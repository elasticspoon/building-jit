require_relative "../lib/lockfile"

class Refs
  LockDenied = Class.new(StandardError)
  InvalidBranch = Class.new(StandardError)

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
    update_ref_file(head_path, oid)
  end

  def read_head
    File.read(head_path).strip if File.exist?(head_path)
  end

  def create_branch(branch_name, start_oid)
    path = @heads_path.join(branch_name)

    raise InvalidBranch, "'#{branch_name}' is not a valid branch name." if branch_name.match?(INVALID_NAME)
    raise InvalidBranch, "A branch named #{branch_name} already exists." if File.file?(path)

    update_ref_file(path, start_oid)
  end

  def read_ref(name)
    path = path_for_name(name)
    # read_ref_file(path)
    File.read(path).rstrip unless path.nil?
  end

  private

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
    lockfile.write(oid)
    lockfile.write("\n")
    lockfile.commit
  rescue Lockfile::MissingParent
    FileUtils.mkdir_p(path.dirname)
    retry
  end

  def head_path
    @pathname.join(HEAD)
  end

  def branch_path(branch_name)
    @pathname.join("refs/heads").join(branch_name)
  end
end
