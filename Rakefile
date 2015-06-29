require 'bundler/setup' # Make sure load paths are in order

require 'ci/reporter/rake/test_unit'
require 'fileutils'
require 'rake/clean'
require 'rake/notes/rake_task'
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

desc 'deploy to all nodes'
task :deploy_nodes do
  require 'logger'
  require 'net/scp'
  require_relative 'ci-tooling/lib/jenkins'
  log = Logger.new(STDERR)
  tooling_path = File.join(Dir.home, 'tooling-pending')
  Jenkins.client.node.list.each do |node|
    log.info "deploy on #{node}"
    next if node == 'master'
    Net::SCP.start(node, 'jenkins-slave') do |scp|
      log.info 'cleanup'
      # FIXME: needs to go to temp path first, then bundle then to final
      puts scp.session.exec!('rm -rf /var/lib/jenkins-slave/tooling-pending')
      log.info 'pushing'
      puts scp.upload!(tooling_path, '/var/lib/jenkins-slave/tooling-pending',
                       recursive: true, verbose: true)
      log.info 'remote deploy'
      puts scp.session.exec('/var/lib/jenkins-slave/tooling-pending/deploy_on_node.sh') do |_channel, _stream, data|
        if stream == :stderr
          @log.error data
        else
          @log.info data
        end
      end
      log.info 'done'
    end
  end
end
task :deploy_nodes => :deploy
