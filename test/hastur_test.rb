require File.join(File.dirname(__FILE__), "test_helper")

require "mocha"
require "hastur"
require "multi_json"

# This is a hack to allow sorting symbols below in Ruby 1.8.
# Ruby 1.9 actually already has this.
class Symbol
  define_method("<=>") do |obj|
    self.to_s <=> obj.to_s
  end
end

class HasturApiTest < MiniTest::Unit::TestCase

  def setup
    @test_messages = []
    Hastur.deliver_with { |msg|
      @test_messages << msg
    }
  end

  def test_messages
    @test_messages
  end

  def teardown
  end

  def test_timestamp_nil
    ts = Hastur.timestamp(nil)
    ts2 = Hastur.timestamp(Time.now)

    assert ts2 - ts < 1_000_000, "nil should work as a timestamp!"
  end

  def test_timestamp_now
    ts = Hastur.timestamp(:now)
    ts2 = Hastur.timestamp(Time.now)

    assert ts2 - ts < 1_000_000, ":now should work as a timestamp!"
  end

  def test_counter
    curr_time = Time.now.to_i
    Hastur.counter("name", 1, curr_time)
    msgs = test_messages
    hash = msgs[-1]
    assert_equal("counter", hash[:type].to_s)
    assert_equal("name", hash[:name])
    assert_equal(curr_time*1000000, hash[:timestamp])
    assert_equal(1, hash[:value])
    assert_equal("counter", hash[:type].to_s)
    assert hash[:labels].keys.sort == [:app, :pid, :tid],
      "Wrong keys #{hash[:labels].keys.inspect} in default labels!"
  end

  def test_gauge
    curr_time = Time.now.to_i
    Hastur.gauge("name", 9, curr_time)
    msgs = test_messages
    hash = msgs[-1]
    assert_equal("gauge", hash[:type].to_s)
    assert_equal("name", hash[:name])
    assert_equal(curr_time * 1000000, hash[:timestamp])
    assert_equal(9, hash[:value])
    assert_equal("gauge", hash[:type].to_s)
    assert hash[:labels].keys.sort == [:app, :pid, :tid],
      "Wrong keys #{hash[:labels].keys.inspect} in default labels!"
  end
 
  def test_mark
    curr_time = Time.now.to_i
    Hastur.mark("myName", nil, curr_time)
    msgs = test_messages
    hash = msgs[-1]
    assert_equal("mark", hash[:type].to_s)
    assert_equal("myName", hash[:name])
    assert_equal("mark", hash[:type].to_s)
    assert_equal(curr_time*1000000, hash[:timestamp])
    assert hash[:labels].keys.sort == [:app, :pid, :tid],
      "Wrong keys #{hash[:labels].keys.inspect} in default labels!"
  end

  def test_heartbeat
    Hastur.heartbeat(nil, nil, nil, :now, :app => "myApp")
    msgs = test_messages
    hash = msgs[-1]
    assert_equal("myApp", hash[:labels][:app])
    assert_equal("hb_process", hash[:type].to_s)
    assert hash[:labels].keys.sort == [:app, :pid, :tid],
      "Wrong keys #{hash[:labels].keys.inspect} in default labels!"
  end

  def test_process_heartbeat
    Hastur.__reset_bg_thread__

    # Make the "every" background thread think it's later than it is
    tn = Time.now
    Time.stubs(:now).returns(tn + 65)
    sleep 2  # Then sleep long enough that it woke up and ran

    msgs = test_messages
    hash = msgs[-1]
    assert hash != nil, "Hash cannot be nil"
    assert_equal("hb_process", hash[:type].to_s)
    assert_equal("process_heartbeat", hash[:name].to_s)
    assert hash[:labels].keys.sort == [:app, :pid, :tid],
      "Wrong keys #{hash[:labels].keys.inspect} in default labels!"
  end

  def test_event
    event_name = "bad.log.line"
    subject = "Got a bad log line: '@@@@@@@@@'"
    body = "a\nb\nc\nd\ne\nf"
    attn = [ "backlot", "helios", "analytics-helios-api" ]
    Hastur.event(event_name, subject, body, attn, :now, {:foo => "foo", :bar => "bar"})
    msgs = test_messages
    hash = msgs[-1]
    assert_equal("event", hash[:type].to_s)
    assert_equal(event_name, hash[:name])
    assert_equal(subject, hash[:subject])
    assert_equal(attn, hash[:attn])
    assert hash[:labels].keys.sort == [:app, :bar, :foo, :pid, :tid],
      "Wrong keys #{hash[:labels].keys.inspect} in default labels!"
  end

  def test_register_plugin
    plugin_path = "plugin_path"
    plugin_args = "plugin_args"
    plugin_name = "plugin_name"
    interval = :five_minutes
    labels = {:foo => "foo"}
    Hastur.register_plugin(plugin_name, plugin_path, plugin_args, interval, nil, labels)
    msgs = test_messages
    hash = msgs[-1] 
    assert_equal("reg_pluginv1", hash[:type].to_s)
    assert_equal(plugin_path, hash[:plugin_path])
    assert_equal(plugin_args, hash[:plugin_args])
    assert_equal(plugin_name, hash[:plugin])
    assert_equal(interval, hash[:interval])
    assert hash[:labels].keys.sort == [:app, :foo, :pid, :tid],
      "Wrong keys #{hash[:labels].keys.inspect} in default labels!"
  end

  def test_every
    Hastur.__reset_bg_thread__

    Hastur.every :minute do
      Hastur.mark("test_every")
    end

    # Make the "every" background thread think it's later than it is
    tn = Time.now
    Time.stubs(:now).returns(tn + 65)
    sleep 2  # Then sleep long enough that it woke up and ran

    msgs = test_messages
    hash = msgs[-1]
    assert hash != nil, "Hash cannot be nil"
    assert_equal("test_every", hash[:name])
  end
end