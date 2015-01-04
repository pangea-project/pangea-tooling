require "ci/reporter/rake/test_unit"
require "rake/testtask"

Rake::TestTask.new do |t|
    t.test_files = FileList["test/test-*.rb"]
    t.verbose = true
end
task :test => "ci:setup:testunit"
