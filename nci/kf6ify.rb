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

# Iterates all plasma repos and adjusts the packaging for the kf5->kf6 transition.
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
      unless relationship.version&.start_with?('${')
        relationship.operator = nil
        relationship.version = nil
      end
      relationship
    end
  end

  def run
    if File.exist?('kf6')
      Dir.chdir('kf6')
    else
      Dir.mkdir('kf6')
      Dir.chdir('kf6')

      repos = ProjectsFactory::Neon.ls
      KDEProjectsComponent.plasma_jobs.uniq.each do |project|
        repo = repos.find { |x| x.end_with?("/#{project}") }
        p [project, repo]
        cmd.run('git', 'clone', "git@invent.kde.org:neon/#{repo}")
      end
    end

    Dir.glob('*') do |dir|
      p dir
      Dir.chdir(dir) do
        cmd.run('git', 'reset', '--hard')
        cmd.run('git', 'checkout', 'Neon/unstable')
        cmd.run('git', 'reset', '--hard', 'origin/Neon/unstable')
        control = Debian::Control.new
        control.parse!

        control.source['Build-Depends'].collect! { |relationships| relator(relationships) }
        control.source['Build-Depends'].compact!

        control.binaries.collect! do |binary|
          binary['Depends']&.collect! { |relationships| relator(relationships) }
          binary['Depends']&.compact!
          binary
        end

        File.write('debian/control', control.dump)
        File.write('debian/rules', File.read("#{__dir__}/data/rules.kf6.data"))
        cmd.run('wrap-and-sort')

        cmd.run('git', 'commit', '--all', '--message', 'port to kf6') unless cmd.run!('git', 'diff', '--quiet').success?
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  Mutagen.new.run
end

__END__
# This is yaml data for the mapping table!

# packaging
pkg-kde-tools: pkg-kde-tools-neon

# plasma
libkfontinst5: libkfontinst6
libkfontinstui5: libkfontinstui6
libplasma-geolocation-interface5: libplasma-geolocation-interface6
libkworkspace5-5: libkworkspace6
libkdecorations2-5v5: libkdecorations2-5v5
libkpipewire5: libkpipewire5
libkpipewirerecord5: libkpipewirerecord5
libkf5screen8: libkf6screen8
libkf5screendpms8: libkf6screendpms8
libkf5screen-bin: libkf6screen-bin
libkscreenlocker5: libkscreenlocker5
liblayershellqtinterface5: liblayershellqtinterface5
libkf5sysguard-bin: libkf6sysguard-bin
libkf5sysguard-data: libkf6sysguard-data
libkf5sysguard-dev: libkf6sysguard-dev
kde-style-oxygen-qt5: kde-style-oxygen-qt6
libpowerdevilui5: libpowerdevilui5

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
libkf5texteditor-dev: kf6-ktexteditor-dev
libkf5textwidgets-dev: kf6-ktextwidgets-dev
libkf5wallet-dev: kf6-kwallet-dev
libkf5itemmodels-dev: kf6-kitemmodels-dev
libkf5windowsystem-dev: kf6-kwindowsystem-dev
libkf5bluezqt-dev: kf6-bluez-qt-dev
libkf5doctools-dev: kf6-kdoctools-dev
libkf5iconthemes-dev: kf6-kiconthemes-dev
libkf5kio-dev: kf6-kio-dev
libkf5notifications-dev: kf6-knotifications-dev
libkf5widgetsaddons-dev: kf6-kwidgetsaddons-dev
libkf5configwidgets-dev: kf6-kconfigwidgets-dev
libkf5guiaddons-dev: kf6-kguiaddons-dev
libkf5service-dev: kf6-kservice-dev
libkf5style-dev: kf6-kstyle-dev
libkf5wayland-dev: kf6-kwayland-dev
libkf5archive-dev: kf6-karchive-dev
libkf5attica-dev: kf6-attica-dev
kirigami2-dev: kf6-kirigami-dev
libkf5itemviews-dev: kf6-kitemviews-dev
libkf5purpose-dev: kf6-purpose-dev
libkf5xmlgui-dev: kf6-kxmlgui-dev
libkf5completion-dev: kf6-kcompletion-dev
libkf5jobwidgets-dev: kf6-kjobwidgets-dev
libkf5unitconversion-dev: kf6-kunitconversion-dev
libkf5sonnet-dev: kf6-sonnet-dev
libkf5pty-dev: kf6-kpty-dev
libkf5auth-dev: kf6-kauth-dev
libkf5filemetadata-dev: kf6-kfilemetadata-dev
libkf5emoticons-dev: null
libkf5qqc2desktopstyle-dev: kf6-qqc2-desktop-style-dev

baloo-kf5: kf6-baloo
kded5: kf6-kded
libkf5globalaccel-bin: kf6-kglobalaccel
libkf5service-bin: kf6-kservice
plasma-framework: kf6-plasma-framework
libkf5su-bin: kf6-kdesu
kpackagetool5: kf6-kpackage
libkf5purpose5: kf6-purpose

# deprecated
libkf5webkit-dev: null
libkf5kdelibs4support-dev: null
libkf5xmlrpcclient-dev: null
libtelepathy-qt5-dev: null
libkf5khtml-dev: null

# supplimental
libdbusmenu-qt5-dev: libdbusmenu-qt6-dev
libpackagekitqt5-dev: libpackagekitqt6-dev
libphonon4qt5-dev: libphonon4qt6-dev
libphonon4qt5experimental-dev: libphonon4qt6experimental-dev
libpolkit-qt5-1-dev: libpolkit-qt6-1-dev
libqca-qt5-2-dev: libqca-qt6-2-dev
libqaccessibilityclient-qt5-dev: libqaccessibilityclient-qt6-dev

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
libqt5webview5-dev: qt6-webview-dev
libqt5waylandclient5-dev: qt6-wayland-dev

libqt5sql5-sqlite: qt6-base
qtwayland5: qt6-wayland
qdbus-qt5: qt6-tools
qttools5-dev-tools: qt6-tools-dev-tools
qt5-qmake-bin: null

# unclear???
libqt5x11extras5-dev: null
libqt5webkit5-dev: null
