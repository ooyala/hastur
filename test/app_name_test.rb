require File.join(File.dirname(__FILE__), "test_helper")

require "mocha"
require "hastur"

class HasturAppNameTest < MiniTest::Unit::TestCase

  def setup
    ENV.delete('HASTUR_APP_NAME')
    Object.class_eval do
      remove_const('HASTUR_APP_NAME') rescue nil
      remove_const('Ecology') rescue nil
    end

    $0 = "fake_app"

    Hastur.reset
  end

  def teardown
  end

  def test_app_name_env
    ENV['HASTUR_APP_NAME'] = "foo"

    assert_equal "foo", Hastur.app_name
  end

  def test_app_name_constant
    Object.class_eval { const_set('HASTUR_APP_NAME', 'warble') }

    assert_equal "warble", Hastur.app_name
  end

  def test_app_name_ecology
    eco = mock("Ecology")
    Object.class_eval { const_set("Ecology", eco) }
    eco.expects(:application).returns("mordecai")

    assert_equal "mordecai", Hastur.app_name
  end

  def test_app_name_first_arg
    $0 = "bobolicious"

    assert_equal "bobolicious", Hastur.app_name
  end

end
