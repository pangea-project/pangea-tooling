# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2017-2021 Harald Sitter <sitter@kde.org>

require 'tty/command'

require_relative '../../lib/debian/version'

module NCI
  # Lists packages out of the apt cache
  class CachePackageLister
    Package = Struct.new(:name, :version)

    # NB: we always need a fitler for this lister. apt-cache cannot be run
    # without arguments!
    def initialize(filter_select:)
      @filter_select = filter_select
    end

    def packages
      @packages ||= begin
        cmd = TTY::Command.new(printer: :null)
        # The overhead of apt is rather substantial, so we'll want to get all
        # data in one go ideally. Should this exhaust some argument limit
        # at some point we'll want to split into chunks instead.
        result = cmd.run('apt-cache', 'policy', *@filter_select)

        map = {}
        name = nil
        version = nil
        result.out.split("\n").each do |line|
          if line.start_with?(/^\w.+:/) # package lines aren't indented
            name = line.split(':', 2)[0].strip
            next
          end
          if line.start_with?(/\s+Candidate:/) # always indented
            version = line.split(':', 2)[1].strip
            raise line unless name && !name.empty?
            raise line unless version && !version.empty?

            raise if map.include?(name) # double match wtf?

            version = version == '(none)' ? nil : Debian::Version.new(version)
            map[name] = version
            # reset the parent scope vars. we need them in parent scope since
            # matching is run across multiple lines
            name = nil
            version = nil
            next
          end
        end

        map.map { |k, v| Package.new(k, v) }
      end
    end
  end
end
