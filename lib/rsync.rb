# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'tty-command'

# Convenience wrapper around rsync cli
class RSync
  def self.sync(from:, to:, verbose: false)
    ssh_command =
      "ssh -o StrictHostKeyChecking=no -i #{ENV.fetch('SSH_KEY_FILE')}"
    rsync_opts = '-a'
    rsync_opts += ' -v' if verbose
    rsync_opts += " -e '#{ssh_command}'"
    TTY::Command.new.run("rsync #{rsync_opts} #{from} #{to}")
  end
end
