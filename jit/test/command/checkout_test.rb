require "minitest/autorun"
require_relative "../command_helper"

class CheckoutTest < MiniTest::Test
  include CommandHelper

  def test_basic
    write_file("a.txt", "test")
    commit("test")
    jit_cmd("branch", "main")

    assert_workspace(["a.txt"])
    jit_cmd("checkout", "main")
    assert_workspace(["a.txt"])
  end
end
