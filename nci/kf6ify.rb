#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-FileCopyrightText: 2023 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/debian/control'
require_relative '../lib/kdeproject_component'
require_relative '../lib/projects/factory/neon'

require 'awesome_print'
require 'deep_merge'
require 'tty/command'
require 'yaml'

class Mutagen
  attr_reader :cmd
  attr_reader :map

  def initialize
    @cmd = TTY::Command.new
    @map = YAML.load(DATA.read)
  end

  def relator(relationships)
    relationships.collect do |relationship|
      next relationship unless relationship.name.include?('5')

      new = map.fetch(relationship.name)
      next nil if new.nil?

      relationship.name.replace(new)
      relationship
    end
  end

  def run
    FileUtils.rm_rf('kf6')
    Dir.mkdir('kf6')
    Dir.chdir('kf6')

    repos = ProjectsFactory::Neon.ls
    KDEProjectsComponent.plasma_jobs.each do |project|
      repo = repos.find { |x| x.end_with?(project) }
      cmd.run('git', 'clone', "git@invent.kde.org:neon/#{repo}")
      Dir.chdir(File.basename(repo)) do
        control = Debian::Control.new
        control.parse!

        control.source['Build-Depends'].collect! { |relationships| relator(relationships) }
        control.source['Build-Depends'].compact!

        control.binaries.collect! do |binary|
          binary['Depends'].collect! { |relationships| relator(relationships) }
          binary['Depends'].compact!
          binary
        end

        File.write('debian/control', control.dump)
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  Mutagen.new.run
end

__END__
# This is yaml data for the mapping table!

# plasma
libkfontinst5: libkfontinst6
libkfontinstui5: libkfontinstui6
libplasma-geolocation-interface5: libplasma-geolocation-interface6
libkworkspace5-5: libkworkspace6

# kf5
baloo-kf5-dev: kf6-baloo-dev
kded5-dev: kf6-kded-dev
libkf5activities-dev: kf6-kactivities-dev
libkf5activitiesstats-dev: kf6-kactivities-stats-dev
libkf5config-dev: kf6-kconfig-dev
libkf5coreaddons-dev: kf6-kcoreaddons-dev
libkf5crash-dev: kf6-kcrash-dev
libkf5dbusaddons-dev: kf6-kdbusaddons-dev
libkf5declarative-dev: kf6-kdeclarative-dev
libkf5globalaccel-dev: kf6-kglobalaccel-dev
libkf5holidays-dev: kf6-kholidays-dev
libkf5i18n-dev: kf6-ki18n-dev
libkf5idletime-dev: kf6-kidletime-dev
libkf5kcmutils-dev: kf6-kcmutils-dev
libkf5kexiv2-dev: kf6-kexiv2-dev
libkf5networkmanagerqt-dev: kf6-networkmanager-qt-dev
libkf5newstuff-dev: kf6-knewstuff-dev
libkf5notifyconfig-dev: kf6-knotifyconfig-dev
libkf5package-dev: kf6-kpackage-dev
libkf5people-dev: kf6-kpeople-dev
libkf5plasma-dev: kf6-plasma-framework-dev
libkf5prison-dev: kf6-prison-dev
libkf5runner-dev: kf6-krunner-dev
libkf5screen-dev: kf6-kscreen-dev
libkf5solid-dev: kf6-solid-dev
libkf5su-dev: kf6-kdesu-dev
libkf5syntaxhighlighting-dev: kf6-syntax-highlighting-dev
libkf5sysguard-dev: kf6-ksysguard-dev
libkf5texteditor-dev: kf6-ktexteditor-dev
libkf5textwidgets-dev: kf6-ktextwidgets-dev
libkf5wallet-dev: kf6-kwallet-dev
libkf5itemmodels-dev: kf6-kitemmodels-dev
libkf5windowsystem-dev: kf6-kwindowsystem-dev
libkf5bluezqt-dev: kf6-bluez-qt-dev

kded5: kf6-kded
libkf5globalaccel-bin: kf6-kglobalaccel
libkf5service-bin: kf6-kservice

# deprecated
libkf5webkit-dev: null
libkf5kdelibs4support-dev: null
libkf5xmlrpcclient-dev: null

# supplimental
libdbusmenu-qt5-dev: libdbusmenu-qt6-dev
libpackagekitqt5-dev: libpackagekitqt6-dev
libphonon4qt5-dev: libphonon4qt6-dev
libphonon4qt5experimental-dev: libphonon4qt6experimental-dev
libpolkit-qt5-1-dev: libpolkit-qt6-1-dev

# qt
qtbase5-dev: qt6-base-dev
qtbase5-private-dev: qt6-base-dev
qtdeclarative5-dev: qt6-declarative-dev
qtscript5-dev: null
qtwayland5-dev-tools: qt6-wayland-dev-tools
qtwayland5-private-dev: qt6-wayland-dev
libqt5sensors5-dev: qt6-sensors-dev
libqt5svg5-dev: qt6-svg-dev
qttools5-dev: qt6-tools-dev
qtmultimedia5-dev: qt6-multimedia-dev
qtquickcontrols2-5-dev: qt6-declarative-dev
qtwebengine5-dev: qt6-webengine-dev

qtwayland5: qt6-wayland
qdbus-qt5: qt6-tools

# unclear???
libqt5x11extras5-dev: null
libqt5webkit5-dev: null
