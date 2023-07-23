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
end
