require 'minitest/autorun'

require 'pathname'
require 'securerandom'
require 'index'
require 'lockfile'

class IndexTest < MiniTest::Test
  # __FILE__ is a reference to the current file name
  def setup
    @tmp_path = File.expand_path('tmp', __dir__)
    index_path = Pathname.new(@tmp_path).join('index')
    @index = Index.new(index_path)
    @stat = File.stat(__FILE__)
    @oid = SecureRandom.hex(20)
  end

  def test_add_single_file
    @index.add('test.txt', @oid, @stat)

    assert_equal(['test.txt'], @index.each_entry.map(&:path))
  end

  def test_replace_file_with_dir
    @index.add('test.txt', @oid, @stat)

    @index.add('test.txt/test.txt', @oid, @stat)

    assert_equal(['test.txt/test.txt'], @index.each_entry.map(&:path))
  end

  def test_replace_dir_with_file
    @index.add('test.txt/test.txt', @oid, @stat)

    @index.add('test.txt', @oid, @stat)

    assert_equal(['test.txt'], @index.each_entry.map(&:path))
  end

  def test_replace_dir_and_children_with_file
    @index.add('dir_a/dir_b/child.txt', @oid, @stat)
    @index.add('dir_a/child.txt', @oid, @stat)

    @index.add('dir_a', @oid, @stat)

    assert_equal(['dir_a'], @index.each_entry.map(&:path))
  end

  def test_error_when_index_lock_exists
    lockfile_dir = Pathname.new(@tmp_path)
    lockfile_path = lockfile_dir.join('index.lock')
    create_index_lock(lockfile_path, lockfile_dir)

    assert_raises(Lockfile::LockDenied) do
      @index.load_for_update
    end
  ensure
    remove_index_lock(lockfile_dir)
  end

  private

  def create_index_lock(path, parent_dir)
    flags = File::RDWR | File::CREAT | File::EXCL
    File.open(path, flags)
  rescue Errno::ENOENT
    Dir.mkdir(parent_dir)
    File.open(path, flags)
  end

  def remove_index_lock(parent_dir)
    FileUtils.rm_r(parent_dir, force: true)
  end
end
