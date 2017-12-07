# frozen_string_literal: true
#
# Copyright (C) 2015-2017 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

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

require_relative 'lib/rake/bundle'

BIN_DIRS = %w[
  .
  ci-tooling
  overlay-bin
].freeze
SOURCE_DIRS = %w[
  ci-tooling/ci
  ci-tooling/dci
  ci-tooling/lib
  ci-tooling/mci
  ci-tooling/nci
  dci
  jenkins-jobs
  lib
  mci
  nci
  mgmt
  overlay-bin
  overlay-bin/lib
].freeze

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

  desc 'Run RuboCop on the lib directory (xml)'
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

  desc 'Run RuboCop on the lib directory (html)'
  RuboCop::RakeTask.new('rubocop::html') do |task|
    task.requires << 'rubocop/formatter/html_formatter'
    BIN_DIRS.each { |bindir| task.patterns << "#{bindir}/*.rb" }
    SOURCE_DIRS.each { |srcdir| task.patterns << "#{srcdir}/**/*.rb" }
    task.formatters = ['RuboCop::Formatter::HTMLFormatter']
    task.options << '--out' << 'rubocop.html'
    task.fail_on_error = false
    task.verbose = false
  end
  CLEAN << 'rubocop.html'
rescue LoadError
  puts 'rubocop not installed, skipping'
end

desc 'deploy host and containment tooling'
task :deploy do
  bundle(*%w[_1.15.4_ pack --all-platforms --no-install])

  # Pending for pickup by container.
  tooling_path_pending = File.join(Dir.home, 'tooling-pending')
  FileUtils.rm_rf(tooling_path_pending)
  FileUtils.mkpath(tooling_path_pending)
  FileUtils.cp_r('.', tooling_path_pending, verbose: true)

  # Live for host.
  tooling_path = File.join(Dir.home, 'tooling')
  tooling_path_staging = File.join(Dir.home, 'tooling-staging')
  tooling_path_compat = File.join(Dir.home, 'tooling3')

  FileUtils.rm_rf(tooling_path_staging, verbose: true)
  FileUtils.mkpath(tooling_path_staging)
  FileUtils.cp_r('.', tooling_path_staging)

  FileUtils.rm_rf(tooling_path, verbose: true)
  FileUtils.mv(tooling_path_staging, tooling_path, verbose: true)
  unless File.symlink?(tooling_path_compat)
    FileUtils.rm_rf(tooling_path_compat, verbose: true)
    FileUtils.ln_s(tooling_path, tooling_path_compat, verbose: true)
  end
end
