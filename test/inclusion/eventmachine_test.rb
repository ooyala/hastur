require File.join(File.dirname(__FILE__), "..", "test_helper")

class EventMachineInclusionTest < MiniTest::Unit::TestCase
  def test_inclusion
    require "hastur/eventmachine"

    assert !Hastur.background_thread?, "hastur/eventmachine must not start a background thread!"
  end
end
