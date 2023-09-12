#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2015 Rohan Garg <rohan@garg.io>
# SPDX-FileCopyrightText: 2015 Harald Sitter <sitter@kde.org>

require 'tty/command'
require_relative '../lib/docker/cleanup'

Docker.options[:read_timeout] = 3 * 60 * 60 # 3 hours.

# First try to let docker do its thing
cmd = TTY::Command
cmd.run('docker', 'system', 'prune', '--all', '--volumes', '--force')

# Then run our aggressive cleanup routines
Docker::Cleanup.containers
Docker::Cleanup.images
