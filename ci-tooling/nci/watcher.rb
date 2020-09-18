#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

# Watches for releases via uscan.

require_relative 'lib/watcher'
require_relative 'lib/setup_env'
require_relative '../lib/debian/source'

# TODO: we should still detect when ubuntu versions diverge I guess?
#   though that may be more applicable to backports version change detection as
#   a whole
if Debian::Source.new(Dir.pwd).format.type == :native
  puts 'This is a native source. Nothing to do!'
  exit 0
end

NCI.setup_env!
NCI::Watcher.new.run
