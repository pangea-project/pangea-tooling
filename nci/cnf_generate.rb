#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'fileutils'
require 'open-uri'
require 'tty/command'

require_relative 'lint/repo_package_lister'

module NCI
  class CNFGenerator
    def dist
      ENV.fetch('DIST')
    end

    def arch
      ENV.fetch('ARCH')
    end

    def repo
      ENV.fetch('REPO')
    end

    def commands_file
      "Commands-#{arch}"
    end

    def pkg_to_version
      @pkg_to_version ||= begin
        pkg_to_version = {}
        Aptly.configure do |config|
          config.uri = URI::HTTPS.build(host: 'archive-api.neon.kde.org')
          # This is read-only.
        end
        NCI::RepoPackageLister.new.packages.each do |pkg|
          pkg_to_version[pkg.name] = pkg.version
        end
        pkg_to_version
      end
    end

    def run
      uri = "https://contents.neon.kde.org/v2/find/archive.neon.kde.org/#{repo}/dists/#{dist}?q=*/bin/*"

      pkg_to_paths = {} # all bin paths in a package

      path_to_pkgs = JSON.parse(URI.open(uri).read)
      path_to_pkgs.each do |path, packages|
        path = "/#{path}" unless path[0] == '/' # Contents paths do not have a leading slash
        packages.each do |pkg|
          # For everything that isn't Qt we'll want the bin name only. Generally
          # people will try to run 'foobar' not '/usr/bin/foobar'. qtchooser OTOH
          # does intentionally and explicitly the latter to differenate its overlay
          # binaries ('/usr/bin/qmake' is a symlink to qtchooser) from the backing
          # SDK binaries ('/usr/lib/qt5/bin/qmake')
          path = File.basename(path) unless path.include?('qt5/bin/')

          (pkg_to_paths[pkg] ||= []) << path
        end
      end

      output_dir = 'repo/main/cnf'
      FileUtils.mkpath(output_dir)
      File.open("#{output_dir}/#{commands_file}", 'w') do |file|
        file.puts(<<~HEADER)
          suite: #{dist}
          component: main
          arch: #{arch}
        HEADER

        file.puts

        pkg_to_paths.each do |pkg, paths|
          file.puts(<<~BLOCK)
            name: #{pkg}
            version: #{pkg_to_version[pkg]}
            commands: #{paths.join(', ')}
          BLOCK

          file.puts
        end
      end
    end
  end
end

NCI::CNFGenerator.new.run if $PROGRAM_NAME == __FILE__
