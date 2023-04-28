require "minitest/autorun"

require "pathname"
require "fileutils"
require "workspace"

class WorkspaceTest < MiniTest::Test
  # def test_throws_error_no_file
  #   working_dir = Pathname.new('')
  #   target_file = Pathname.new('bad_file.rb')
  #   workspace = Workspace.new(working_dir)

  #   assert_raises(Workspace::MissingFile) { workspace.list_files(target_file) }
  # end

  # def test_throws_no_premission_reading_unreadable_file
  #   working_dir = Pathname.new('')
  #   file_path = Pathname.new('test_file.txt')
  #   workspace = Workspace.new(working_dir)

  #   File.new(file_path, File::CREAT, 0o220)

  #   assert_raises(Workspace::NoPermission) { workspace.read_file(file_path) }
  # ensure
  #   FileUtils.rm_f(file_path)
  # end
end
