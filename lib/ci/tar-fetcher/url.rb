# frozen_string_literal: true

# SPDX-FileCopyrightText: 2015-2022 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'uri'
require 'open-uri'
require 'tmpdir'

require_relative '../tarball'

module CI
  class URLTarFetcher
    def initialize(url)
      @uri = URI.parse(url)
    end

    def fetch(destdir)
      parser = URI::Parser.new
      filename = parser.unescape(File.basename(@uri.path))
      target = File.join(destdir, filename)
      unless File.exist?(target)
        puts "Downloading #{@uri}"
        File.write(target, URI.open(@uri).read)
      end
      puts "Tarball: #{target}"
      Tarball.new(target)
    end
  end
end
