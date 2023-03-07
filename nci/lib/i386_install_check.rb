# frozen_string_literal: true

# SPDX-FileCopyrightText: 2023 Jonthan Esk-Riddell <jr@jriddell.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'fileutils'
require 'logger'
require 'logger/colors'
require 'open3'
require 'tmpdir'

require_relative 'apt'
require_relative 'aptly-ext/filter'
require_relative 'dpkg'
require_relative 'repo_abstraction'
require_relative 'retry'
require_relative 'thread_pool'
require_relative 'ci/fake_package'

# Base class for install checks, isolating common logic.
class I386InstallCheck
  def initialize
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
  end

  def run
    Apt.update
    DPKG.run(['--add-architecture', 'i386'])
    Apt.install('steam')
    Apt.install('wine32')
  end
end
