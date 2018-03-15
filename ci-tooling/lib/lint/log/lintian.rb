# frozen_string_literal: true
require_relative '../linter'
require_relative 'build_log_segmenter'

module Lint
  class Log
    # Lintian log linter
    class Lintian < Linter
      include BuildLogSegmenter

      TYPE = ENV.fetch('TYPE', '')
      EXCLUSION = [
        # Package names can easily go beyond what shit can suck on, so gag it.
        'source-package-component-has-long-file-name',
        'package-has-long-file-name',
        # We really do not care about standards versions for now. They only ever
        # get bumped by the pkg-kde team anyway.
        'out-of-date-standards-version',
        'newer-standards-version',
        'ancient-standards-version',
        # We package an enormous amount of GUI apps without manpages (in fact
        # they arguably wouldn't even make sense what with being GUI apps). So
        # ignore any and all manpage warnings to save Harald from having to
        # override them in every single application repository.
        'binary-without-manpage',
        # Equally we don't really care enough about malformed manpages.
        'manpage-has-errors-from-man',
        'manpage-has-bad-whatis-entry',
        # We do also not care about correct dep5 format as we do nothing with
        # it.
        'dep5-copyright-license-name-not-unique',
        'missing-license-paragraph-in-dep5-copyright',
        # TODO: check if we still need or want these
        # next if line.include?('not-binnmuable-any-depends-all')
        # Lintian is made for stupid people.
        # FIXME: needs test probably
        'debian-revision-should-not-be-zero',
        'bad-distribution-in-changes-file',
        # On dev editions we actually pack x-test for testing purposes.
        'unknown-locale-code x-test',
        # As of 18.04 this warning is no longer true as transitionals should be
        # in optional now (extra was deprecated). Skip the old warning for 16.04
        # the new warning has a different ID and gets raised on 18.04+.
        'transitional-package-should-be-oldlibs-extra',
        # Same as transitional above.
        'debug-package-should-be-priority-extra'
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

      def exclusion
        @exclusion ||= begin
          ex = EXCLUSION.dup
          unless %w[release release-lts].include?(TYPE)
            # For non-release builds we do not care about tarball signatures,
            # we generated the tarballs anyway (mostly anyway).
            # FIXME: what about Qt though :(
            ex << 'orig-tarball-missing-upstream-signature'
          end
          ex
        end
      end

      def static_exclude?(line)
        # Always exclude random warnings from lintian itself.
        return true if line.start_with?('warning: ')
        # Also silly override reports.
        return true if line =~ /N: \d+ tags overridden \(.*\)/
      end

      def exclusion_excluse?(line)
        exclusion.any? do |e|
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
