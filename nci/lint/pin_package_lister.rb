# frozen_string_literal: true
# SPDX-FileCopyrightText: 2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'tty/command'

require_relative '../../lib/debian/version'

module NCI
  # Lists packages that are currently pinned
  class PinPackageLister
    Package = Struct.new(:name, :version)

    # NB: we always need a fitler for this lister. apt-cache cannot be run
    # without arguments!
    def initialize(filter_select: nil)
      @filter_select = filter_select
    end

    def packages
      @packages ||= begin
        cmd = TTY::Command.new(printer: :null)
        result = cmd.run('apt-cache', 'policy')

        section_regex = /[^:]+:/
        pin_regex =
          /\s?(?<package>[^\s]+) -> (?<version>[^\s]+) (?<remainder>.*)/

        pins = {}
        # Output doesn't start with pins so we'll first want to find the pin
        # section. Track us being inside/outside.
        looking_at_pins = false
        result.out.split("\n").each do |line|
          if line.strip.include?('Pinned packages:')
            looking_at_pins = true
            next
          end

          next unless looking_at_pins

          if line.match(section_regex)
            looking_at_pins = false
            next
          end

          matchdata = line.match(pin_regex)
          unless matchdata
            raise "Unexpectadly encountered a none pinny line: #{line}"
          end

          package = matchdata['package'].strip
          version = matchdata['version'].strip

          # We track versions in a pin since the output may contain multiple
          # versions. We need to pick the hottest.
          pins[package] ||= []
          pins[package] << version
        end

        pins = pins.collect do |pkg, versions|
          versions = versions.compact.uniq
          case versions.size
          when 0
            raise "Something is wrong with parsing, there's no version: #{pkg}"
          when 1
            next Package.new(pkg, Debian::Version.new(versions[0]))
          end

          # Depending on pins a single packge may be listped multiple times
          # becuase the command doesn't return the candidate but all versions
          # at the same priority -.-
          raise 'Multiple pin candidates not supported.' \
            " You'll need to write some code if this is required."
          # If necessary we'd likely need to do some comparisions here to
          # pick the highest possible thingy and then ensure it's >> the
          # candidate or something similar.
          # Probably neds refactoring of filter_select to contain versions
          # or something
        end.compact

        return pins unless @filter_select

        pins.select { |x| @filter_select.include?(x.name) }
      end
    end
  end
end
