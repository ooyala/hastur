require "rubygems"
require "goliath"
require "em-synchrony/em-http"
require "time"

$LOAD_PATH << File.join(File.dirname(__FILE__), "../lib")
require "hastur/eventmachine"

class GetProxy < Goliath::API
  use Goliath::Rack::Params

  attr_reader :backend
  def initialize
    ::ARGV.each_with_index do |arg,idx|
      if arg == "--backend"
        @backend = ::ARGV[idx + 1]
        ::ARGV.slice! idx, 2
        break
      end
    end

    unless @backend
      raise "Initialization error: could not determine backend server, try --backend <url>"
    end

    super
  end

  def response(env)
    url = "#{@backend}#{env['REQUEST_PATH']}"
    start = Hastur.timestamp
    http = EM::HttpRequest.new(url).get :query => params
    done = Hastur.timestamp

    uri = URI.parse url

    # Hastur was designed to be queried ground-up using labels. Liberal use
    # of labels is recommended. We add labels as we need them.
    labels = { :scheme => uri.scheme,
               :host   => uri.host,
               :port   => uri.port
    }

    case http.response_header.status
    when 300..307
      # Marks are interesting, but non-critical points. Value defaults to nil,
      # timestamp defaults to 'now'.
      Hastur.mark(
        "test.proxy.3xx", # name
        nil,              # value
        start,            # timestamp
        :status => :moved # label
      )
      labels[:status] = "3xx"
    when 400..417
      # Log is used for low priority data that will be buffered and batched by
      # Hastur. Severity is optional and irrelevant to delivery.
      Hastur.log(
        "test.proxy.4xx",      # name
        {                      # data
          :path => uri.path,
          :query => uri.query,
        },
        start                  # timestamp
      )
      labels[:status] = "4xx"
    when 500.505
      # Event is serious business. Hastur will punish the little elves crankin
      # in it bowels mercilessly to get this out and about ASAP.
      Hastur.event(
        "test.proxy.5xx",        # name
        "Internal Server Error", # subject
        nil,                     # body
        ["devnull@ooyala.com"],  # attn
        start,                   # timestamp
        :path => uri.path,       # labels
        :query => uri.query      # labels
      )
      labels[:status] = "5xx"
    end

    # Gauges are used to track values.
    Hastur.gauge(
      # Use . to separate namespaces in Hastur.
      "test.proxy.latencies.ttr", # name
      done.to_f - start.to_f,     # value
      start,                      # timestamp
      labels                      # labels
    )

    [http.response_header.status, http.response_header, http.response]
  end
end
