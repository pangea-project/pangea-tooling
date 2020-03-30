# frozen_string_literal: true
# SPDX-FileCopyrightText: 2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'tty/command'
require 'tty/command/printers/abstract'

# Native style printer. Somewhere betweeen quiet and pretty printer.
# Pretty has a tedency to fuck up output flushed without newlines as each
# output string is streamed to the printer target with
#   color(\t$output)
# which can in case of apt mean that a single character is put on
# a newline with color and tab; blowing up the output and making it
# unreadable. Native seeks to mitigate this by simply streaming output very
# unformatted so as to preserve the original output structure and color.
# At the same time preserving handy dandy annotations from pretty printer such
# as what command is run and how long it took.
class NativePrinter < TTY::Command::Printers::Abstract
  TIME_FORMAT = "%5.3f %s".freeze

  def print_command_start(cmd, *args)
    message = ["Running #{decorate(cmd.to_command, :yellow, :bold)}"]
    message << args.map(&:chomp).join(' ') unless args.empty?
    puts(cmd, message.join)
  end

  def print_command_out_data(cmd, *args)
    message = args.join(' ')
    write(cmd, message, out_data)
  end

  def print_command_err_data(cmd, *args)
    message = args.join(' ')
    write(cmd, message, err_data)
  end

  def print_command_exit(cmd, status, runtime, *args)
    if cmd.only_output_on_error && !status.zero?
      output << out_data
      output << err_data
    end

    runtime = TIME_FORMAT % [runtime, pluralize(runtime, 'second')]
    # prepend newline to make sure we are spearate from end of output
    message = ["\nFinished in #{runtime}"]
    message << " with exit status #{status}" if status
    message << " (#{success_or_failure(status)})"
    puts(cmd, message.join)
  end

  def puts(cmd, message)
    write(cmd, "#{message}\n")
  end

  def write(cmd, message, data = nil)
    out = []
    out << message
    target = (cmd.only_output_on_error && !data.nil?) ? data : output
    target << out.join
  end

  private

  # Pluralize word based on a count
  #
  # @api private
  def pluralize(count, word)
    "#{word}#{'s' unless count.to_f == 1}"
  end

  # @api private
  def success_or_failure(status)
    if status == 0
      decorate('successful', :green, :bold)
    else
      decorate('failed', :red, :bold)
    end
  end
end
