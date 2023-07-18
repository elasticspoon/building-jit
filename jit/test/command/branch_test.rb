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

    current_head = repo.refs.read_head

    jit_cmd("branch", "main", current_head)

    assert_ref("main", current_head)
  end

  def test_specific_commit_with_reference_using_tilde
    commit("test")

    original_head = repo.refs.read_head

    commit("test")
    commit("test")

    current_head = repo.refs.read_head

    jit_cmd("branch", "main", "#{current_head}~2")

    assert_ref("main", original_head)
  end

  def test_ampersand_matches_head
    commit("test")

    original_head = repo.refs.read_head

    commit("test")
    commit("test")

    jit_cmd("branch", "main", "@^^")

    assert_ref("main", original_head)
  end

  def test_specific_commit_with_reference_using_caret
    commit("test")

    original_head = repo.refs.read_head

    commit("test")
    commit("test")

    current_head = repo.refs.read_head

    jit_cmd("branch", "main", "#{current_head}^^")

    assert_ref("main", original_head)
  end

  # TODO: Figure out how to make objects with specific shas
end
