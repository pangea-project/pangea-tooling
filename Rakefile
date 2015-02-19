require "ci/reporter/rake/test_unit"
require "rake/testtask"

Rake::TestTask.new do |t|
    t.ruby_opts << "-r#{File.expand_path(File.dirname(__FILE__))}/test/helper.rb"
    t.test_files = FileList["test/test_*.rb", "ci-tooling/test/test_*.rb"]
    t.verbose = true
end
task :test => "ci:setup:testunit"
