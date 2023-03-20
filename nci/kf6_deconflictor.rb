#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-FileCopyrightText: 2023 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'fileutils'
require 'json'

require_relative '../lib/apt'
require_relative '../lib/kdeproject_component'

# Installs all kf5 and all kf6
# Compares files in /usr/kf6 with /usr and reports conflicts
class Deconflictor
  def install!
    projects = KDEProjectsComponent.frameworks_jobs.uniq

    # KF5
    kf5_projects = projects.map do |x|
      # deprecations
      next if %w[kross khtml kjs kdesignerplugin oxygen-icons5 kjsembed kdewebkit kinit].include?(x)
      # expected conflicts
      next if %w[breeze-icons].include?(x)
      # new in kf6
      next if %w[kimageformats].include?(x)

      # anomalities that don't get their leading k clipped
      naming_anomalities = %w[
        kde kcm kio kross kjs khtml kapidox kirigami
      ]
      x = x[1..-1] if x[0] == 'k' && naming_anomalities.none? { |y| x.start_with?(y) }
      name = "libkf5#{x}-dev"
      {
        'libkf5baloo-dev' => 'baloo-kf5-dev',
        'libkf5bluez-qt-dev' => 'libkf5bluezqt-dev',
        'libkf5extra-cmake-modules-dev' => 'extra-cmake-modules',
        'libkf5kded-dev' => 'kded5-dev',
        'libkf5kdesu-dev' => 'libkf5su-dev',
        'libkf5activities-stats-dev' => 'libkf5activitiesstats-dev',
        'libkf5kapidox-dev' => 'kapidox',
        'libkf5plasma-framework-dev' => 'libkf5plasma-dev',
        'libkf5syntax-highlighting-dev' => 'libkf5syntaxhighlighting-dev',
        'libkf5quickcharts-dev' => 'kquickcharts-dev',
        'libkf5kirigami-dev' => 'kirigami2-dev',
        'libkf5frameworkintegration-dev' => 'frameworkintegration',
        'libkf5kdeclarative-dev' => 'libkf5declarative-dev',
        'libkf5modemmanager-qt-dev' => 'modemmanager-qt-dev',
        'libkf5networkmanager-qt-dev' => 'libkf5networkmanagerqt-dev',
        'libkf5qqc2-desktop-style-dev' => 'libkf5qqc2desktopstyle-dev',
        'libkf5calcore-dev' => 'libkf5calendarcore-dev',
      }.fetch(name, name)
    end

    # KF6
    kf6_projects = projects.map { |x| "kf6-#{x}-dev" }
    # Remove deprecated and incorrect mappings
    %w[
      kf6-breeze-icons-dev
      kf6-extra-cmake-modules-dev
      kf6-kapidox-dev
      kf6-kcalcore-dev
      kf6-kdelibs4support-dev
      kf6-kdesignerplugin-dev
      kf6-kdewebkit-dev
      kf6-kemoticons-dev
      kf6-khtml-dev
      kf6-kimageformats-dev
      kf6-kinit-dev
      kf6-kirigami-dev
      kf6-kjs-dev
      kf6-kjsembed-dev
      kf6-kmediaplayer-dev
      kf6-kross-dev
      kf6-kxmlrpcclient-dev
      kf6-oxygen-icons5-dev
    ].each { |x| kf6_projects.delete(x) }

    # Add corrected mappings
    # NOTE: ecm is not getting checked because it will remain compatible with kf5 and thus doesn't need co-installability
    # NOTE: kf6-breeze-icons is not packaged because it is a drop in replacement I presume
    kf6_projects += %w[
      kf6-kapidox
      kf6-kimageformat-plugins
      kf6-kirigami2-dev
    ]

    Apt.install(*kf5_projects) || raise
    Apt.install(*kf6_projects) || raise
  end

  def run
    # install!

    conflicts = []
    Dir.glob('/usr/kf6/**/**') do |kf6_path|
      next if File.directory?(kf6_path)

      kf5_path = kf6_path.sub('/usr/kf6/', '/usr/').sub('/usr/kf6/etc/', '/etc/')
      conflicts << [kf6_path, kf5_path] if File.exist?(kf5_path)
    end
    File.write('conflict-report.json', JSON.pretty_generate(conflicts))
    puts 'conflict-report.json'
  end
end

Deconflictor.new.run if $PROGRAM_NAME == __FILE__

__END__

dpkg: warning: overriding problem because --force enabled:
dpkg: warning: trying to overwrite '/etc/xdg/accept-languages.codes', which is also in package kio 5.103.0+p22.04+tunstable+git20230227.0532-0
dpkg: warning: overriding problem because --force enabled:
dpkg: warning: trying to overwrite '/etc/xdg/kshorturifilterrc', which is also in package kio 5.103.0+p22.04+tunstable+git20230227.0532-0
Preparing to unpack .../kf6-baloo_0.0+p22.04+tunstable+git20230306.0155-0_amd64.deb ...
Unpacking kf6-baloo (0.0+p22.04+tunstable+git20230306.0155-0) ...
dpkg: warning: overriding problem because --force enabled:
dpkg: warning: trying to overwrite '/etc/xdg/autostart/baloo_file.desktop', which is also in package baloo-kf5 5.103.0+p22.04+tunstable+git20230226.1031-0
Preparing to unpack .../kf6-bluez-qt_0.0+p22.04+tunstable+git20230308.1238-0_amd64.deb ...
Unpacking kf6-bluez-qt:amd64 (0.0+p22.04+tunstable+git20230308.1238-0) ...
dpkg: warning: overriding problem because --force enabled:
dpkg: warning: trying to overwrite '/lib/udev/rules.d/61-kde-bluetooth-rfkill.rules', which is also in package libkf5bluezqt-data 5.103.0+p22.04+tunstable+git20230214.1617-0
