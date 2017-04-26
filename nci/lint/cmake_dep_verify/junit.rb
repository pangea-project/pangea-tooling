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

require 'jenkins_junit_builder'

module CMakeDepVerify
  module JUnit
    # Wrapper converting an ADT summary into a JUnit suite.
    class Suite
      # Wrapper converting an ADT summary entry into a JUnit case.
      class CMakePackage
        def initialize(name, result)
          @name = name
          @result = result
        end

        def to_case
          c = JenkinsJunitBuilder::Case.new
          # 2nd drill down from SuitePackage
          c.classname = @name
          # 3rd and final drill down CaseClassName
          c.name = 'find_package'
          c.time = 0
          c.result = value
          if output?
            c.system_out.message = @result.out
            c.system_err.message = @result.err
          end
          c
        end

        private

        def value
          if @result.success?
            JenkinsJunitBuilder::Case::RESULT_PASSED
          else
            JenkinsJunitBuilder::Case::RESULT_FAILURE
          end
        end

        def output?
          !@result.out.empty? || !@result.err.empty?
        end
      end

      def initialize(deb_name, summary)
        @suite = JenkinsJunitBuilder::Suite.new
        # This is not particularly visible in Jenkins, it's only used on the
        # testcase page itself where it will refer to the test as
        # SuitePackage.CaseClassName.CaseName (from SuitePackage.SuiteName)
        @suite.name = 'CMakePackages'
        # Primary sorting name on Jenkins.
        # Test results page lists a table of all tests by packagename
        # NB: we use the deb_name here to get a quicker overview as the job
        #   running this only has cmakepackage output, so we do not need to
        #   isolate ourselves into 'CMakePackges' or whatever.
        @suite.package = deb_name
        summary.each do |package, result|
          @suite.add_case(CMakePackage.new(package, result).to_case)
        end
      end

      def to_xml
        @suite.build_report
      end
    end
  end
end
