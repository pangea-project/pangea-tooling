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
        r.valid = !data.empty?
        parse(data, r)
        r.uniq
        r
      end

      private

      def parse(data, result)
        until data.empty?
          line = data.shift
          METHS.each do |id, meth|
            next unless line.include?(id)
            ret = send(meth, line, data)
            @ignores.each do |ignore|
              ret.reject! { |d| ignore.match?(d) }
            end
            result.warnings += ret
            break
          end
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
            missing << match[1] if match && match.size > 1
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
        return [] unless match && match.size > 1
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
        return [] if line.match(/CMake Warning at [^ :]+:\d+ \(find_package\)/)
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
