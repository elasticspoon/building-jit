require "minitest/autorun"
require_relative "../command_helper"

class BranchTest < MiniTest::Test
  include CommandHelper

  def test_creates_a_branch
    commit("test")

    current_head = repo.refs.read_head
    jit_cmd("branch", "main")

    assert_ref("main", current_head)
  end

  def test_does_not_create_duplicate_branch
    commit("test")

    jit_cmd("branch", "main")
    jit_cmd("branch", "main")

    assert_stderr("fatal: A branch named main already exists.\n")
  end

  def test_does_not_create_invalid_branch
    commit("test")

    jit_cmd("branch", "^")

    assert_stderr("fatal: '^' is not a valid branch name.\n")
  end

  def test_creates_branch_given_specific_commit
    commit("test")

    jit_cmd("branch", "new_head", current_head)

    assert_ref("new_head", current_head)
  end

  def test_specific_commit_with_reference_using_tilde
    commit("test")

    original_head = current_head

    commit("test")
    commit("test")

    jit_cmd("branch", "new_head", "@~2")

    assert_ref("new_head", original_head)
  end

  def test_ampersand_matches_head
    commit("test")

    original_head = current_head

    commit("test")
    commit("test")

    jit_cmd("branch", "new_head", "@^^")

    assert_ref("new_head", original_head)
  end

  def test_specific_commit_with_reference_using_caret
    commit("test")

    original_head = current_head

    commit("test")

    jit_cmd("branch", "old_head", "@^")

    assert_ref("old_head", original_head)
  end

  def test_head_moves_with_branch_pointer
    write_file("a.txt", "initial")
    commit_all("initial")

    jit_cmd("branch", "initial_head", "@")
    jit_cmd("checkout", "initial_head")

    write_file("b.txt", "initial")
    commit_all("second")

    assert_ref("initial_head", current_head)
  end

  ### Branch Listing ###

  def test_lists_branches_compact
    write_file("a.txt", "intial")
    commit_all("initial")

    jit_cmd("branch", "secondary")

    jit_cmd("branch")

    assert_stdout(<<~MSG
      * main
        secondary
    MSG
                 )
  end

  def test_lists_branches_verbose
    write_file("a.txt", "intial")
    commit_all("initial")

    short_sha = current_head[..6]

    jit_cmd("branch", "secondary")

    jit_cmd("branch", "--verbose")

    assert_stdout(<<~MSG
      * main      #{short_sha} initial
        secondary #{short_sha} initial
    MSG
                 )
  end

  def test_lists_verbose_branches_short_command
    write_file("a.txt", "intial")
    commit_all("initial")

    short_sha = current_head[..6]

    jit_cmd("branch", "secondary")

    jit_cmd("branch", "-v")

    assert_stdout(<<~MSG
      * main      #{short_sha} initial
        secondary #{short_sha} initial
    MSG
                 )
  end

  def test_branch_delete_deletes_branch
    write_file("a.txt", "intial")
    commit_all("initial")

    jit_cmd("branch", "secondary")
    jit_cmd("branch", "tertiary")

    jit_cmd("branch", "-D", "secondary")

    assert_ref("tertiary")
    assert_ref("main")
    assert_no_ref("secondary")
  end

  def test_branch_delete_reports_error_deleting_missing_branch
    jit_cmd("branch", "-D", "missing")

    assert_stderr("error: branch 'missing' not found.\n")
  end

  def test_force_delete_branch
    write_file("a.txt", "intial")
    commit_all("initial")

    jit_cmd("branch", "secondary")
    jit_cmd("branch", "tertiary")

    short_sha = current_head[..6]
    jit_cmd("branch", "-D", "secondary")

    assert_stdout(<<~MSG
      Deleted branch secondary (was #{short_sha}).
    MSG
                 )
  end

  def test_regular_delete_branch_with_force_alt_syntax
    write_file("a.txt", "intial")
    commit_all("initial")

    jit_cmd("branch", "secondary")
    jit_cmd("branch", "tertiary")

    short_sha = current_head[..6]
    jit_cmd("branch", "-d", "--force", "secondary")

    assert_stdout(<<~MSG
      Deleted branch secondary (was #{short_sha}).
    MSG
                 )
  end

  def test_regular_delete_branch_with_force
    write_file("a.txt", "intial")
    commit_all("initial")

    jit_cmd("branch", "secondary")
    jit_cmd("branch", "tertiary")

    short_sha = current_head[..6]
    jit_cmd("branch", "-d", "-f", "secondary")

    assert_stdout(<<~MSG
      Deleted branch secondary (was #{short_sha}).
    MSG
                 )
  end

  def test_force_delete_multiples_branches
    write_file("a.txt", "intial")
    commit_all("initial")

    jit_cmd("branch", "secondary")
    jit_cmd("branch", "tertiary")

    short_sha = current_head[..6]
    jit_cmd("branch", "-D", "secondary", "tertiary")

    assert_stdout(<<~MSG
      Deleted branch secondary (was #{short_sha}).
      Deleted branch tertiary (was #{short_sha}).
    MSG
                 )
  end

  def test_branch_regular_delete_branch
    write_file("a.txt", "intial")
    commit_all("initial")

    jit_cmd("branch", "secondary")
    jit_cmd("branch", "tertiary")

    jit_cmd("branch", "-d", "secondary")

    assert_stderr("Unforced branch deletion not implemented\n")
  end

  def test_regular_delete_unmerged_branch_fails
  end
end
