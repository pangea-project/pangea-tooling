# frozen_string_literal: true
# SPDX-FileCopyrightText: 2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../ci-tooling/lib/os'

module Lintian
  class Profile
    attr_reader :name
    attr_accessor :disable_tags

    DEFAULT_DISABLE_TAGS = [
      # Package names can easily go beyond
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
      'bad-distribution-in-changes-file',
      # On dev editions we actually pack x-test for testing purposes.
      'unknown-locale-code x-test',
      # We entirely do not care about random debian transitions but defer
      # to KDE developer's judgment.
      'script-uses-deprecated-nodejs-location',
      # Maybe it should, maybe we just don't care. In particular since this is
      # an error but really it is not even making a warning in my mind.
      'copyright-should-refer-to-common-license-file-for-lgpl'
    ]

    def default_disable_tags
      tags = DEFAULT_DISABLE_TAGS.clone
      unless %w[release release-lts].include?(ENV.fetch('TYPE', ''))
        # For non-release builds we do not care about tarball signatures,
        # we generated the tarballs anyway (mostly anyway).
        # FIXME: what about Qt though :(
        tags << 'orig-tarball-missing-upstream-signature'
      end
      tags
    end

    def initialize(name)
      @name = name
      @disable_tags = default_disable_tags
      # Force disable override reporting. Utterly pointless data points for us
      # as nobody ever looked at existing overrides.
      @@no_overrides ||= File.open(cfg, 'a+') do |f|
        f.puts("show-overrides = no")
      end
    end

    def cfg
      # Mostly here for unit testing
      ENV.fetch('LINTIAN_CFG', '/etc/lintianrc')
    end

    def profile_dir
      # Mostly here for unit testing
      ENV.fetch('LINTIAN_PROFILE_DIR', '/usr/share/lintian/profiles')
    end

    def default_base
      if OS::ID == 'ubuntu' || OS::ID_LIKE.split(' ').include?('ubuntu')
        'ubuntu/main'
      elsif OS::ID == 'debian' || OS::ID_LIKE.split(' ').include?('debian')
        'debian/main'
      else
        raise 'Cannot infer base profile from os-release id'
      end
    end

    def write
      FileUtils.mkpath("#{profile_dir}/#{name}")
      File.write("#{profile_dir}/#{name}/main.profile", <<-PROFILE)
Profile: #{name}/main
Extends: #{default_base}
Disable-Tags: #{disable_tags.join(', ')}
      PROFILE
    end

    def export
      write
      ENV['LINTIAN_PROFILE'] = name
    end
  end
end
