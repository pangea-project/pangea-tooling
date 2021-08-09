#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

# Watches for releases via uscan.

require_relative 'lib/watcher'
require_relative 'lib/setup_env'
require_relative '../lib/debian/changelog'
require_relative '../lib/debian/source'

# TODO: we should still detect when ubuntu versions diverge I guess?
#   though that may be more applicable to backports version change detection as
#   a whole
Dir.chdir('deb-packaging') do
  if Debian::Source.new(Dir.pwd).format.type == :native
    puts 'This is a native source. Nothing to do!'
    exit 0
  end

  # Special exclusion list. For practical reasons we have kind of neon-specific
  # sources that aren't built from tarballs but rather from git directly.
  # Sources in this list MUST be using KDE_L10N_SYNC_TRANSLATIONS AND have a
  # gitish watch file or none at all.
  # Changes to these requiremenst MUST be discussed with the team!
  source_name = Debian::Changelog.new(Dir.pwd).name
  if %w[drkonqi-pk-debug-installer].include?(source_name) &&
    File.read('debian/rules').include?('KDE_L10N_SYNC_TRANSLATIONS') &&
    (!File.exist?('debian/watch') ||
      File.read('debian/watch').include?('mode=git'))
    puts 'This is a neon-ish source built from git despite being in release/.'
    exit 0
  end
end

NCI.setup_env!
NCI::Watcher.new.run
