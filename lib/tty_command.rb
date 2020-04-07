# frozen_string_literal: true
# SPDX-FileCopyrightText: 2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'tty/command'
require_relative 'tty_command/native_printer'

# NB: our command construct with native printers by default!

module TTY
  class Command
    alias :initialize_orig :initialize
    def initialize(*args, **kwords)
      kwords = { printer: NativePrinter }.merge(kwords)
      initialize_orig(*args, **kwords)
    end
  end
end
