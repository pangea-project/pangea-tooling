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
  overlay-bin
].freeze

SOURCE_DIRS = %w[
  ci
  jenkins-jobs
  lib
  nci
  mgmt
  overlay-bin
  overlay-bin/lib
  xci
].freeze

desc 'run all unit tests'
Rake::TestTask.new do |t|
  t.ruby_opts << "-r#{File.expand_path(__dir__)}/test/helper.rb"
  # Parsing happens in a separate task because failure there outranks everything
  list =FileList['test/test_*.rb'].exclude('test/test_parse.rb')
  t.test_files = list
  t.options = "--stop-on-failure --verbose=v"
  t.verbose = false
end
task :test => :test_pangea_parse
CLEAN << 'coverage' # Created through helper's simplecov
CLEAN << 'test/reports'

desc 'run pangea-tooling (parse) test'
Rake::TestTask.new(:test_pangea_parse) do |t|
  # Parse takes forever, so we run it concurrent to the other tests.
  t.test_files = FileList['test/test_parse.rb']
  t.verbose = true
end

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
  bundle(*%w[clean --force --verbose])
  bundle(*%w[pack --all-platforms --no-install])

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
