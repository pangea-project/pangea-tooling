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

REPLACEMENT_BUILD_DEPENDS = {"extra-cmake-modules" => "kf6-extra-cmake-modules",
                             "pkg-kde-tools" => "pkg-kde-tools-neon",
                             "qttools5-dev-tools" => "qt6-tools-dev",
                             "qtbase5-dev" => "qt6-base-dev",
                             "qtdeclarative5-dev" => "qt6-declarative-dev"
                            }.freeze
                            

EXCLUDE_BUILD_DEPENDS = %w[qt6-base-private-dev libqt6opengl6-dev qt6-declarative-private-dev qml6-module-qtquick qml6-module-qttest qml6-module-qtquick].freeze

class KFSixy

  attr_reader :dir
  attr_reader :name

  def initialize(name:, dir:)
    @dir = dir
    @name = name
    puts "Running Sixy in #{dir}"
    unless File.exist?("#{dir}/debian")
      raise "Must be run in a 'foo' repo with 'debian/' dir"
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
    bin.replace({'Package' => "kf6-" + name, 'Architecture' => 'any', 'Section' => 'kde', 'Description' => '((TBD))'})
    
    #bin['Provides'] = Debian::Deb822.parse_relationships(old_provides_list + bin_binaries.collect { |x| x['Package'] unless x['X-Neon-MergedPackage'] == 'true' }.join(', '))
    bin['X-Neon-MergedPackage'] = 'true'
    if not old_depends_list.empty?
      bin['Depends'] = old_depends
    end
    dev = control.binaries[1]
    dev.replace({'Package' => "kf6-" + name + '-dev', 'Architecture' => 'any', 'Section' => 'kde', 'Description' => '((TBD))'})
    #dev['Provides'] = Debian::Deb822.parse_relationships(old_dev_provides_list + dev_binaries.collect { |x| x['Package'] }.join(', '))
    dev['X-Neon-MergedPackage'] = 'true'
    if not old_dev_depends_list.empty?
      dev['Depends'] = old_dev_depends
    end

    bin_binaries_names.each do |package_name|
      next if bin['Package'] == package_name

      old_install_file_data = File.read("#{dir}/debian/" + package_name + ".install") if File.exist?("#{dir}/debian/" + package_name + ".install")
      new_install_filename = "#{dir}/debian/" + bin['Package'] + ".install"
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".install")
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".symbols")
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".lintian-overrides")
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".maintscript")
      old_install_file_data.gsub!("usr/lib/\*/", "usr/kf6/lib/*/") if old_install_file_data
      old_install_file_data.gsub!("usr/share/", "usr/kf6/share/") if old_install_file_data
      old_install_file_data.gsub!("usr/bin/", "usr/kf6/bin/") if old_install_file_data
      old_install_file_data.gsub!("qlogging-categories5", "qlogging-categories6") if old_install_file_data
      old_install_file_data.gsub!("/kf5", "/kf6") if old_install_file_data
      old_install_file_data.gsub!("/kservicetypes5", "/kservicetypes6") if old_install_file_data
      old_install_file_data.gsub!(".*tags", "") if old_install_file_data
      File.write(new_install_filename, old_install_file_data, mode: "a")
      
      # Old names are now dummy packages
      package_name6 = package_name.gsub("5", "6")
      dummy = {}
      dummy['Package'] = package_name6
      dummy['Architecture'] = 'all'
      dummy['Depends'] = []
      dummy['Depends'][0] = []
      dummy['Depends'][0].append("kf6-" + name)
      dummy['Description'] = "Dummy transitional\nTransitional dummy package.\n"
      control.binaries.append(dummy)
    end

    bin_binaries.each do |bin_bin|
      p bin_bin
      fold_pkg(bin_bin, into: bin)
    end
    bin.delete('Description')
    bin['Description'] = bin_binaries[0]['Description']
    bin['Description'].gsub!("5", "6")

    # bin['Provides'] ||= []
    # bin['Provides'] += bin_binaries.collect { |x| x['Package'] }.join(', ')

    dev_binaries_names.each do |package_name|
      next if dev['Package'] == package_name
      old_install_file_data = File.read("#{dir}/debian/" + package_name + ".install") if File.exists?("#{dir}/debian/" + package_name + ".install")
      new_install_filename = "#{dir}/debian/" + dev['Package'] + ".install"
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".install")
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".symbols")
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".maintscript")
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".lintian-overrides")
      FileUtils.rm_f("#{dir}/debian/" + package_name + ".acc.in")
      old_install_file_data.gsub!("usr/include/KF5/", "usr/kf6/include/KF6/") if old_install_file_data
      old_install_file_data.gsub!("usr/lib/\*/cmake/", "usr/kf6/lib/*/cmake/") if old_install_file_data
      old_install_file_data.gsub!("usr/lib/\*/libKF5", "usr/kf6/lib/*/libKF5") if old_install_file_data
      old_install_file_data.gsub!("usr/lib/\*/qt5/mkspecs/modules/qt", "usr/kf6/mkspecs/modules/qt") if old_install_file_data
      old_install_file_data.gsub!("usr/lib/\*/pkgconfig", "usr/kf6/lib/*/pkgconfig") if old_install_file_data
      old_install_file_data.gsub!("usr/lib\/*/qt5/qml", "usr/kf6/lib/*/qml/") if old_install_file_data
      old_install_file_data.gsub!("usr/share/qlogging-categories5/", "usr/kf6/share/qlogging-categories6/") if       old_install_file_data
      File.write(new_install_filename, old_install_file_data, mode: "a")
      p "written to #{new_install_filename}"

      package_name6 = package_name.gsub("5", "6")
      dummy = {}
      dummy['Package'] = package_name6
      dummy['Architecture'] = 'all'
      dummy['Depends'] = []
      dummy['Depends'][0] = []
      dummy['Depends'][0].append("kf6-" + name + "-dev")
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
    dev['Description'].gsub!("5", "6")

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
    FileUtils.rm_f("#{dir}/debian/" + "compat")
    
    # Some magic to delete the build deps we list as bad above
    EXCLUDE_BUILD_DEPENDS.each {|build_dep| control.source["Build-depends"].delete_if {|x| x[0].name.start_with?(build_dep)} }
    control.source["Source"].replace("kf6-" + name)
    control.source["Maintainer"].replace("Jonathan Esk-Riddell <jr@jriddell.org>")
    control.source.delete("Uploaders")
    control.source["Build-depends"].each {|x| x[0].version = nil}
    control.source["Build-depends"].each {|x| x[0].operator = nil}
    debhelper_compat = Debian::Relationship.new("debhelper-compat")
    debhelper_compat.version = "13"
    debhelper_compat.operator = "="
    control.source["Build-depends"].prepend([debhelper_compat])
    control.source["Build-depends"].each {|x| control.source["Build-depends"].delete(x) if x[0].name == "debhelper"}
    control.source["Build-depends"].each do |build_dep|
      if REPLACEMENT_BUILD_DEPENDS.keys.include?(build_dep[0].name)
        control.source["Build-depends"].append([Debian::Relationship.new(REPLACEMENT_BUILD_DEPENDS[build_dep[0].name])])
      end
    end    

    control.source["Build-depends"].each do |build_dep|
      puts "delete pondering #{build_dep[0].name}"
      if REPLACEMENT_BUILD_DEPENDS.keys.include?(build_dep[0].name)
        control.source["Build-depends"].each {|delme| control.source["Build-depends"].delete(delme) if delme[0].name == build_dep[0].name}
      end
    end    

    control.source["Build-depends"].each do |build_dep|
      if build_dep[0].name.include?("libkf5")
        new_build_depend = build_dep[0].name.gsub("libkf5", "kf6-k")
        control.source["Build-depends"].append([Debian::Relationship.new(new_build_depend)])
      end
    end

    control.source["Build-depends"].each do |build_dep|
      puts "delete pondering #{build_dep[0].name}"
      if build_dep[0].name.include?("libkf5")
        control.source["Build-depends"].each {|delme| control.source["Build-depends"].delete(delme) if delme[0].name == build_dep[0].name}
      end
    end

    File.write("#{dir}/debian/control", control.dump)
    
    changelog = "kf6-" + name
    changelog += %q( (0.0-0neon) UNRELEASED; urgency=medium

  * New release

 -- Jonathan Esk-Riddell <jr@jriddell.org>  Mon, 12 Dec 2022 13:04:30 +0000
)
    File.write("#{dir}/debian/changelog", changelog)

    rules = %q(#!/usr/bin/make -f
# -*- makefile -*-

%:
	dh $@ --with kf6 --buildsystem kf6

override_dh_shlibdeps:
	dh_shlibdeps -l$(CURDIR)/debian/$(shell dh_listpackages | head -n1)/usr/kf6/lib/$(DEB_HOST_MULTIARCH)/
)
    File.write("#{dir}/debian/rules", rules)
    cmd.run('wrap-and-sort', chdir: dir)
    cmd.run('git add debian/*install', chdir: dir)
  end
end

if $PROGRAM_NAME == __FILE__
  sixy = KFSixy.new(name: File.basename(Dir.pwd), dir: Dir.pwd)
  sixy.run
end

#if $PROGRAM_NAME == __FILE__
  #sixy = KFSixy.new(name: File.basename('/home/jr/src/pangea-tooling/test/data/test_nci_kf_sixy/test_sixy_repo/threadweaver'), dir: '/home/jr/src/pangea-tooling/test/data/test_nci_kf_sixy/test_sixy_repo/threadweaver')
  #sixy.run
#end
