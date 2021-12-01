#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-FileCopyrightText: 2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/debian/control'
require_relative '../lib/projects/factory/neon'

require 'deep_merge'
require 'tty/command'

def fold_pkg(pkg, into:)
  pkg.each do |k,v|
    next if k == 'Package'
    next if k == 'Architecture'
    next if k == 'Multi-Arch'
    next if k == 'Section'
    next if k == 'Description'

    into[k] = v unless into.include?(k)
    case into[k].class
    when Hash, Array
      into[k].deep_merge!(v)
    else
      into[k] += v
    end
  end
end

cmd = TTY::Command.new
%w[qt6/qt6-base].each do |repo|
# ProjectsFactory::Neon.ls.each do |repo| TODO
  next unless repo.include?('qt6')

  # TODO remove
  next unless repo.include?('base')

  p repo
  # FileUtils.rm_rf('qt_sixy')
  # Dir.mkdir('qt_sixy')
  Dir.chdir('qt_sixy') do
    # cmd.run("git clone --depth 1 --branch master https://invent.kde.org/neon/#{repo}")
    Dir.chdir(File.basename(repo)) do
      FileUtils.cp('debian/control.bak', 'debian/control') if File.exist?('debian/control.bak')
      FileUtils.cp('debian/control', 'debian/control.bak')
      control = Debian::Control.new
      control.parse!
      p control.binaries.collect { |x| x['Package'] } # pkgs
      # TODO deep clone instead of parsing twice
      old_control = Debian::Control.new
      old_control.parse!

      dev_binaries = control.binaries.select { |x| x['Package'].include?('-dev') }
      bin_binaries = control.binaries.select { |x| !dev_binaries.include?(x) }
      control.binaries.replace(control.binaries[0..1])
      dev_binaries_names = dev_binaries.collect { |x| x['Package'] }
      bin_binaries_names = bin_binaries.collect { |x| x['Package'] }

      control.binaries.replace( [{}, {}] )

      bin = control.binaries[0]
      bin.replace({'Package' => File.basename(repo), 'Architecture' => 'any', 'Section' => 'kde', 'Description' => '((TBD))'})

      bin['Provides'] = Debian::Deb822.parse_relationships(bin_binaries.collect { |x| x['Package'] }.join(', '))
      dev = control.binaries[1]
      dev.replace({'Package' => File.basename(repo) + '-dev', 'Architecture' => 'any', 'Section' => 'kde', 'Description' => '((TBD))'})
      dev['Provides'] = Debian::Deb822.parse_relationships(dev_binaries.collect { |x| x['Package'] }.join(', '))

      bin_binaries.each do |bin_bin|
        p bin_bin
        fold_pkg(bin_bin, into: bin)
      end

      # bin['Provides'] ||= []
      # bin['Provides'] += bin_binaries.collect { |x| x['Package'] }.join(', ')

      dev_binaries.each do |dev_bin|
        fold_pkg(dev_bin, into: dev)
      end


      dev.each do |k, v|
        next unless v.is_a?(Array)

        v.each do |relationships|
          next unless relationships.is_a?(Array)
          relationships.each do |alternative|
            next unless alternative.is_a?(Debian::Relationship)

            next unless bin_binaries_names.include?(alternative.name)
            p alternative
            alternative.name.replace(bin['Package'])
          end
        end
      end

      File.write('debian/control', control.dump)
      cmd.run('wrap-and-sort')
      system('cat debian/control')

    end
  end
end
