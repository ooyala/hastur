require File.join(File.dirname(__FILE__), "..", "test_helper")

require "mocha"

module Hastur
end

class DefaultInclusionTest < MiniTest::Unit::TestCase
  def test_inclusion
    Hastur.expects(:register_process)
    Hastur.expects(:start_background_thread)

    require "hastur"
  end
end
