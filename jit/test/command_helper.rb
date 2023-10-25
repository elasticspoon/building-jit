require 'fileutils'
require 'pathname'

require_relative '../lib/command'
require_relative '../lib/repository'
class Database
  def store_mock_object(object)
    content = serialize_object(object)
    write_object(object.oid, content)
  end
end

module CommandHelper
  def self.included(suite)
    suite.class_eval do
      def setup
        jit_cmd('init', repo_path.to_s)
      end

      def teardown
        FileUtils.rm_rf(repo_path)
      end
    end
  end

  def write_file(file_name, file_content)
    path = repo_path.join(file_name)
    FileUtils.mkdir_p(path.dirname)

    flags = File::RDWR | File::CREAT | File::TRUNC

    File.open(path, flags) { |f| f.write(file_content) }
  end

  def set_stdin(string)
    @stdin = StringIO.new(string)
  end

  def set_env(key, val)
    @env ||= {}
    @env[key] = val
  end

  def commit(message, time=nil, author=true)
    if author
      set_env('GIT_AUTHOR_NAME', 'A. U. Thor')
      set_env('GIT_AUTHOR_EMAIL', 'author@example.com')
    end
    Time.stub(:now, time || Time.now) { jit_cmd 'commit', '-m', message }
  end

  def load_commit(expression)
    repo.database.load(resolve_revision(expression))
  end

  def resolve_revision(expression)
    Revision.new(repo, expression).resolve
  end

  def commit_all(message)
    jit_cmd('add', '.')
    commit(message)
  end

  def jit_cmd(*argv)
    @env ||= {}
    @stdin ||= StringIO.new
    @stdout = StringIO.new
    @stderr = StringIO.new

    @cmd = Command.execute(repo_path.to_s, @env, argv, @stdin, @stdout, @stderr)
  end

  def current_head
    repo.refs.read_head
  end

  def repo_path
    Pathname.new(File.expand_path('test_repo', __dir__))
  end

  def repo
    @repo ||= Repository.new(repo_path.join('.git'))
  end

  def assert_index(expected)
    repo.index.load

    actual = repo.index.each_entry.map { |entry| [entry.mode, entry.path] }
    assert_equal(expected, actual)
  end

  def assert_workspace(expected)
    actual = repo.workspace.list_files.map do |path|
      stat = Index::Entry.mode_for_stat(repo.workspace.stat_file(path))
      [stat, path.to_s]
    end
    assert_equal(expected, actual)
  end

  def assert_workspace_contents(expected, repo=self.repo)
    files = {}

    repo.workspace.list_files.sort.each do |pathname|
      files[pathname.to_s] = repo.workspace.read_file(pathname)
    end

    assert_equal(expected, files)
  end

  def make_executable(name)
    FileUtils.chmod(0o755, repo_path.join(name))
  end

  def make_unreadable(name)
    FileUtils.chmod(0o220, repo_path.join(name))
  end

  def touch(name)
    FileUtils.touch(repo_path.join(name))
  end

  def mkdir(name)
    FileUtils.mkdir_p(repo_path.join(name))
  end

  def delete(name)
    FileUtils.rm_rf(repo_path.join(name))
  end

  def assert_status(expected)
    assert_equal(expected, @cmd.status)
  end

  def assert_stdout(expected)
    assert_output(@stdout, expected)
  end

  def assert_ref(name, value=nil)
    ref_value = repo.refs.read_ref(name)

    if value
      assert_equal(ref_value, value)
    else
      assert_equal(ref_value.nil?, false)
    end
  end

  def assert_no_ref(name)
    ref_value = repo.refs.read_ref(name)

    assert_nil(ref_value)
  end

  def assert_stderr(expected)
    assert_output(@stderr, expected)
  end

  def assert_repo_status(expected)
    jit_cmd('status', '--porcelain')
    assert_stdout(expected)
  end

  private

  def assert_output(stream, message)
    stream.rewind
    assert_equal(message, stream.read)
  end

  def assert_file_contents(file, expected)
    file_name = repo_path.join(file)
    raise StandardError, "File #{file_name} does not exist" unless File.exist?(file_name)

    file_content = File.read(file_name)
    assert_equal(expected, file_content)
  end
end
