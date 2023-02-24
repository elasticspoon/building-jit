class Workspace
  IGNORE = ['.', '..', '.git'].freeze

  def initialize(pathname)
    @pathname = pathname
  end

  def list_files(file_path=@pathname)
    if File.directory?(file_path)
      filenames = Dir.entries(file_path) - IGNORE
      filenames.flat_map { |file_name| list_files(file_path.join(file_name)) }
    else
      [file_path.relative_path_from(@pathname)]
    end
  end

  def read_file(path)
    File.read(@pathname.join(path))
  end

  def stat_file(path)
    File.stat(@pathname.join(path))
  end
end
