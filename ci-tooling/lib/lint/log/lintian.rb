require_relative '../linter'
require_relative 'build_log_segmenter'

module Lint
  class Log
    # Lintian log linter
    class Lintian < Linter
      include BuildLogSegmenter

      EXCLUSION = [
        # Package names can easily go beyond what shit can suck on, so gag it.
        'source-package-component-has-long-file-name',
        'package-has-long-file-name',
        # We really do not care about standards versions for now. They only ever
        # get bumped by the pkg-kde team anyway.
        'out-of-date-standards-version',
        'newer-standards-version',
        # We package an enormous amount of GUI apps without manpages (in fact
        # they arguably wouldn't even make sense what with being GUI apps). So
        # ignore any and all manpage warnings to save Harald from having to
        # override them in every single application repository.
        'binary-without-manpage',
        # Equally we don't really care enough about malformed manpages.
        'manpage-has-errors-from-man',
        'manpage-has-bad-whatis-entry',
        # TODO: check if we still need or want these
        # next if line.include?('not-binnmuable-any-depends-all')
        # Lintian is made for stupid people.
        # FIXME: needs test probably
        'debian-revision-should-not-be-zero',
        'bad-distribution-in-changes-file'
      ].freeze

      def lint(data)
        r = Result.new
        data = segmentify(data, "=== Start lintian\n", "=== End lintian\n")
        r.valid = true
        data.each do |line|
          lint_line(line, r)
        end
        r
      rescue BuildLogSegmenter::SegmentMissingError => e
        puts "#{self.class}: in log #{e.message}"
        r
      end

      private

      def static_exclude?(line)
        # Always exclude random warnings from lintian itself.
        return true if line.start_with?('warning: ')
        # Also silly override reports.
        return true if line =~ /N: \d+ tags overridden \(.*\)/
      end

      def exclude?(line)
        return true if static_exclude?(line)
        EXCLUSION.each do |e|
          next unless line.include?(e)
          return true
        end
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
