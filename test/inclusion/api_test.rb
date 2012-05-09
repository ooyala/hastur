require File.join(File.dirname(__FILE__), "..", "test_helper")

class ApiInclusionTest < MiniTest::Unit::TestCase
  def test_inclusion
    require "hastur/api"

    assert !Hastur.background_thread?, "hastur/api must not start a background thread!"
  end
end
