require 'bundler/setup' # Make sure load paths are in order

require 'ci/reporter/rake/test_unit'
require 'fileutils'
require 'rake/clean'
require 'rake/notes/rake_task'
require 'rake/testtask'
require 'rubocop/rake_task'

BIN_DIRS = %w(
  .
  ci-tooling
)
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
)

desc 'run unit tests'
Rake::TestTask.new do |t|
  t.ruby_opts << "-r#{File.expand_path(__dir__)}/test/helper.rb"
  t.test_files = FileList['test/test_*.rb', 'ci-tooling/test/test_*.rb']
  t.verbose = true
end
task :test => 'ci:setup:testunit'
CLEAN << 'coverage' # Created through helper's simplecov
CLEAN << 'test/reports'

desc 'run ci-tooling tests'
Rake::TestTask.new(:test_ci) do |t|
  t.ruby_opts << "-r#{File.expand_path(__dir__)}/test/helper.rb"
  t.test_files = FileList['ci-tooling/test/test_*.rb']
  t.verbose = true
end

desc 'run pangea-tooling tests'
Rake::TestTask.new(:test_pangea) do |t|
  t.ruby_opts << "-r#{File.expand_path(__dir__)}/test/helper.rb"
  t.test_files = FileList['test/test_*.rb']
  t.verbose = true
end

desc 'generate line count report'
task :cloc do
  system("cloc --by-file --xml --out=cloc.xml #{SOURCE_DIRS.join(' ')}")
end
CLEAN << 'cloc.xml'

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
