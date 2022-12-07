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

EXCLUDE_BUILD_DEPENDS = %w[qt6-base-private-dev libqt6opengl6-dev qt6-declarative-private-dev qml6-module-qtquick qml6-module-qttest qml6-module-qtquick].freeze

class QtSixy

  attr_reader :dir
  attr_reader :name

  def initialize(name:, dir:)
    @dir = dir
    @name = name
    puts "Running Sixy in #{dir}"
    unless File.exist?("#{dir}/debian")
      raise "Must be run in a 'qt6-foo' repo with 'debian/' dir"
    end
  end

  def fold_pkg(pkg, into:)
    return pkg if pkg['X-Neon-MergedPackage'] == 'true' # noop
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
    control = Debian::Control.new(@dir)
    control.parse!
    p control.binaries.collect { |x| x['Package'] } # pkgs

    dev_binaries = control.binaries.select { |x| x['Package'].include?('-dev') }
    bin_binaries = control.binaries.select { |x| !dev_binaries.include?(x) }
    control.binaries.replace(control.binaries[0..1])
    dev_binaries_names = dev_binaries.collect { |x| x['Package'] }
    bin_binaries_names = bin_binaries.collect { |x| x['Package'] }

    # Get the old provides to add to the new
    #old_bin_binary = bin_binaries.select { |x| x['Package'] == name }
    #old_provides_list = ''
    #if old_bin_binary.kind_of?(Array) and not old_bin_binary.empty?
      #old_provides = old_bin_binary[0]['Provides']
      #old_provides_list = old_provides.collect { |x| x[0].name }.join(', ')
    #end
    #old_dev_binary = dev_binaries.select { |x| x['Package'] == name + "-dev" }
    #old_dev_provides_list = ''
    #if old_dev_binary.kind_of?(Array) and not old_dev_binary.empty?
      #old_dev_provides = old_dev_binary[0]['Provides']
      #old_dev_provides_list = old_dev_provides.collect { |x| x[0].name }.join(', ')
    #end

    old_bin_binary = bin_binaries.select { |x| x['Package'] == name }
    old_depends_list = ''
    if old_bin_binary.kind_of?(Array) and not old_bin_binary.empty?
      old_depends = old_bin_binary[0]['Depends']
      old_depends_list = old_depends.collect { |x| x[0].name }.join(', ')
    end
    old_dev_binary = dev_binaries.select { |x| x['Package'] == name + "-dev" }
    old_dev_depends_list = ''
    if old_dev_binary.kind_of?(Array) and not old_dev_binary.empty?
      old_dev_depends = old_dev_binary[0]['Depends']
      old_dev_depends_list = old_dev_depends.collect { |x| x[0].name }.join(', ')
    end

    control.binaries.replace( [{}, {}] )

    bin = control.binaries[0]
    bin_depends = bin['Depends']
    bin.replace({'Package' => name, 'Architecture' => 'any', 'Section' => 'kde', 'Description' => '((TBD))'})
    
    #bin['Provides'] = Debian::Deb822.parse_relationships(old_provides_list + bin_binaries.collect { |x| x['Package'] unless x['X-Neon-MergedPackage'] == 'true' }.join(', '))
    bin['X-Neon-MergedPackage'] = 'true'
    if not old_depends_list.empty?
      bin['Depends'] = old_depends
    end
    dev = control.binaries[1]
    dev.replace({'Package' => name + '-dev', 'Architecture' => 'any', 'Section' => 'kde', 'Description' => '((TBD))'})
    #dev['Provides'] = Debian::Deb822.parse_relationships(old_dev_provides_list + dev_binaries.collect { |x| x['Package'] }.join(', '))
    dev['X-Neon-MergedPackage'] = 'true'
    if not old_dev_depends_list.empty?
      dev['Depends'] = old_dev_depends
    end

    bin_binaries_names.each do |package_name|
      next if bin['Package'] == package_name

      old_install_file_data = File.read("#{dir}/debian/" + package_name + ".install") if File.exists?("#{dir}/debian/" + package_name + ".install")
      new_install_filename = "#{dir}/debian/" + bin['Package'] + ".install"
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".install")
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".symbols")
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".lintian-overrides")
      File.write(new_install_filename, old_install_file_data, mode: "a")
      
      # Old names are now dummy packages
      dummy = {}
      dummy['Package'] = package_name
      dummy['Architecture'] = 'all'
      dummy['Depends'] = []
      dummy['Depends'][0] = []
      dummy['Depends'][0].append(name)
      dummy['Description'] = "Dummy transitional\nTransitional dummy package.\n"
      control.binaries.append(dummy)
    end

    bin_binaries.each do |bin_bin|
      p bin_bin
      fold_pkg(bin_bin, into: bin)
    end
    bin.delete('Description')
    bin['Description'] = bin_binaries[0]['Description']

    # bin['Provides'] ||= []
    # bin['Provides'] += bin_binaries.collect { |x| x['Package'] }.join(', ')

    dev_binaries_names.each do |package_name|
      next if dev['Package'] == package_name
      old_install_file_data = File.read("#{dir}/debian/" + package_name + ".install") if File.exists?("#{dir}/debian/" + package_name + ".install")
      new_install_filename = "#{dir}/debian/" + dev['Package'] + ".install"
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".install")
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".symbols")
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".lintian-overrides")
      File.write(new_install_filename, old_install_file_data, mode: "a")
      p "written to #{new_install_filename}"

      dummy = {}
      dummy['Package'] = package_name
      dummy['Architecture'] = 'all'
      dummy['Depends'] = []
      dummy['Depends'][0] = []
      dummy['Depends'][0].append(name + "-dev")
      dummy['Description'] = "Dummy transitional\n Transitional dummy package.\n"
      control.binaries.append(dummy)
    end
    # Qt6ShaderToolsTargets-none.cmake is not none on arm so wildcard it
    content = File.read("#{dir}/debian/#{dev['Package']}.install")
    content = content.gsub('-none.cmake', '-*.cmake')
    content = content.gsub('_none_metatypes.json', '_*_metatypes.json')
    File.write("#{dir}/debian/#{dev['Package']}.install", content)

    dev_binaries.each do |dev_bin|
      fold_pkg(dev_bin, into: dev)
    end
    dev.delete('Description')
    dev['Description'] = dev_binaries[0]['Description']

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

    if not old_depends_list.empty?
      bin['Depends'] = old_depends
    end
    if not old_dev_depends_list.empty?
      dev['Depends'] = old_dev_depends
    end
    # Some magic to delete the build deps we list as bad above
    EXCLUDE_BUILD_DEPENDS.each {|build_dep| control.source["Build-depends"].delete_if {|x| x[0].name.start_with?(build_dep)} }

    File.write("#{dir}/debian/control", control.dump)
    cmd.run('wrap-and-sort', chdir: dir) if File.exists?('/usr/bin/wrap-and-sort')
  end
end

if $PROGRAM_NAME == __FILE__
 sixy = QtSixy.new(name: File.basename(Dir.pwd), dir: Dir.pwd)
 sixy.run
end

#if $PROGRAM_NAME == __FILE__
  #sixy = QtSixy.new(name: File.basename('/home/jr/src/pangea-tooling/test/data/test_nci_qt_sixy/test_sixy_repo/qt6-test'), dir: '/home/jr/src/pangea-tooling/test/data/test_nci_qt_sixy/test_sixy_repo/qt6-test')
  #sixy.run
#end
