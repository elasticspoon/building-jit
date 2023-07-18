require "minitest/autorun"
require_relative "../command_helper"

class CheckoutTest < MiniTest::Test
  include CommandHelper

  BASE_FILES = {
    "1.txt" => "1",
    "outer/2.txt" => "2",
    "outer/inner/3.txt" => "3"
  }.freeze

  alias_method :orig_setup, :setup

  def setup
    orig_setup
    BASE_FILES.each do |name, contents|
      write_file(name, contents)
    end
    jit_cmd("add", ".")
    commit "intial commit"
  end

  def test_unchanged_when_loading_itself
    jit_cmd("checkout", "@")

    assert_workspace_contents(BASE_FILES)
  end

  def test_checkout_adds_file
    delete("1.txt")
    commit_all("removed file")

    jit_cmd("checkout", "@^")
    assert_workspace_contents(BASE_FILES)
  end

  def test_checkout_deletes_file
    write_file("a.txt", "test")
    commit_all("added file")

    jit_cmd("checkout", "@^")

    assert_workspace_contents(BASE_FILES)
  end

  def test_checkout_changes_file
    write_file("1.txt", "changed contents")
    commit_all("changed 1 contents")

    jit_cmd("checkout", "@^")
    assert_workspace_contents(BASE_FILES)
  end

  def test_checkout_fails_with_stale_file
    write_file("1.txt", "changed value - committed")
    commit_all("commited value")

    write_file("1.txt", "changed value - unstaged")

    jit_cmd("checkout", "@^")
    assert_stderr_stale_file("1.txt")
  end

  def test_checkout_fails_with_stale_directory
    delete("outer/2.txt")
    commit_all("removed file")

    write_file("outer/2.txt/subfile.txt", "some value")
    jit_cmd("checkout", "@^")

    assert_stderr_stale_directory("outer/2.txt")
  end

  def test_checkout_fails_with_overwrite_conflict
    delete("1.txt")
    commit_all("removed 1")

    write_file("1.txt", "some other value")
    jit_cmd("checkout", "@^")

    assert_stderr_overwrite_conflict("1.txt")
  end

  def test_checkout_fails_with_remove_conflict
    delete("1.txt")
    commit_all("removed 1")

    write_file("a.txt", "some other value")
    commit_all("intermediary commit")

    write_file("1.txt", "some value")
    jit_cmd("checkout", "@^")

    assert_stderr_overwrite_conflict("1.txt")
  end

  private

  def assert_stderr_stale_file(filename)
    assert_stderr <<~ERROR
      error: Your local changes to the following files would be overwritten by checkout:
      \t#{filename}
      Please commit your changes or stash them before you switch branches.
      Aborting
    ERROR
  end

  def assert_stderr_stale_directory(filename)
    assert_stderr <<~ERROR
      error: Updating the following directories would lose untracked files in them:
      \t#{filename}

      Aborting
    ERROR
  end

  def assert_stderr_overwrite_conflict(filename)
    assert_stderr <<~ERROR
      error: The following untracked working tree files would be overwritten by checkout:
      \t#{filename}
      Please move or remove them before you switch branches.
      Aborting
    ERROR
  end

  def assert_stderr_remove_conflict(filename)
    assert_stderr <<~ERROR
      error: The following untracked working tree files would be removed by checkout:
      \t#{filename}
      Please move or remove them before you switch branches.
      Aborting
    ERROR
  end
end
