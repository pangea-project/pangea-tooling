# frozen_string_literal: true

# SPDX-FileCopyrightText: 2023 Jonthan Esk-Riddell <jr@jriddell.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'fileutils'
require 'logger'
require 'logger/colors'
require 'open3'
require 'tmpdir'

require_relative '../../lib/apt'
require_relative '../../lib/dpkg'
require_relative 'lib/setup_repo'

# Base class for install checks, isolating common logic.
class I386InstallCheck
  def initialize
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
  end

  def run
    Apt.update
    DPKG.dpkg(['--add-architecture', 'i386'])
    Apt.install('steam')
    Apt.install('wine32')
    NCI.setup_repo!
    Apt.install('neon-desktop')
  end
end
