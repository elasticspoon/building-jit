require 'minitest/autorun'
require_relative '../command_helper'

class AddTest < MiniTest::Test
  include CommandHelper

  def test_index_empty_initially
    write_file('hello.txt', 'hello')
    assert_index([])
  end

  def test_add_file_to_index
    write_file('hello.txt', 'hello')

    jit_cmd('add', 'hello.txt')

    assert_index([[0o100644, 'hello.txt']])
  end

  def test_add_executable_file_to_index
    write_file('hello.txt', 'hello')
    make_executable('hello.txt')

    jit_cmd('add', 'hello.txt')

    assert_index([[0o100755, 'hello.txt']])
  end

  def test_incrementally_add_multiple_files_to_index
    write_file('b.txt', 'hello')
    write_file('a.txt', 'hello')

    jit_cmd('add', 'b.txt')
    assert_index([[0o100644, 'b.txt']])

    jit_cmd('add', 'a.txt')
    assert_index([[0o100644, 'a.txt'], [0o100644, 'b.txt']])
  end

  def test_add_multiple_files_to_index
    write_file('b.txt', 'hello')
    write_file('a.txt', 'hello')

    jit_cmd('add', 'a.txt', 'b.txt')
    assert_index([[0o100644, 'a.txt'], [0o100644, 'b.txt']])
  end

  def test_add_directory_contents_to_index
    write_file('dir/a.txt', 'hello')
    write_file('dir/b.txt', 'hello')

    jit_cmd('add', 'dir')

    assert_index([[0o100644, 'dir/a.txt'], [0o100644, 'dir/b.txt']])
  end

  def test_add_root_dir_to_index
    write_file('dir_a/a.txt', 'hello')
    write_file('dir_a/dir_b/b.txt', 'hello')

    jit_cmd('add', '.')

    assert_index([[0o100644, 'dir_a/a.txt'], [0o100644, 'dir_a/dir_b/b.txt']])
  end

  def test_add_silent_on_success
    write_file('a.txt', 'hello')

    jit_cmd('add', 'a.txt')

    assert_status(0)
    assert_stdout('')
    assert_stderr('')
  end

  def test_unreadable_file
    write_file('a.txt', 'hello')
    make_unreadable('a.txt')

    jit_cmd('add', 'a.txt')

    assert_status(128)
    assert_stdout('')
    assert_stderr(<<~ERROR
      error: open('a.txt'): Permission denied
      fatal: adding files failed
    ERROR
                 )
    assert_index([])
  end

  def test_missing_file
    jit_cmd('add', 'a.txt')

    assert_status(128)
    assert_stdout('')
    assert_stderr(<<~ERROR
      fatal: pathspec 'a.txt' did not match any files
    ERROR
                 )
    assert_index([])
  end

  def test_locked_index_file
    write_file('a.txt', 'hello')
    write_file('.git/index.lock', 'hello')

    jit_cmd('add', 'a.txt')

    assert_status(128)
    assert_stdout('')
    assert_index([])
  end
end
