require 'bundler/setup' # Make sure load paths are in order

require 'fileutils'
require 'rake/clean'
require 'rake/testtask'

begin
  require 'ci/reporter/rake/test_unit'
rescue LoadError
  puts 'ci_reporter_test_unit not installed, skipping'
end
begin
  require 'rake/notes/rake_task'
rescue LoadError
  puts 'rake-notes not installed, skipping'
end

BIN_DIRS = %w(
  .
  ci-tooling
).freeze
SOURCE_DIRS = %w(
  ci-tooling/ci
  ci-tooling/dci
  ci-tooling/kci
  ci-tooling/lib
  ci-tooling/mci
  ci-tooling/nci
  dci
  git-monitor
  jenkins-jobs
  kci
  lib
  mci
  nci
  mgmt
  mobster
  s3-images-generator
).freeze

desc 'run all unit tests'
task :test do
  # We separately run pangea (host) and ci-tooling (host/container) tooling
  # as former is not particularly suited to parallel exceution due to it
  # using a live docker, so reentrancy and so forth is a concern.
  # Latter however is perfectly suited and is run in parallel to speed up
  # test execution.
end
task :test => 'ci:setup:testunit'
task :test => :test_pangea
task :test => :test_ci_parallel
CLEAN << 'coverage' # Created through helper's simplecov
CLEAN << 'test/reports'

desc 'run ci-tooling tests (this runs in sync via TestTask)'
Rake::TestTask.new(:test_ci) do |t|
  t.ruby_opts << "-r#{File.expand_path(__dir__)}/test/helper.rb"
  t.test_files = FileList['ci-tooling/test/test_*.rb']
  t.verbose = true
end

desc 'run ci-tooling tests in parallel'
task :test_ci_parallel do
  ENV['PARALLEL_TESTS_EXECUTABLE'] = "ruby -r#{__dir__}/test/helper.rb"
  opts = []
  opts << '--serialize-stdout'
  opts << '--combine-stderr'
  opts << '--nice'
  opts << '--verbose'
  test_files = FileList['ci-tooling/test/test_*.rb']
  sh('parallel_test', *opts, *test_files)
end
task :test_ci_parallel => 'ci:setup:testunit'

desc 'run pangea-tooling (parse) test'
Rake::TestTask.new(:test_pangea_parse) do |t|
  # Parse takes forever, so we run it concurrent to the other tests.
  t.test_files = FileList['test/test_parse.rb']
  t.verbose = true
end

desc 'run pangea-tooling tests'
Rake::TestTask.new(:test_pangea_core) do |t|
  t.ruby_opts << "-r#{File.expand_path(__dir__)}/test/helper.rb"
  t.test_files = FileList['test/test_*.rb'].exclude('test/test_parse.rb')
  t.verbose = true
end
multitask :test_pangea => [:test_pangea_parse, :test_pangea_core]

desc 'generate line count report'
task :cloc do
  system("cloc --by-file --xml --out=cloc.xml #{SOURCE_DIRS.join(' ')}")
end
CLEAN << 'cloc.xml'

begin
  require 'rubocop/rake_task'

  desc 'Run RuboCop on the lib directory'
  RuboCop::RakeTask.new(:rubocop) do |task|
    task.requires << 'rubocop/formatter/checkstyle_formatter'
    BIN_DIRS.each { |bindir| task.patterns << "#{bindir}/*.rb" }
    SOURCE_DIRS.each { |srcdir| task.patterns << "#{srcdir}/**/*.rb" }
    task.formatters = ['RuboCop::Formatter::CheckstyleFormatter']
    task.options << '--out' << 'checkstyle.xml'
    task.fail_on_error = false
    task.verbose = false
  end
  CLEAN << 'checkstyle.xml'
rescue LoadError
  puts 'rubocop not installed, skipping'
end

desc 'deploy host and containment tooling'
task :deploy do
  system('bundle pack')

  # Pending for pickup by LXC.
  tooling_path = File.join(Dir.home, 'tooling-pending')
  FileUtils.rm_rf(tooling_path)
  FileUtils.mkpath(tooling_path)
  FileUtils.cp_r(Dir.glob('*'), tooling_path)

  # Live for host.
  # FIXME: not all host jobs are blocked by mgmt_tooling and can run into
  # problems when reading a file while we deploy.
  tooling_path = File.join(Dir.home, 'tooling3')
  FileUtils.rm_rf(tooling_path)
  FileUtils.mkpath(tooling_path)
  FileUtils.cp_r(Dir.glob('*'), tooling_path)
end
