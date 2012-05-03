require File.join(File.dirname(__FILE__), "..", "test_helper")

require "mocha"

class AllInclusionTest < MiniTest::Unit::TestCase
  def test_inclusion
    require "hastur/api"

    Hastur.application = "app_name"
    Hastur.expects(:register_process)
    Hastur.expects(:start_background_thread)

    require "hastur/all"

    assert Hastur::RegistrationData.any? do |set|
      set.has_key?(:loaded_features) &&
      set.hash_key?(:loaded_gems)
    end
  end
end
