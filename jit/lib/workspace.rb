require "fileutils"
class Workspace
  IGNORE = [".", "..", ".git"].freeze
  MissingFile = Class.new(StandardError)
  NoPermission = Class.new(StandardError)

  attr_reader :pathname

  def initialize(pathname)
    @pathname = pathname
  end

  def list_files(file_path = @pathname)
    relative = file_path.relative_path_from(@pathname)

    if File.directory?(file_path)
      filenames = Dir.entries(file_path) - IGNORE
      filenames.flat_map { |file_name| list_files(file_path.join(file_name)) }
    elsif File.exist?(file_path)
      [relative]
    else
      raise MissingFile, "pathspec '#{relative}' did not match any files"
    end
  end

  def read_file(path)
    File.read(@pathname.join(path))
  rescue Errno::EACCES
    raise NoPermission, "open('#{path}'): Permission denied"
  end

  def stat_file(path)
    File.stat(@pathname.join(path))
  rescue Errno::ENOENT, Errno::ENOTDIR
    nil
  rescue Errno::EACCES
    raise NoPermission, "stat('#{path}'): Permission denied"
  end

  def list_dir(dir_path)
    path = @pathname.join(dir_path || "")
    entries = Dir.entries(path) - IGNORE
    stats = {}

    entries.each do |entry|
      relative = path.join(entry).relative_path_from(@pathname)
      stats[relative.to_s] = File.stat(path.join(entry))
    end

    stats
  end

  def apply_migration(migration)
    apply_change_list(migration, :destroy)
    migration.rmdirs.sort.reverse_each { |dir| remove_empty_directory(dir) }

    migration.mkdirs.sort.each { |dir| remove_empty_directory(dir) }
    apply_change_list(migration, :update)
    apply_change_list(migration, :create)
  end

  def remove_empty_directory(dir_path)
    Dir.rmdir(@pathname.join(dir_path))
  rescue Errno::ENOENT, Errno::ENOTDIR, Errno::ENOTEMPTY
  end

  def make_dir(dir_path)
    path = @pathname.join(dir_path)
    stat = stat_file(path)

    File.unlink(path) if stat&.file?
    Dir.mkdir(path) unless stat&.directory?
  end

  private

  def apply_change_list(migration, change_type)
    migration.changes[change_type].each do |path, entry|
      path = @pathname.join(path)

      FileUtils.rm_rf(path)
      next if change_type == :destroy

      flags = File::WRONLY | File::CREAT | File::EXCL
      data = migration.blob_data(entry.oid)

      File.open(path, flags) { |file| file.write(data) }
      File.chmod(entry.mode, path)
    end
  end
end
