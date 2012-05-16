require "multi_json"
require "socket"
require "date"
require "thread"

#
# Hastur API gem that allows services/apps to easily publish
# correct Hastur-commands to their local machine's UDP sockets.
# Bare minimum for all JSON packets is to have :type key/values to
# map to a hastur message type, which the router uses for sink delivery.
#
module Hastur
  extend self

  # TODO(noah): Change all instance variables to use Hastur.variable
  # and add attr_reader/attr_accessor for them if appropriate.
  # Right now you could use a mix of Hastur.variable and including
  # the Hastur module and get two full sets of Hastur stuff.
  # This will only matter if people include Hastur directly,
  # which we haven't documented as possible.

  class << self
    attr_accessor :mutex
  end

  Hastur.mutex ||= Mutex.new

  SECS_2100       = 4102444800
  MILLI_SECS_2100 = 4102444800000
  MICRO_SECS_2100 = 4102444800000000
  NANO_SECS_2100  = 4102444800000000000

  SECS_1971       = 31536000
  MILLI_SECS_1971 = 31536000000
  MICRO_SECS_1971 = 31536000000000
  NANO_SECS_1971  = 31536000000000000

  PLUGIN_INTERVALS = [ :five_minutes, :thirty_minutes, :hourly, :daily, :monthly ]

  #
  # Prevents starting a background thread under any circumstances.
  #
  def no_background_thread!
    @prevent_background_thread = true
  end

  START_OPTS = [
    :background_thread
  ]

  #
  # Start Hastur's background thread and/or do process registration
  # or neither, according to what options are set.
  #
  # @param [Hash] opts The options for features
  # @option opts [boolean] :background_thread Whether to start a background thread
  #
  def start(opts = {})
    bad_keys = opts.keys - START_OPTS
    raise "Unknown options to Hastur.start: #{bad_keys.join(", ")}!" unless bad_keys.empty?

    unless @prevent_background_thread ||
        (opts.has_key?(:background_thread) && !opts[:background_thread])
      start_background_thread
    end

    register_process Hastur.app_name, {}
  end

  #
  # Starts a background thread that will execute blocks of code every so often.
  #
  def start_background_thread
    if @prevent_background_thread
      raise "You can't start a background thread!  Somebody called .no_background_thread! already."
    end

    return if @bg_thread

    @intervals = [:five_secs, :minute, :hour, :day]
    @interval_values = [5, 60, 60*60, 60*60*2 ]
    __reset_bg_thread__
  end

  #
  # This should ordinarily only be for testing.  It kills the
  # background thread so that automatic heartbeats and .every() blocks
  # don't happen.
  #
  def kill_background_thread
    __kill_bg_thread__
  end

  #
  # Returns whether the background thread is currently running.
  # @todo Debug this.
  #
  def background_thread?
    @bg_thread && !@bg_thread.alive?
  end

  #
  # Best effort to make all timestamps be Hastur timestamps, 64 bit
  # numbers that represent the total number of microseconds since Jan
  # 1, 1970 at midnight UTC.  Accepts second, millisecond or nanosecond
  # timestamps and Ruby times.  You can also give :now or nil for Time.now.
  #
  # @param timestamp The timestamp as a Fixnum, Float or Time.  Defaults to Time.now.
  # @return [Fixnum] Number of microseconds since Jan 1, 1970 midnight UTC
  # @raise RuntimeError Unable to validate timestamp format
  #
  def epoch_usec(timestamp=Time.now)
    timestamp = Time.now if timestamp.nil? || timestamp == :now

    case timestamp
    when Time
      (timestamp.to_f*1000000).to_i
    when DateTime
      # Ruby 1.8.7 doesn't have to DateTime#to_time or DateTime#to_f method.
      # For right now, declare failure.
      raise "Ruby DateTime objects are not yet supported!"
    when SECS_1971..SECS_2100
      timestamp * 1000000
    when MILLI_SECS_1971..MILLI_SECS_2100
      timestamp * 1000
    when MICRO_SECS_1971..MICRO_SECS_2100
      timestamp
    when NANO_SECS_1971..NANO_SECS_2100
      timestamp / 1000
    else
      raise "Unable to validate timestamp: #{timestamp}"
    end
  end

  alias :timestamp :epoch_usec

  #
  # Attempts to determine the application name.
  # Consults $0 and Ecology, if present.
  # @return [String] The application name, or best guess at same
  #
  def app_name
    return @app_name if @app_name

    eco = Ecology rescue nil
    return @app_name = Ecology.application if eco

    @app_name = File.basename $0
  end
  alias application app_name

  #
  # Set the application name that Hastur registers as.
  #
  # @param [String] new_name The new application name.
  #
  def app_name=(new_name)
    @app_name = new_name
  end
  alias application= app_name=

  #
  # Add default labels which will be sent back with every Hastur
  # message sent by this process.  The labels will be sent back with
  # the same constant value each time that is specified in the labels
  # hash.
  #
  # This is a useful way to send back information that won't change
  # during the run, or that will change only occasionally like
  # resource usage, server information, deploy environment, etc.  The
  # same kind of information can be sent back using info_process(), so
  # consider which way makes more sense for your case.
  #
  # @param [Hash] new_default_labels A hash of new labels to send.
  #
  def add_default_labels(new_default_labels)
    @default_labels ||= {}

    @default_labels.merge!
  end

  #
  # Remove default labels which will be sent back with every Hastur
  # message sent by this process.  This cannot remove the three
  # automatic defaults (application, pid, tid).  Keys that have not
  # been added cannot be removed, and so will be silently ignored (no
  # exception will be raised).
  #
  # @param [Array<String> or multiple strings] default_label_keys Keys to stop sending
  #
  def remove_default_label_names(*default_label_keys)
    keys_to_remove = default_label_keys.flatten

    keys_to_remove.each { |key| @default_labels.delete(key) }
  end

  #
  # Reset the default labels which will be sent back with every Hastur
  # message sent by this process.  After this, only the automatic
  # default labels (process ID, thread ID, application name) will be
  # sent, plus of course the ones specified for the specific Hastur
  # message call.
  #
  def reset_default_labels
    @default_labels = {}
  end

  protected

  #
  # Returns the default labels for any UDP message that ships.
  #
  def default_labels
    pid = Process.pid
    thread = Thread.current
    unless thread[:tid]
      thread[:tid] = thread_id(thread)
    end

    {
      :pid => pid,
      :tid => thread[:tid],
      :app => app_name,
    }
  end

  #
  # This is a convenience function because the Ruby
  # thread API has no accessor for the thread ID,
  # but includes it in "to_s" (buh?)
  #
  def thread_id(thread)
    return 0 if thread == Thread.main

    str = thread.to_s

    match = nil
    match  = str.match /(0x\d+)/
    return nil unless match
    match[1].to_i
  end

  #
  # Returns whether Hastur is in test mode
  #
  def test_mode
    STDERR.puts "Test mode is deprecated: 2012/5/7"
    @test_mode || false
  end

  #
  # Get the UDP port.
  #
  # @return The UDP port.  Defaults to 8125.
  #
  def udp_port
    @udp_port || 8125
  end

  #
  # Sends a message unmolested to the HASTUR_UDP_PORT on 127.0.0.1
  #
  # @param m The message to send
  #
  def send_to_udp(m)
    if @__test_mode__
      @__test_msgs__ ||= []
      @__test_msgs__ << m
    elsif @__delivery_method__
      @__delivery_method__.call(m)
    else
      __send_to_udp__(m)
    end
  end

  private

  def __send_to_udp__(m)
    begin
      u = ::UDPSocket.new
      mj = MultiJson.dump m
      u.send mj, 0, "127.0.0.1", udp_port
    rescue Errno::EMSGSIZE => e
      return if @no_recurse
      @no_recurse = true
      err = "Message too long to send via Hastur UDP Socket. " +
        "Backtrace: #{e.backtrace.inspect} " + "(Truncated) Message: #{mj}"
      Hastur.log err
      @no_recurse = false
    rescue Exception => e
      return if @no_recurse
      @no_recurse = true
      err = "Exception sending via Hastur UDP Socket. " + "Exception: #{e.message} " +
        "Backtrace: #{e.backtrace.inspect} " + "(Truncated) Message: #{mj}"
      Hastur.log err
      @no_recurse = false

    end
  end

  public

  #
  # The list of messages that were queued up when in test mode.
  #
  # @return The list of messages in JSON format
  #
  def __test_msgs__
    STDERR.puts "Test mode is deprecated: 2012/5/7"
    @__test_msgs__ ||= []
  end

  #
  # Clears the list of buffered messages.
  #
  def __clear_msgs__
    STDERR.puts "Test mode is deprecated: 2012/5/7"
    @__test_msgs__.clear if @__test_msgs__
  end

  #
  # Kills the background thread if it's running.
  #
  def __kill_bg_thread__
    if @bg_thread
      @bg_thread.kill
      @bg_thread = nil
    end
  end

  #
  # Resets Hastur's background thread, removing all scheduled
  # callbacks and resetting the times for all intervals.  This is TEST
  # MODE ONLY and will do TERRIBLE THINGS IF CALLED IN PRODUCTION.
  #
  def __reset_bg_thread__
    if @prevent_background_thread
      raise "You can't start a background thread!  Somebody called .no_background_thread! already."
    end

    __kill_bg_thread__

    @last_time ||= Hash.new

    @mutex.synchronize do
      @scheduled_blocks ||= Hash.new

      # initialize all of the scheduling hashes
      @intervals.each do |interval|
        @last_time[interval] = Time.at(0)
        @scheduled_blocks[interval] = []
      end
    end

    # add a heartbeat background job
    every :minute do
      heartbeat("process_heartbeat")
    end

    # define a thread that will schedule and execute all of the background jobs.
    # it is not very accurate on the scheduling, but should not be a problem
    @bg_thread = Thread.new do
      begin
        loop do
          # for each of the interval buckets
          curr_time = Time.now

          @intervals.each_with_index do |interval, idx|
            to_call = []

            # Don't need to dup this because we never change the old
            # array, only reassign a new one.
            @mutex.synchronize { to_call = @scheduled_blocks[interval] }

            # execute the scheduled items if time is up
            if curr_time - @last_time[ interval ] >= @interval_values[idx]
              @last_time[interval] = curr_time
              to_call.each(&:call)
            end
          end

          # TODO(noah): increase this time
          sleep 1       # rest
        end
      rescue Exception => e
        STDERR.puts e.inspect
      end
    end
  end

  #
  # Set delivery method to the given proc/block.  The block is saved
  # and called with each message to be sent.  If no block is given or
  # if this method is not called, the delivery method defaults to
  # sending over the configured UDP port.
  #
  def deliver_with(&block)
    @__delivery_method__ = block
  end

  #
  # Switches the behavior of how messages gets handled. If test_mode is on, then
  # all messages are buffered in memory instead of getting shipped through UDP.
  # Only use this method for testing purposes.
  #
  # @param [boolean] test_mode True to set test_mode, false to clear it.
  #
  def __test_mode__=(test_mode)
    STDERR.puts "Test mode is deprecated: 2012/5/7"
    @__test_mode__ = test_mode
  end

  #
  # Set the UDP port.  Defaults to 8125
  #
  # @param [Fixnum] new_port The new port number.
  #
  def udp_port=(new_port)
    @udp_port = new_port
  end

  #
  # Sends a 'mark' stat to Hastur.  A mark gives the time that
  # an interesting event occurred even with no value attached.
  # You can also use a mark to send back string-valued stats
  # that might otherwise be guages -- "Green", "Yellow",
  # "Red" or similar.
  #
  # It is different from a Hastur event because it happens at
  # stat priority -- it can be batched or slightly delayed,
  # and doesn't have an end-to-end acknowledgement included.
  #
  # @param [String] name The mark name
  # @param [String] value An optional string value
  # @param timestamp The timestamp as a Fixnum, Float, Time or :now
  # @param [Hash] labels Any additional data labels to send
  #
  def mark(name, value = nil, timestamp=:now, labels={})
    send_to_udp :type      => :mark,
                :name      => name,
                :value     => value,
                :timestamp => epoch_usec(timestamp),
                :labels    => default_labels.merge(labels)
  end

  #
  # Sends a 'counter' stat to Hastur.  Counters are linear,
  # and are sent as deltas (differences).  Sending a
  # value of 1 adds 1 to the counter.
  #
  # @param [String] name The counter name
  # @param [Fixnum] value Amount to increment the counter by
  # @param timestamp The timestamp as a Fixnum, Float, Time or :now
  # @param [Hash] labels Any additional data labels to send
  #
  def counter(name, value=1, timestamp=:now, labels={})
    send_to_udp :type      => :counter,
                :name      => name,
                :value     => value,
                :timestamp => epoch_usec(timestamp),
                :labels    => default_labels.merge(labels)
  end

  #
  # Sends a 'gauge' stat to Hastur.  A gauge's value may or may
  # not be on a linear scale.  It is sent as an exact value, not
  # a difference.
  #
  # @param [String] name The mark name
  # @param value The value of the gauge as a Fixnum or Float
  # @param timestamp The timestamp as a Fixnum, Float, Time or :now
  # @param [Hash] labels Any additional data labels to send
  #
  def gauge(name, value, timestamp=:now, labels={})
    send_to_udp :type      => :gauge,
                :name      => name,
                :value     => value,
                :timestamp => epoch_usec(timestamp),
                :labels    => default_labels.merge(labels)
  end

  #
  # Sends an event to Hastur.  An event is high-priority and never buffered,
  # and will be sent preferentially to stats or heartbeats.  It includes
  # an end-to-end acknowledgement to ensure arrival, but is expensive
  # to store, send and query.
  #
  # 'Attn' is a mechanism to describe the system or component in which the
  # event occurs and who would care about it.  Obvious values to include in the
  # array include user logins, email addresses, team names, and server, library
  # or component names.  This allows making searches like "what events should I
  # worry about?" or "what events have recently occurred on the Rails server?"
  #
  # @param [String] name The name of the event (ex: "bad.log.line")
  # @param [String] subject The subject or message for this specific event (ex "Got bad log line: @#$#@garbage@#$#@")
  # @param [String] body An optional body with details of the event.  A stack trace or email body would go here.
  # @param [Array] attn The relevant components or teams for this event.  Web hooks or email addresses would go here.
  # @param timestamp The timestamp as a Fixnum, Float, Time or :now
  # @param [Hash] labels Any additional data labels to send
  #
  def event(name, subject=nil, body=nil, attn=[], timestamp=:now, labels={})
    send_to_udp :type => :event,
                :name => name,
                :subject => subject.to_s[0...3_072],
                :body => body.to_s[0...3_072],
                :attn => [ attn ].flatten,
                :timestamp => epoch_usec(timestamp),
                :labels  => default_labels.merge(labels)
  end

  #
  # Sends a log line to Hastur.  A log line is of relatively low
  # priority, comparable to stats, and is allowed to be buffered or
  # batched while higher-priority data is sent first.
  #
  # Severity can be included in the data field with the tag
  # "severity" if desired.
  #
  # @param [String] subject The subject or message for this specific log (ex "Got bad input: @#$#@garbage@#$#@")
  # @param [Hash] data Additional JSON-able data to be sent
  # @param timestamp The timestamp as a Fixnum, Float, Time or :now
  # @param [Hash] labels Any additional data labels to send
  #
  def log(subject=nil, data={}, timestamp=:now, labels={})
    send_to_udp :type => :log,
                :subject => subject.to_s[0...7_168],
                :data => data,
                :timestamp => epoch_usec(timestamp),
                :labels => default_labels.merge(labels)
  end

  #
  # Sends a process registration to Hastur.  This indicates that the
  # process is currently running, and that heartbeats should be sent
  # for some time afterward.
  #
  # @param [String] name The name of the application or best guess
  # @param [Hash] data The additional data to include with the registration
  # @param timestamp The timestamp as a Fixnum, Float, Time or :now
  # @param [Hash] labels Any additional data labels to send
  #
  def register_process(name = app_name, data = {}, timestamp = :now, labels = {})
    send_to_udp :type      => :reg_process,
                :data      => data,
                :timestamp => epoch_usec(timestamp),
                :labels    => default_labels.merge(labels)
  end

  #
  # Sends freeform process information to Hastur.  This can be
  # supplemental information about resources like memory, loaded gems,
  # Ruby version, files open and whatnot.  It can be additional
  # configuration or deployment information like environment
  # (dev/staging/prod), software or component version, etc.  It can be
  # information about the application as deployed, as run, or as it is
  # currently running.
  #
  # The default labels contain application name and process ID to
  # match this information with the process registration and similar
  # details.
  #
  # Any number of these can be sent as information changes or is
  # superceded.  However, if information changes constantly or needs
  # to be graphed or alerted on, send that separately as a metric or
  # event.  Info_process messages are freeform and not readily
  # separable or graphable.
  #
  # @param [String] tag The tag or title of this chunk of process info
  # @param [Hash] data The detailed data being sent
  # @param timestamp The timestamp as a Fixnum, Float, Time or :now
  # @param [Hash] labels Any additional data labels to send
  #
  def info_process(tag, data = {}, timestamp = :now, labels = {})
    send_to_udp :type      => :info_process,
                :tag       => tag,
                :data      => data,
                :timestamp => epoch_usec(timestamp),
                :labels    => default_labels.merge(labels)
  end

  #
  # This sends back freeform data about the agent or host that Hastur
  # is running on.  Sample uses include what libraries or packages are
  # installed and available, the total installed memory
  #
  # Any number of these can be sent as information changes or is
  # superceded.  However, if information changes constantly or needs
  # to be graphed or alerted on, send that separately as a metric or
  # event.  Info_agent messages are freeform and not readily separable
  # or graphable.
  #
  # @param [String] tag The tag or title of this chunk of process info
  # @param [Hash] data The detailed data being sent
  # @param timestamp The timestamp as a Fixnum, Float, Time or :now
  # @param [Hash] labels Any additional data labels to send
  #
  def info_agent(tag, data = {}, timestamp = :now, labels = {})
    send_to_udp :type      => :info_agent,
                :tag       => tag,
                :data      => data,
                :timestamp => epoch_usec(timestamp),
                :labels    => default_labels.merge(labels)
  end

  #
  # Sends a plugin registration to Hastur.  A plugin is a program on the host machine which
  # can be run to determine status of the machine, an application or anything else interesting.
  #
  # This registration tells Hastur to begin scheduling runs
  # of the plugin and report back on the resulting status codes or crashes.
  #
  # @param [String] name The name of the plugin, and of the heartbeat sent back
  # @param [String] plugin_path The path on the local file system to this plugin executable
  # @param [Array] plugin_args The array of arguments to pass to the plugin executable
  # @param [Symbol] plugin_interval The interval to run the plugin.  The scheduling will be slightly approximate.  One of:  PLUGIN_INTERVALS
  # @param timestamp The timestamp as a Fixnum, Float, Time or :now
  # @param [Hash] labels Any additional data labels to send
  #
  def register_plugin(name, plugin_path, plugin_args, plugin_interval, timestamp=:now, labels={})
    unless PLUGIN_INTERVALS.include?(plugin_interval)
      raise "Interval must be one of: #{PLUGIN_INTERVALS.join(', ')}"
    end
    send_to_udp :type        => :reg_pluginv1,
                :plugin_path => plugin_path,
                :plugin_args => plugin_args,
                :interval    => plugin_interval,
                :plugin      => name,
                :timestamp   => epoch_usec(timestamp),
                :labels      => default_labels.merge(labels)
  end

  #
  # Sends a heartbeat to Hastur.  A heartbeat is a periodic
  # message which indicates that a host, application or
  # service is currently running.  It is higher priority
  # than a statistic and should not be batched, but is
  # lower priority than an event does not include an
  # end-to-end acknowledgement.
  #
  # Plugin results are sent as a heartbeat with the
  # plugin's name as the heartbeat name.
  #
  # @param [String] name The name of the heartbeat.
  # @param value The value of the heartbeat as a Fixnum or Float
  # @param [Float] timeout How long in seconds to expect to wait, at maximum, before the next heartbeat.  If this is nil, don't worry if it doesn't arrive.
  # @param timestamp The timestamp as a Fixnum, Float, Time or :now
  # @param [Hash] labels Any additional data labels to send
  #
  def heartbeat(name="application.heartbeat", value=nil, timeout = nil, timestamp=:now, labels={})
    send_to_udp :name => name,
                :type => :hb_process,
                :value => value,
                :timestamp => epoch_usec(timestamp),
                :labels    => default_labels.merge(labels)
  end

  #
  # Runs a block of code periodically every interval.
  # Use this method to report statistics at a fixed time interval.
  #
  # @param [Symbol] every How often to run.  One of [:five_secs, :minute, :hour, :day]
  # @yield [] A block which will send Hastur messages, called periodically
  #
  def every(interval, &block)
    if @prevent_background_thread
      log("You called .every(), but background threads are specifically prevented.")
    end

    unless @intervals.include?(interval)
      raise "Interval must be one of these: #{@intervals}, you gave #{interval.inspect}"
    end

    # Don't add to existing array.  += will create a new array.  Then
    # when we save a reference to the old array and iterate through
    # it, it won't change midway.
    Hastur.mutex.synchronize { @scheduled_blocks[interval] += [ block ] }
  end
end
