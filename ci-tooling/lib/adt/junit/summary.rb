# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

module ADT
  module JUnit
    class Summary
      class Entry
        def initialize(entry, dir)
          @entry = entry
          @dir = dir
        end

        def to_case
          c = JenkinsJunitBuilder::Case.new
          c.name = @entry.name
          c.time = 0
          c.classname = @entry.name
          c.result = result
          if output?
            c.system_out.message = stdout
            c.system_err.message = stderr
          end
          c
        end

        private

        RESULT_MAP = {
          ADT::Summary::Result::PASS =>
            JenkinsJunitBuilder::Case::RESULT_PASSED,
          ADT::Summary::Result::FAIL =>
            JenkinsJunitBuilder::Case::RESULT_FAILURE
        }.freeze

        def output?
          @entry.result == ADT::Summary::Result::FAIL
        end

        def stdout
          read_output('stdout')
        end

        def stderr
          read_output('stderr')
        end

        def read_output(type)
          path = "#{@dir}/#{@entry.name}-#{type}"
          File.exist?(path) ? File.read(path) : nil
        end

        def result
          RESULT_MAP.fetch(@entry.result)
        end
      end

      def initialize(summary)
        @suite = JenkinsJunitBuilder::Suite.new
        @suite.name = 'autopkgtest'
        @suite.package = 'autopkgtest'
        dir = File.dirname(summary.path)
        summary.entries.each do |entry|
          @suite.add_case(Entry.new(entry, dir).to_case)
        end
      end

      def to_xml
        @suite.build_report
      end

      private


    end
  end
end
