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
    write_file("outer/a.txt", "value")
    commit_all("inner file staging")

    delete("outer/a.txt")
    delete(".git/index")
    jit_cmd("add", ".")

    write_file("outer/a.txt", "conflict")

    jit_cmd("checkout", "@^")
    assert_stderr_remove_conflict("outer/a.txt")
  end

  def test_checkout_fails_with_unstaged_file_at_parent_path
    write_file("outer/inner/94.txt", "94")
    commit_all("init")

    delete("outer/inner")
    delete(".git/index")
    jit_cmd("add", ".")
    write_file("outer/inner", "conflict")

    jit_cmd("checkout", "@^")
    assert_stderr_remove_conflict("outer/inner")
  end

  def test_checkout_detached_to_branch_prints_current_HEAD_pos
    write_file("ab.txt", "aaa")
    jit_cmd("branch", "init")
    commit_all("second commit")
    second_commit = current_head[..6]

    jit_cmd("checkout", "@")
    jit_cmd("checkout", "init")

    expected = "Previous HEAD position was #{second_commit} second commit\n" \
      "Switched to branch 'init'\n"
    assert_stderr(expected)
  end

  def test_checkout_detached_to_detached_prints_current_HEAD_pos
    write_file("ab.txt", "aaa")
    first_commit = current_head[..6]
    commit_all("second commit")
    second_commit = current_head[..6]

    jit_cmd("checkout", "@")
    jit_cmd("checkout", "@^")

    expected = "Previous HEAD position was #{second_commit} second commit\n" \
      "HEAD is now at #{first_commit} intial commit\n"
    assert_stderr(expected)
  end

  def test_prints_error_when_switching_to_same_branch
    jit_cmd("branch", "main")
    jit_cmd("checkout", "main")
    jit_cmd("checkout", "main")

    assert_stderr("Already on 'main'\n")
  end

  def test_detaching_head_reports_correct_message
    jit_cmd("branch", "main")
    jit_cmd("checkout", "main")

    jit_cmd("checkout", "@")

    assert_stderr <<~STDOUT
      Note: checking out '@'

      You are in 'detached HEAD' state. You can look around, make experimental
      changes and commit them, and you can discard any commits you make in this
      state without impacting any branches by switching back to a branch.
      
      If you want to create a new branch to retain commits you create, you may
      do so (now or later) by using -c with the switch command. Example:
      
        git switch -c <new-branch-name>

      HEAD is now at #{current_head[..6]} intial commit
    STDOUT
  end

  def test_checking_out_branch_creates_sym_ref
    jit_cmd("branch", "main")
    jit_cmd("checkout", "main")

    assert_file_contents(".git/HEAD", "ref: refs/heads/main\n")
  end

  def test_checking_out_commit_creates_oid_ref
    jit_cmd("checkout", "@")

    assert_file_contents(".git/HEAD", "#{current_head}\n")
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
