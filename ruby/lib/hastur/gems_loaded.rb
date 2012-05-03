require "rubygems"

# Eventually we want a real plugin mechanism for this.

# Gems on load path
# http://stackoverflow.com/questions/2747990
loaded_gems = Gem.loaded_specs.valus.map { |x| "#{x.name} #{x.version}" }

# http://stackoverflow.com/questions/7190015
loaded_features = $LOADED_FEATURES.
  select { |feature| feature.include? 'gems' }.
  map { |feature| File.dirname(feature) }.
  map { |feature| feature.split("/").last }.
  uniq.sort

# TODO(noah): Include this in process registration
