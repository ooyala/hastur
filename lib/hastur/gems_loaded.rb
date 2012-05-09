require "rubygems"

# Gems on load path
# http://stackoverflow.com/questions/2747990
gem_versions = Gem.loaded_specs.values.map { |x| [ x.name, x.version] }
loaded_gems = {}
gem_versions.each do |name, version|
  loaded_gems[name] = version
end

Hastur.info_process "loaded_gems", loaded_gems

# http://stackoverflow.com/questions/7190015
loaded_features = $LOADED_FEATURES.
  select { |feature| feature.include? 'gems' }.
  map { |feature| File.dirname(feature) }.
  map { |feature| feature.split("/").last }.
  uniq.sort

Hastur.info_process "loaded_features", loaded_features
