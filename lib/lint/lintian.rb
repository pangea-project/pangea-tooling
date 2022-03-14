# frozen_string_literal: true
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-FileCopyrightText: 2020 Jonathan Riddell <jr@jriddell.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'tty/command'

require_relative 'linter'

module Lint
  # Lintian log linter
  class Lintian < Linter
    TYPE = ENV.fetch('TYPE', '')
    EXCLUSION = [
      # Our names are very long because our versions are very long because
      # we usually include some form of time stamp as well as extra sugar.
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
      'global-files-wildcard-not-first-paragraph-in-dep5-copyright',
      'debian-revision-should-not-be-zero',
      'file-without-copyright-information',
      # Lintian doesn't necessarily know the distros we talk about.
      'bad-distribution-in-changes-file',
      # On dev editions we actually pack x-test for testing purposes.
      'unknown-locale-code x-test',
      # We entirely do not care about random debian transitions but defer
      # to KDE developer's judgment.
      'script-uses-deprecated-nodejs-location',
      # Maybe it should, maybe we just don't care. In particular since this is
      # an error but really it is not even making a warning in my mind.
      'copyright-should-refer-to-common-license-file-for-lgpl',
      'copyright-should-refer-to-common-license-file-for-gpl',

      # libkdeinit5 never needs ldconfig triggers actually
      %r{E: (\w+): package-must-activate-ldconfig-trigger (.+)/libkdeinit5_(.+).so},
      # While this is kind of a concern it's not something we can do anything
      # about on a packaging level and getting this sort of stuff takes ages,
      # judging from past experiences.
      'inconsistent-appstream-metadata-license',
      'incomplete-creative-commons-license',
      # Sourcing happens a number of ways but generally we'll want to rely on
      # uscan to verify signatures if applicable. The trouble here is that
      # we only run lintian during the bin_ job at which point there is
      # generally no signature available.
      # What's more, depending on how the src_ job runs it also may have
      # no signature. For example it can fetch a tarball from our own
      # apt repo instead of upstream when doing a rebuild at which point
      # there is no siganture but the source is implicitly trusted. As such
      # it's probably best to skip over signature warnings as they are 99%
      # irrelevant for us. There probably should be a way to warn when uscan
      # isn't configured to check a signature but it probably needs to be
      # done manually outside lintian somewhere.
      'orig-tarball-missing-upstream-signature',
      # Laments things such as revisions -0 on native packages' PREVIOUS
      # entries. Entirely pointless.
      'odd-historical-debian-changelog-version',
      # When the version contains the dist name lintian whines. Ignore it.
      # We intentionally put the version in sometimes so future versions
      # are distinctly different across both ubuntu base version and
      # our build variants.
      'version-refers-to-distribution',
      # We don't really care. No harm done. Having us chase that sort of stuff
      # is a waste of time.
      'zero-byte-file-in-doc-directory',
      'description-starts-with-package-name',
      'incorrect-packaging-filename debian/TODO.Debian'
    ].freeze

    def initialize(changes_directory = Dir.pwd,
                   cmd: TTY::Command.new)
      @changes_directory = changes_directory
      @cmd = cmd
      super()
    end

    def lint
      @result = Result.new
      @result.valid = true
      data.each do |line|
        lint_line(mangle(line), @result)
      end
      @result
    end

    private

    # called with chdir inside packaging dir
    def changes_file
      files = Dir.glob("#{@changes_directory}/*.changes")
      raise "Found not exactly one changes: #{files}" if files.size != 1

      files[0]
    end

    # called with chdir inside packaging dir
    def lintian
      result = @cmd.run!('lintian', '--allow-root', changes_file)
      result.out.split("\n")
    end

    def data
      @data ||= lintian
    end

    def mangle(line)
      # Lintian has errors that aren't so let's mangle the lot.
      # Nobody cares for stupid noise.
      line = line.gsub(/^\s*E: /, 'W: ')

      # If this is a soname mismatch we'll take a closer look at what package
      # this affects. An actual library package must not contain unexpected
      # sonames or they need to be explicitly overridden.
      # This is specifically to guard against cases where
      #  a) the install rule contained too broad wildcarding matching libraries
      #     or versions it shouldn't have matched
      #  b) an unrelated library is shoved into the same binary package, which
      #     can be fine but needs opting into since two different libraries
      #     may eventually diverge in so-version, so we cannot assume that this
      #     is fine, it sometimes is it often isn't.
      return line unless line.include?('package-name-doesnt-match-sonames')

      line_expr = /\w: (?<package>.+): package-name-doesnt-match-sonames .+/
      package = line.match(line_expr)&.[](:package)&.strip
      raise "Failed to parse line #{line}" unless package
      return line unless package =~ /lib.+\d/

      # Promote this warning to an error if it is a lib package
      line.gsub(/^\s*W: /, 'E: ')
    end

    def exclusion
      @exclusion ||= begin
        EXCLUSION.dup # since we dup you could opt to manipulate this array
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
