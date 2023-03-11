class Workspace
  IGNORE = ['.', '..', '.git'].freeze
  MissingFile = Class.new(StandardError)
  NoPermission = Class.new(StandardError)

  def initialize(pathname)
    @pathname = pathname
  end

  def list_files(file_path=@pathname)
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
  rescue Errno::EACCES
    raise NoPermission, "stat('#{path}'): Permission denied"
  end

  def list_dir(dir_path)
    path = @pathname.join(dir_path || '')
    entries = Dir.entries(path) - IGNORE
    stats = {}

    entries.each do |entry|
      relative = path.join(entry).relative_path_from(@pathname)
      stats[relative.to_s] = File.stat(path.join(entry))
    end

    stats
  end
end
