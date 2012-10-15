require 'hastur/api'

module Hastur
  #
  # Send Process.times information as gauges.
  # Stat names are automatically set to:
  #  hastur.process.utime - user time
  #  hastur.process.stime - system time
  #  hastur.process.cutime - child process user time
  #  hastur.process.cstime - child process system time
  #
  # @example
  #   Hastur.send_process_times
  #
  def send_process_times
    now = Time.now
    t = Process.times

    # amount of user/system cpu time in seconds
    Hastur.gauge("hastur.process.utime", t.utime, now)
    Hastur.gauge("hastur.process.stime", t.stime, now)

    # completed child processes' user/system cpu time in seconds (always 0 on Windows NT)
    Hastur.gauge("hastur.process.cutime", t.cutime, now)
    Hastur.gauge("hastur.process.cstime", t.cstime, now)
  end
end
