require "minitest/autorun"
require_relative "../command_helper"

class CommitTest < MiniTest::Test
  include CommandHelper

  def test_committing_updates_head
    write_file("a.txt", "hello")

    assert_index([])

    jit_cmd("add", "a.txt")

    assert_index([[0o100644, "a.txt"]])

    commit("stuff")

    assert_index([[0o100644, "a.txt"]])
  end
end
