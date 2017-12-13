#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require 'date'
require 'jenkins_junit_builder'

require_relative '../ci-tooling/lib/projects/factory/neon'

module NCI
  # Checks for duplicated repos.
  class DuplicatedRepos
    # Whitelists basename=>[paths] from being errored on (for when the dupe)
    # is intentional. NB: this should not ever be necessary!
    # This does strictly assert that the paths defined are the paths we have.
    # Any deviation will result in a test fail as the whitelist must be kept
    # current to prevent false-falsitives.
    WHITELIST = {}.freeze

    class << self
      attr_writer :whitelist

      def whitelist
        @whitelist ||= WHITELIST
      end
    end

    PATH_EXCLUSION = [
      'kde-sc/', # Legacy KDE 4 material
      'attic/', # Archive for old unused stuff.
      'deduplication-wastebin/' # Trash from dupe cleanup.
    ].freeze

    module JUnit
      # Wrapper converting to JUnit Suite.
      class Suite
        # Wrapper converting to JUnit Case.
        class Case < JenkinsJunitBuilder::Case
          def initialize(name, paths)
            self.classname = name
            # 3rd and final drill down CaseClassName
            self.name = name
            self.time = 0
            self.result = JenkinsJunitBuilder::Case::RESULT_FAILURE
            system_out.message = build_output(name, paths)
          end

          def build_output(name, paths)
            output = <<-EOF
'#{name}' has more than one repository. It appears at [#{paths.join(' ')}].
This usually means that a neon-packaging/ or forks/ repo was created when indeed
Debian had a repo already which should be used instead. Similiarly Debian
may have added the repo after the fact and work should be migrated there.
Less likely scenarios include the mirror tech having failed to properly mirror
a symlink (should only appear in the canonical location on our side).
            EOF
            return output unless (whitelist = DuplicatedRepos.whitelist[name])
            output + <<-EOF
\nThere was a whitelist rule but it did not match! Was: [#{whitelist.join(' ')}]
            EOF
          end
        end

        def initialize(dupes)
          @suite = JenkinsJunitBuilder::Suite.new
          # This is not particularly visible in Jenkins, it's only used on the
          # testcase page itself where it will refer to the test as
          # SuitePackage.CaseClassName.CaseName (from SuitePackage.SuiteName)
          @suite.name = 'Check'
          # Primary sorting name on Jenkins.
          # Test results page lists a table of all tests by packagename
          @suite.package = 'DuplicatedRepos'
          dupes.each { |name, paths| @suite.add_case(Case.new(name, paths)) }
        end

        def write_into(dir)
          FileUtils.mkpath(dir) unless Dir.exist?(dir)
          File.write("#{dir}/#{@suite.package}.xml", @suite.build_report)
        end
      end
    end

    # List of paths the repo appears in.
    def self.reject_paths?(paths)
      remainder = paths.reject do |path|
        PATH_EXCLUSION.any? { |e| path.start_with?(e) }
      end
      remainder.size < 2
    end

    # base is the basename of the repo
    # paths is an array of directories the repo appears in
    def self.reject?(base, paths)
      # Only one candidate. All fine
      return true if paths.size < 2
      # Ignore if we should reject the paths
      return true if reject_paths?(paths)
      # Exclude whitelisted materials
      return true if whitelist.fetch(base, []) == paths
      false
    end

    def self.run
      repos = ProjectsFactory::Neon.ls
      repos_in_paths = repos.group_by { |x| File.basename(x) }
      repos_in_paths.reject! { |base, paths| reject?(base, paths) }.to_h
      JUnit::Suite.new(repos_in_paths).write_into('reports/')
      puts repos_in_paths
      raise 'Duplicated repos found' unless repos_in_paths.empty?
    end
  end
end

NCI::DuplicatedRepos.run if $PROGRAM_NAME == __FILE__
