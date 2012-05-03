require "bundler/gem_tasks"
require "rake/testtask"

namespace "test" do
  desc "Run all unit tests"
  Rake::TestTask.new(:units) do |t|
    t.libs += ["test"]
    t.test_files = Dir["test/*_test.rb"]
    t.verbose = true
  end
end

inclusion_tests = Dir["test/inclusion/*_test.rb"]

inclusion_tests.each do |test_filename|
  test_name = test_filename.split("/")[-1].sub(/_test\.rb$/, "").gsub("_", " ")

  desc "Hastur #{test_name} inclusion test"
  task "test:inclusion:#{test_name}" do
    system("ruby", "-I.", test_filename)
    raise "Test #{test_name} failed!" unless $?.success?
  end

  task "test:inclusions" => "test:inclusion:#{test_name}"
end

task "test" => [ "test:units", "test:inclusions" ]
