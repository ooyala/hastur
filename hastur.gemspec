# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hastur/version"

Gem::Specification.new do |s|
  s.name        = "hastur"
  s.version     = Hastur::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Viet Nguyen"]
  s.email       = ["viet@ooyala.com"]
  s.homepage    = "http://www.ooyala.com"
  s.description = "Hastur API client gem"
  s.summary     = "A gem used to communicate with the Hastur Client through UDP."
  s.rubyforge_project = "hastur"

  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

  s.add_development_dependency "yard"
  s.add_development_dependency "redcarpet"
  s.add_development_dependency "mocha"
  s.add_development_dependency "minitest", "= 3.5.0"
  s.add_development_dependency "simplecov" if RUBY_VERSION[/^1.9/]
  s.add_development_dependency "rake"
  s.add_runtime_dependency "multi_json", ">=1.3.2"
  s.add_runtime_dependency "chronic"

  s.files         = `git ls-files`.split("\n")
  s.require_paths = ["lib"]
end
