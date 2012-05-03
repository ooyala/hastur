require File.join(File.dirname(__FILE__), "..", "test_helper")

require "mocha"

class AllInclusionTest < MiniTest::Unit::TestCase
  def test_inclusion
    require "hastur/api"

    Hastur.application = "app_name"
    Hastur.expects(:register_process).with("app_name", {})
    Hastur.expects(:start_background_thread)

    require "hastur/all"
  end
end
