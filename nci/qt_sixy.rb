#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-FileCopyrightText: 2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

# A quick script to go over a qt 6 repo from Debian and simplify the .debs produced to make them only runtime and dev packages
# The intention is to simplify maintinance so when new Qts come out we don't have to worry about where to put the files
# This needs manual going over the output for sanity

require_relative '../lib/debian/control'
require_relative '../lib/projects/factory/neon'

require 'deep_merge'
require 'tty/command'

class QtSixy

  def initialize(path)
    Dir.chdir(path)
    puts "Running Sixy in #{Dir.pwd}"
    unless File.basename(Dir.pwd).include?("qt6-")
      puts "Must be run in a 'qt6-foo' repo"
      exit
    end
    unless File.exists?("debian")
      puts "Must be run in a 'qt6-foo' repo with 'debian/' dir"
      exit
    end
  end

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

  def run
    cmd = TTY::Command.new
    #FileUtils.cp('debian/control.bak', 'debian/control') if File.exist?('debian/control.bak')
    FileUtils.cp('debian/control', 'debian/control.bak')
    control = Debian::Control.new
    control.parse!
    p control.binaries.collect { |x| x['Package'] } # pkgs

    dev_binaries = control.binaries.select { |x| x['Package'].include?('-dev') }
    bin_binaries = control.binaries.select { |x| !dev_binaries.include?(x) }
    control.binaries.replace(control.binaries[0..1])
    dev_binaries_names = dev_binaries.collect { |x| x['Package'] }
    bin_binaries_names = bin_binaries.collect { |x| x['Package'] }

    control.binaries.replace( [{}, {}] )

    bin = control.binaries[0]
    bin.replace({'Package' => File.basename(Dir.pwd), 'Architecture' => 'any', 'Section' => 'kde', 'Description' => '((TBD))'})

    bin['Provides'] = Debian::Deb822.parse_relationships(bin_binaries.collect { |x| x['Package'] }.join(', '))
    dev = control.binaries[1]
    dev.replace({'Package' => File.basename(Dir.pwd) + '-dev', 'Architecture' => 'any', 'Section' => 'kde', 'Description' => '((TBD))'})
    dev['Provides'] = Debian::Deb822.parse_relationships(dev_binaries.collect { |x| x['Package'] }.join(', '))

    bin_binaries_names.each do |package_name|
      next if bin['Package'] == package_name
      old_install_file_data = File.read("debian/" + package_name + ".install")
      new_install_filename = "debian/" + bin['Package'] + ".install"
      File.write(new_install_filename, old_install_file_data, mode: "a")
      FileUtils.rm_f("debian/" + package_name + ".install")
      FileUtils.rm_f("debian/" + package_name + ".symbols")
      FileUtils.rm_f("debian/" + package_name + ".lintian-overrides")
    end

    bin_binaries.each do |bin_bin|
      p bin_bin
      fold_pkg(bin_bin, into: bin)
    end

    # bin['Provides'] ||= []
    # bin['Provides'] += bin_binaries.collect { |x| x['Package'] }.join(', ')

    dev_binaries_names.each do |package_name|
      next if dev['Package'] == package_name
      old_install_file_data = File.read("debian/" + package_name + ".install")
      new_install_filename = "debian/" + bin['Package'] + ".install"
      File.write(new_install_filename, old_install_file_data, mode: "a")
      FileUtils.rm_f("debian/" + package_name + ".install")
      FileUtils.rm_f("debian/" + package_name + ".symbols")
      FileUtils.rm_f("debian/" + package_name + ".lintian-overrides")
    end

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

if $PROGRAM_NAME == __FILE__
  sixy = QtSixy.new(ARGV[0])
  sixy.run
end
