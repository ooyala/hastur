$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

if ENV['COVERAGE'] && RUBY_VERSION[/^1.9/]
  require "simple_cov"
  SimpleCov.start
end
