require_relative "../lib/lockfile"

class Refs
  LockDenied = Class.new(StandardError)
  InvalidBranch = Class.new(StandardError)

  SymRef = Struct.new(:refs, :path) do
    def read_oid
      refs.read_ref(path)
    end

    def head?
      path == HEAD
    end
  end

  Ref = Struct.new(:oid) do
    def read_oid
      oid
    end
  end

  SYMREF = /^ref: (.+)$/

  INVALID_NAME = %r{
^\.
| /\.
| \.\.
| /$
| \.lock$
| @\{
| [\x00-\x20*:?\[\\^~\x7f]
}x
  HEAD = "HEAD".freeze

  def initialize(pathname)
    @pathname = pathname
    @refs_path = pathname.join("refs")
    @heads_path = @refs_path.join("heads")
  end

  def update_head(oid)
    update_symref(head_path, oid)
  end

  def read_head
    read_symref(head_path)
  end

  def set_head(revision, oid)
    head = @pathname.join(HEAD)
    path = @heads_path.join(revision)

    if File.file?(path)
      relative = path.relative_path_from(@pathname)
      update_ref_file(head, "ref: #{relative}")
    else
      update_ref_file(head, oid)
    end
  end

  def create_branch(branch_name, start_oid)
    path = @heads_path.join(branch_name)

    raise InvalidBranch, "'#{branch_name}' is not a valid branch name." if branch_name.match?(INVALID_NAME)
    raise InvalidBranch, "A branch named #{branch_name} already exists." if File.file?(path)

    update_ref_file(path, start_oid)
  end

  def read_ref(name)
    path = path_for_name(name)
    path.nil? ? nil : read_symref(path)
  end

  def current_ref(source = HEAD)
    ref = read_oid_or_symref(@pathname.join(source))

    case ref
    when SymRef
      current_ref(ref.path)
    when Ref, nil
      SymRef.new(self, source)
    end
  end

  private

  def read_oid_or_symref(path)
    data = File.read(path).strip
    match = SYMREF.match(data)

    match ? SymRef.new(self, match[1]) : Ref.new(data)
  rescue Errno::ENOENT
    nil
  end

  def read_symref(path)
    ref = read_oid_or_symref(path)

    case ref
    when SymRef
      symref_path = @pathname.join(ref.path)
      read_symref(symref_path)
    when Ref
      ref.oid
    end
  end

  def update_symref(path, oid)
    lockfile = Lockfile.new(path)
    lockfile.hold_for_update

    ref = read_oid_or_symref(path)

    return write_lockfile(lockfile, oid) unless ref.is_a?(SymRef)

    begin
      update_symref(@pathname.join(ref.path), oid)
    ensure
      lockfile.rollback
    end
  end

  def path_for_name(name)
    prefixes = [@pathname, @refs_path, @heads_path]
    prefix = prefixes.find { |path| File.file? path.join(name) }

    prefix&.join(name)
  end

  def read_ref_file(path)
    File.read(path).rstrip
  rescue Errno::ENOENT, TypeError
    nil
  end

  def update_ref_file(path, oid)
    lockfile = Lockfile.new(path)

    lockfile.hold_for_update
    write_lockfile(lockfile, oid)
  rescue Lockfile::MissingParent
    FileUtils.mkdir_p(path.dirname)
    retry
  end

  def write_lockfile(lockfile, oid)
    lockfile.write(oid)
    lockfile.write("\n")
    lockfile.commit
  end

  def head_path
    @pathname.join(HEAD)
  end

  def branch_path(branch_name)
    @pathname.join("refs/heads").join(branch_name)
  end
end
