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

require_relative '../linter'
require_relative 'build_log_segmenter'

module Lint
  class Log
    # Parses CMake output
    # FIXME: presently we simply result with names, this however lacks context
    #        in the log then, so the output should be changed to a descriptive
    #        line
    class CMake < Linter
      include BuildLogSegmenter

      METHS = {
        'The following OPTIONAL packages have not been found' \
          => :parse_summary,
        'The following RUNTIME packages have not been found' \
          => :parse_summary,
        'The following features have been disabled' \
          => :parse_summary,
        'Could not find a package configuration file provided by' \
          => :parse_package,
        'CMake Warning' \
          => :parse_warning
      }.freeze

      def lint(data)
        r = Result.new
        data = segmentify(data, 'dh_auto_configure', 'dh_auto_build')
        r.valid = true
        parse(data, r)
        r.uniq
      rescue BuildLogSegmenter::SegmentMissingError => e
        puts "#{self.class}: in log #{e.message}"
        r
      end

      private

      def load_static_ignores
        super
        return unless ENV.fetch('DIST') == 'bionic'
        return unless ENV.fetch('DIST') == NCI.future_series
        # As long as bionic is the future series ignore QCH problems. We cannot
        # solve them without breaking away from xenial or breaking xenial
        # support.
        @ignores << CI::IncludePattern.new('QCH, API documentation in QCH')
        # It ECM it's by a different name for some reason.
        @ignores << CI::IncludePattern.new('BUILD_QTHELP_DOCS')
      end

      def warnings(line, data)
        METHS.each do |id, meth|
          next unless line.include?(id)
          ret = send(meth, line, data)
          @ignores.each do |ignore|
            ret.reject! { |d| ignore.match?(d) }
          end
          return ret
        end
        []
      end

      def parse(data, result)
        until data.empty?
          line = data.shift
          result.warnings += warnings(line, data)
        end
      end

      def parse_summary(_line, data)
        missing = []
        start_line = false
        until data.empty?
          line = data.shift
          if !start_line && line.empty?
            start_line = true
            next
          elsif start_line && !line.empty?
            next if line.strip.empty?
            match = line.match(/^ *\* (.*)$/)
            missing << match[1] if match&.size && match.size > 1
          else
            # Line is empty and the start conditions didn't match.
            # Either the block is not valid or we have reached the end.
            # In any case, break here.
            break
          end
        end
        missing
      end

      def parse_package(line, _data)
        package = 'Could not find a package configuration file provided by'
        match = line.match(/^\s+#{package}\s+"(.+)"/)
        return [] unless match&.size && match.size > 1
        [match[1]]
      end

      # This possibly should be outsourced into files somehow?
      def parse_warning(line, _data)
        warn 'CMake Warning Parsing is disabled at this time!'
        return [] unless line.include?('CMake Warning')
        # Lines coming from MacroOptionalFindPackage (from old parsing).
        return [] if line.include?('CMake Warning at ' \
          '/usr/share/kde4/apps/cmake/modules/MacroOptionalFindPackage.cmake')
        # Lines coming from find_package (from old parsing).
        return [] if line =~ /CMake Warning at [^ :]+:\d+ \(find_package\)/
        # Lines coming from warnings inside the actual CMakeLists.txt as those
        # can be arbitrary.
        # ref: "CMake Warning at src/worker/CMakeLists.txt:33 (message):"
        warning_exp = /CMake Warning at [^ :]*CMakeLists.txt:\d+ \(message\)/
        return [] if line.match(warning_exp)
        return [] if line.start_with?('CMake Warning (dev)')
        [] # if line.start_with?('CMake Warning:')] ALWAYS empty, too pointless
      end
    end
  end
end
