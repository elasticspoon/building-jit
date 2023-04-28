require "minitest/autorun"
require_relative "../command_helper"

class StatusTest < MiniTest::Test
  include CommandHelper

  def test_lists_an_untracked_file
    write_file("a.txt", "hello")

    jit_cmd("status")

    assert_repo_status(<<~STATUS
      ?? a.txt
    STATUS
                      )
    assert_status 0
  end

  def test_does_not_list_commited_files
    write_file("a.txt", "hello")
    jit_cmd("add", "a.txt")
    commit("some message")

    write_file("b.txt", "hello")

    assert_repo_status(<<~STATUS
      ?? b.txt
    STATUS
                      )
    assert_status 0
  end

  def test_lists_untracked_files_in_name_order
    write_file("b.txt", "hello")
    write_file("a.txt", "hello")

    assert_repo_status(<<~STATUS
      ?? a.txt
      ?? b.txt
    STATUS
                      )
    assert_status 0
  end

  def test_lists_dir_when_all_contents_untracked
    write_file("a.txt", "hello")
    write_file("dir/a.txt", "hello")

    assert_repo_status(<<~STATUS
      ?? a.txt
      ?? dir/
    STATUS
                      )
    assert_status 0
  end

  def test_lists_untracked_dir_contents_when_some_tracked
    write_file("a/b/inner.txt", "hello")
    jit_cmd("add", "a/b/inner.txt")
    commit("message")

    write_file("a/outer.txt", "hello")
    write_file("a/b/c/file.txt", "hello")

    assert_repo_status(<<~STATUS
      ?? a/b/c/
      ?? a/outer.txt
    STATUS
                      )
    assert_status 0
  end

  def test_empty_dirs_not_shown
    mkdir("test")

    assert_repo_status("")
    assert_status 0
  end

  def test_top_dir_listed_when_all_contents_untracked
    write_file("a/b/c.txt", "stuff")

    assert_repo_status(<<~STATUS
      ?? a/
    STATUS
                      )
    assert_status 0
  end

  # def test_lists_tracked_files_in_name_order
  #   write_file('b.txt', 'hello')
  #   write_file('a.txt', 'hello')
  #   jit_cmd('add', 'b.txt', 'a.txt')

  #   assert_index([[0o100644, 'a.txt'], [0o100644, 'b.txt']])

  #   jit_cmd('status')

  #   assert_repo_status(<<~STATUS
  #     A  a.txt
  #     A  b.txt
  #   STATUS
  #                     )
  #   assert_status 0
  # end
end

class WorkspaceChangesTest < MiniTest::Test
  include CommandHelper
  alias_method :old_setup, :setup

  def setup
    old_setup
    write_file("1.txt", "1")
    write_file("a/2.txt", "2")
    write_file("a/b/3.txt", "3")
    jit_cmd("add", ".")
    commit("some message")
  end

  def test_no_output_on_clean_workspace
    assert_repo_status("")
    assert_status(0)
  end

  def test_correct_output_when_files_change
    write_file("1.txt", "changed")
    write_file("a/2.txt", "changed")

    assert_repo_status(<<-STATUS
 M 1.txt
 M a/2.txt
    STATUS
                      )
    assert_status 0
  end

  def test_shows_files_made_executable
    make_executable("1.txt")

    assert_repo_status(<<-STATUS
 M 1.txt
    STATUS
                      )
  end

  def test_shows_file_changed_with_same_size
    sleep 0.01
    # added the sleep because in certain situations the file
    # the file would be created and modded in the same time according to stat
    write_file("1.txt", "2")

    assert_repo_status(<<-STATUS
 M 1.txt
    STATUS
                      )
    assert_status 0
  end

  def test_prints_nothing_if_file_touched
    touch("1.txt")

    assert_repo_status("")
    assert_status 0
  end

  def test_reports_a_deleted_file
    delete("a/2.txt")

    assert_repo_status(<<-STATUS
 D a/2.txt
    STATUS
                      )
    assert_status 0
  end

  def test_reports_files_in_deleted_directories
    delete("a")

    assert_repo_status(<<-STATUS
 D a/2.txt
 D a/b/3.txt
    STATUS
                      )
    assert_status 0
  end
end

class IndexHeadChangesTest < MiniTest::Test
  include CommandHelper
  alias_method :old_setup, :setup

  def setup
    old_setup # some intial setup is done with a on include hook in command helper
    write_file("1.txt", "one")
    write_file("a/2.txt", "two")
    write_file("a/b/3.txt", "three")

    jit_cmd("add", ".")
    commit("first commit")
  end

  def test_lists_file_as_added
    write_file("a/4.txt", "four")
    jit_cmd("add", ".")

    assert_repo_status(<<~STATUS
      A  a/4.txt
    STATUS
                      )
    assert_status 0
  end

  def test_lists_dir_untracked_file_added
    write_file("d/e/5.txt", "five")
    jit_cmd("add", ".")

    assert_repo_status(<<~STATUS
      A  d/e/5.txt
    STATUS
                      )
    assert_status 0
  end

  def test_reports_modified_modes
    make_executable("1.txt")
    jit_cmd("add", ".")

    assert_repo_status(<<~STATUS
      M  1.txt
    STATUS
                      )
    assert_status 0
  end

  def test_reports_modified_contents
    write_file("a/b/3.txt", "something else")
    jit_cmd("add", ".")

    assert_repo_status(<<~STATUS
      M  a/b/3.txt
    STATUS
                      )
    assert_status 0
  end

  def test_reports_deleted_files
    delete("1.txt")
    delete(".git/index")
    jit_cmd("add", ".")

    assert_repo_status(<<~STATUS
      D  1.txt
    STATUS
                      )
    assert_status 0
  end

  def test_reports_deleted_directories
    delete("a")
    delete(".git/index")
    jit_cmd("add", ".")

    assert_repo_status(<<~STATUS
      D  a/2.txt
      D  a/b/3.txt
    STATUS
                      )
    assert_status 0
  end

  def test_reports_deleted_files_from_index
    delete("1.txt")
    jit_cmd("add", ".")

    assert_repo_status(<<~STATUS
      D  1.txt
    STATUS
                      )
    assert_status 0
  end

  def test_reports_deleted_directories_from_index
    delete("a")
    jit_cmd("add", ".")

    assert_repo_status(<<~STATUS
      D  a/2.txt
      D  a/b/3.txt
    STATUS
                      )
    assert_status 0
  end
end
