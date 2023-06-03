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
end
