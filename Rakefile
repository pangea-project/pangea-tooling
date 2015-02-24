require 'ci/reporter/rake/test_unit'
require 'fileutils'
require 'rake/clean'
require 'rake/testtask'
require 'rubocop/rake_task'

SOURCE_DIRS = %w(
  ci-tooling/dci
  ci-tooling/kci
  ci-tooling/lib
  dci
  git-monitor
  jenkins-jobs
  kci
  lib
  s3-images-generator
  schroot-scripts
)

desc 'run unit tests'
Rake::TestTask.new do |t|
  t.ruby_opts << "-r#{File.expand_path(File.dirname(__FILE__))}/test/helper.rb"
  t.test_files = FileList["test/test_*.rb", "ci-tooling/test/test_*.rb"]
  t.verbose = true
end
task :test => 'ci:setup:testunit'
CLEAN << 'coverage' # Created through helper's simplecov
CLEAN << 'test/reports'

desc 'generate line count report'
task :cloc do
  system("cloc --by-file --xml --out=cloc.xml #{SOURCE_DIRS.join(' ')}")
end
CLEAN << 'cloc.xml'

desc 'Run RuboCop on the lib directory'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.requires << 'rubocop/formatter/checkstyle_formatter'
  SOURCE_DIRS.each do |srcdir|
    task.patterns << "#{srcdir}/**/*.rb"
  end
  task.formatters = ['RuboCop::Formatter::CheckstyleFormatter']
  task.options << '--out' << 'checkstyle.xml'
  task.fail_on_error = false
  task.verbose = false
end
CLEAN << 'checkstyle.xml'

desc 'deploy to ~/tooling-pending for processing by LXC jobs'
task :deploy do
  `bundle pack`
  tooling_path = File.join(Dir.home, 'tooling-pending')
  FileUtils.rm_rf(tooling_path)
  FileUtils.mkpath(tooling_path)
  FileUtils.cp_r(Dir.glob('*'), tooling_path)
end
