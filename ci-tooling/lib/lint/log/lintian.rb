# frozen_string_literal: true
require_relative '../linter'
require_relative 'build_log_segmenter'

module Lint
  class Log
    # Lintian log linter
    class Lintian < Linter
      include BuildLogSegmenter

      # Applied after lintian is run so we can apply advanced magic such as
      # regexes which ordinarily a linitian profile wouldn't allow us to do.
      # This has the unfortunate disadvantage that the lines will still show
      # up in the log even though we skip them for the junit report.
      EXCLUSION = [
        # libkdeinit5 never needs ldconfig triggers actually
        #   16.04
        %r{E: (\w+): postinst-must-call-ldconfig (.+)/libkdeinit5_(.+).so},
        #   18.04
        %r{E: (\w+): package-must-activate-ldconfig-trigger (.+)/libkdeinit5_(.+).so}
      ].freeze

      # These tags get reduced from E: to W:
      ERROR_REDUCTION = [
        # don't fail build on source missing. it can trigger even if a blob
        # is not questionable and only used for tests
        'source-is-missing',
        'copyright-contains-dh_make-todo-boilerplate',
        'helper-templates-in-copyright'
      ]

      def lint(data)
        r = Result.new
        data = segmentify(data, "=== Start lintian\n", "=== End lintian\n")
        r.valid = true
        data.each do |line|
          lint_line(mangle(line), r)
        end
        r
      rescue BuildLogSegmenter::SegmentMissingError => e
        puts "#{self.class}: in log #{e.message}"
        r
      end

      private

      def mangle(line)
        if ERROR_REDUCTION.any? { |x| line.include?(x) }
          return line.gsub('E: ', 'W: ')
        end
        line
      end

      def static_exclude?(line)
        # Always exclude random warnings from lintian itself.
        return true if line.start_with?('warning: ')
      end

      def exclusion_excluse?(line)
        EXCLUSION.any? do |e|
          next line.include?(e) if e.is_a?(String)
          next line =~ e if e.is_a?(Regexp)
          false
        end
      end

      def exclude?(line)
        # Always exclude certain things.
        return true if static_exclude?(line)
        # Main exclusion list, may be slightly different based on ENV[TYPE]
        return true if exclusion_excluse?(line)
        # Linter based ignore system per-source. Ought not be used anywhere
        # as I don't think we load anything ever.
        @ignores.each do |i|
          next unless i.match?(line)
          return true
        end
        false
      end

      def lint_line(line, result)
        return if exclude?(line)
        case line[0..1]
        when 'W:'
          result.warnings << line
        when 'E:'
          result.errors << line
        when 'I:'
          result.informations << line
        end
        # else: skip
      end
    end
  end
end
