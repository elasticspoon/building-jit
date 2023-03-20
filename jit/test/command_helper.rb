require 'fileutils'
require 'pathname'

require 'command'
require 'repository'

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

  def commit(message)
    set_env('GIT_AUTHOR_NAME', 'A. U. Thor')
    set_env('GIT_AUTHOR_EMAIL', 'author@example.com')
    set_stdin(message)
    jit_cmd('commit')
  end

  def jit_cmd(*argv)
    @env ||= {}
    @stdin ||= StringIO.new
    @stdout = StringIO.new
    @stderr = StringIO.new

    @cmd = Command.execute(repo_path.to_s, @env, argv, @stdin, @stdout, @stderr)
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
end
