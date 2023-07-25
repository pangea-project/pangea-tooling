#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-FileCopyrightText: 2023 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'fileutils'
require 'json'

require_relative 'lib/setup_repo'
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
      next nil if %w[kross khtml kjs kdesignerplugin oxygen-icons5 kjsembed kdewebkit kinit].include?(x)
      # expected conflicts
      next nil if %w[breeze-icons].include?(x)
      # new in kf6
      next nil if %w[kimageformats kcolorscheme].include?(x)

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
    end.compact
    kf5_projects += JSON.parse(DATA.read)
    kf5_projects.uniq!

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
      kf6-ksvg-dev
      kf6-ktexttemplate-dev
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
    # Drop all dpkg configs so locales and the like get installed.
    FileUtils.rm_rf(Dir.glob('/etc/dpkg/dpkg.cfg.d/*'))
    NCI.setup_proxy!
    NCI.add_repo_key!
    NCI.setup_repo!
    install!

    conflicts = []
    Dir.glob('/usr/kf6/**/**') do |kf6_path|
      next if File.directory?(kf6_path)
      next if kf6_path.include?('share/ECM/') || kf6_path.include?('share/doc/ECM')

      kf5_path = kf6_path.sub('/usr/kf6/etc/', '/etc/').sub('/usr/kf6/', '/usr/')
      conflicts << [kf6_path, kf5_path] if File.exist?(kf5_path)
    end
    File.write('conflict-report.json', JSON.pretty_generate(conflicts))
    puts 'conflict-report.json'
  end
end

Deconflictor.new.run if $PROGRAM_NAME == __FILE__

__END__

[
  "libkf5attica-dev",
  "libkf5attica-doc",
  "libkf5attica5",
  "baloo-kf5",
  "baloo-kf5-dev",
  "libkf5baloo-doc",
  "libkf5baloo5",
  "libkf5balooengine5",
  "libkf5bluezqt-data",
  "libkf5bluezqt-dev",
  "libkf5bluezqt-doc",
  "libkf5bluezqt6",
  "qml-module-org-kde-bluezqt",
  "breeze-icon-theme",
  "breeze-icon-theme-rcc",
  "extra-cmake-modules",
  "extra-cmake-modules-doc",
  "frameworkintegration",
  "libkf5style-dev",
  "libkf5style5",
  "kactivities-bin",
  "libkf5activities-dev",
  "libkf5activities-doc",
  "libkf5activities5",
  "qml-module-org-kde-activities",
  "libkf5activitiesstats-dev",
  "libkf5activitiesstats-doc",
  "libkf5activitiesstats1",
  "kapidox",
  "libkf5archive-dev",
  "libkf5archive-doc",
  "libkf5archive5",
  "libkf5auth-data",
  "libkf5auth-dev",
  "libkf5auth-dev-bin",
  "libkf5auth-doc",
  "libkf5auth5",
  "libkf5authcore5",
  "libkf5auth-bin-dev",
  "libkf5bookmarks-data",
  "libkf5bookmarks-dev",
  "libkf5bookmarks-doc",
  "libkf5bookmarks5",
  "libkf5calendarcore-dev",
  "libkf5calendarcore5",
  "libkf5kcmutils-data",
  "libkf5kcmutils-dev",
  "libkf5kcmutils-doc",
  "libkf5kcmutils5",
  "libkf5kcmutilscore5",
  "qml-module-org-kde-kcmutils",
  "libkf5codecs-data",
  "libkf5codecs-dev",
  "libkf5codecs-doc",
  "libkf5codecs5",
  "libkf5completion-data",
  "libkf5completion-dev",
  "libkf5completion-doc",
  "libkf5completion5",
  "libkf5config-bin",
  "libkf5config-data",
  "libkf5config-dev",
  "libkf5config-dev-bin",
  "libkf5config-doc",
  "libkf5configcore5",
  "libkf5configgui5",
  "libkf5configqml5",
  "libkf5config-bin-dev",
  "libkf5configwidgets-data",
  "libkf5configwidgets-dev",
  "libkf5configwidgets-doc",
  "libkf5configwidgets5",
  "libkf5contacts-dev",
  "libkf5contacts-data",
  "libkf5contacts5",
  "libkf5contacts-doc",
  "libkf5coreaddons-data",
  "libkf5coreaddons-dev",
  "libkf5coreaddons-dev-bin",
  "libkf5coreaddons-doc",
  "libkf5coreaddons5",
  "libkf5crash-dev",
  "libkf5crash-doc",
  "libkf5crash5",
  "libkf5dav-data",
  "libkf5dav-dev",
  "libkf5dav5",
  "libkf5dbusaddons-bin",
  "libkf5dbusaddons-data",
  "libkf5dbusaddons-dev",
  "libkf5dbusaddons-doc",
  "libkf5dbusaddons5",
  "kpackagelauncherqml",
  "libkf5calendarevents5",
  "libkf5declarative-data",
  "libkf5declarative-dev",
  "libkf5declarative-doc",
  "libkf5declarative5",
  "libkf5quickaddons5",
  "qml-module-org-kde-draganddrop",
  "qml-module-org-kde-kcm",
  "qml-module-org-kde-kconfig",
  "qml-module-org-kde-graphicaleffects",
  "qml-module-org-kde-kcoreaddons",
  "qml-module-org-kde-kio",
  "qml-module-org-kde-kquickcontrols",
  "qml-module-org-kde-kquickcontrolsaddons",
  "qml-module-org-kde-kwindowsystem",
  "qtdeclarative5-kf5declarative",
  "kded5",
  "kded5-dev",
  "libkf5kdelibs4support-data",
  "libkf5kdelibs4support-dev",
  "libkf5kdelibs4support5",
  "libkf5kdelibs4support5-bin",
  "kdesignerplugin",
  "kdesignerplugin-data",
  "kgendesignerplugin",
  "kgendesignerplugin-bin",
  "libkf5su-bin",
  "libkf5su-data",
  "libkf5su-dev",
  "libkf5su-doc",
  "libkf5su5",
  "libkf5webkit-dev",
  "libkf5webkit5",
  "libkf5dnssd-data",
  "libkf5dnssd-dev",
  "libkf5dnssd-doc",
  "libkf5dnssd5",
  "kdoctools-dev",
  "kdoctools5",
  "libkf5doctools-dev",
  "libkf5doctools5",
  "libkf5emoticons-bin",
  "libkf5emoticons-data",
  "libkf5emoticons-dev",
  "libkf5emoticons-doc",
  "libkf5emoticons5",
  "libkf5filemetadata-bin",
  "libkf5filemetadata-data",
  "libkf5filemetadata-dev",
  "libkf5filemetadata-doc",
  "libkf5filemetadata3",
  "libkf5globalaccel-bin",
  "libkf5globalaccel-data",
  "libkf5globalaccel-dev",
  "libkf5globalaccel-doc",
  "libkf5globalaccel5",
  "libkf5globalaccelprivate5",
  "libkf5guiaddons-bin",
  "libkf5guiaddons-data",
  "libkf5guiaddons-dev",
  "libkf5guiaddons-doc",
  "libkf5guiaddons5",
  "libkf5holidays-data",
  "libkf5holidays-dev",
  "libkf5holidays-doc",
  "libkf5holidays5",
  "qml-module-org-kde-kholidays",
  "libkf5khtml-bin",
  "libkf5khtml-data",
  "libkf5khtml-dev",
  "libkf5khtml5",
  "libkf5i18n-data",
  "libkf5i18n-dev",
  "libkf5i18n-doc",
  "libkf5i18n5",
  "libkf5i18nlocaledata5",
  "qml-module-org-kde-i18n-localedata",
  "libkf5iconthemes-bin",
  "libkf5iconthemes-data",
  "libkf5iconthemes-dev",
  "libkf5iconthemes-doc",
  "libkf5iconthemes5",
  "libkf5idletime-dev",
  "libkf5idletime-doc",
  "libkf5idletime5",
  "kimageformat-plugins",
  "kinit",
  "kinit-dev",
  "kio",
  "kio-dev",
  "libkf5kio-dev",
  "libkf5kio-doc",
  "libkf5kiocore5",
  "libkf5kiofilewidgets5",
  "libkf5kiogui5",
  "libkf5kiontlm5",
  "libkf5kiowidgets5",
  "kirigami2-dev",
  "libkf5kirigami2-5",
  "libkf5kirigami2-doc",
  "qml-module-org-kde-kirigami2",
  "libkf5itemmodels-dev",
  "libkf5itemmodels-doc",
  "libkf5itemmodels5",
  "qml-module-org-kde-kitemmodels",
  "libkf5itemviews-data",
  "libkf5itemviews-dev",
  "libkf5itemviews-doc",
  "libkf5itemviews5",
  "libkf5jobwidgets-data",
  "libkf5jobwidgets-dev",
  "libkf5jobwidgets-doc",
  "libkf5jobwidgets5",
  "libkf5js5",
  "libkf5jsapi5",
  "libkf5kjs-dev",
  "libkf5jsembed-data",
  "libkf5jsembed-dev",
  "libkf5jsembed5",
  "libkf5mediaplayer-data",
  "libkf5mediaplayer-dev",
  "libkf5mediaplayer5",
  "libkf5newstuff-data",
  "libkf5newstuff-dev",
  "libkf5newstuff-doc",
  "libkf5newstuff5",
  "libkf5newstuffcore5",
  "libkf5newstuffwidgets5",
  "qml-module-org-kde-newstuff",
  "knewstuff-dialog",
  "libkf5notifications-data",
  "libkf5notifications-dev",
  "libkf5notifications-doc",
  "libkf5notifications5",
  "qml-module-org-kde-notification",
  "libkf5notifyconfig-data",
  "libkf5notifyconfig-dev",
  "libkf5notifyconfig-doc",
  "libkf5notifyconfig5",
  "kpackagetool5",
  "libkf5package-data",
  "libkf5package-dev",
  "libkf5package-doc",
  "libkf5package5",
  "libkf5parts-data",
  "libkf5parts-dev",
  "libkf5parts-doc",
  "libkf5parts-plugins",
  "libkf5parts5",
  "libkf5people-data",
  "libkf5people-dev",
  "libkf5people-doc",
  "libkf5people5",
  "libkf5peoplebackend5",
  "libkf5peoplewidgets5",
  "qml-module-org-kde-people",
  "libkf5plotting-dev",
  "libkf5plotting-doc",
  "libkf5plotting5",
  "libkf5pty-data",
  "libkf5pty-dev",
  "libkf5pty-doc",
  "libkf5pty5",
  "kquickcharts-dev",
  "qml-module-org-kde-quickcharts",
  "kross",
  "kross-dev",
  "libkf5krosscore5",
  "libkf5krossui5",
  "libkf5runner-dev",
  "libkf5runner-doc",
  "libkf5runner5",
  "qml-module-org-kde-runnermodel",
  "libkf5service-bin",
  "libkf5service-data",
  "libkf5service-dev",
  "libkf5service-doc",
  "libkf5service5",
  "ktexteditor-data",
  "ktexteditor-katepart",
  "libkf5texteditor-bin",
  "libkf5texteditor-dev",
  "libkf5texteditor-doc",
  "libkf5texteditor5",
  "libkf5textwidgets-data",
  "libkf5textwidgets-dev",
  "libkf5textwidgets-doc",
  "libkf5textwidgets5",
  "libkf5unitconversion-data",
  "libkf5unitconversion-dev",
  "libkf5unitconversion-doc",
  "libkf5unitconversion5",
  "libkf5wallet-bin",
  "libkf5wallet-data",
  "libkf5wallet-dev",
  "libkf5wallet-doc",
  "libkf5wallet5",
  "libkwalletbackend5-5",
  "kwayland-data",
  "kwayland-dev",
  "libkf5wayland-dev",
  "libkf5wayland-doc",
  "libkf5waylandclient5",
  "libkf5waylandserver5",
  "libkf5widgetsaddons-data",
  "libkf5widgetsaddons-dev",
  "libkf5widgetsaddons-doc",
  "libkf5widgetsaddons5",
  "libkf5windowsystem-data",
  "libkf5windowsystem-dev",
  "libkf5windowsystem-doc",
  "libkf5windowsystem5",
  "libkf5xmlgui-bin",
  "libkf5xmlgui-data",
  "libkf5xmlgui-dev",
  "libkf5xmlgui-doc",
  "libkf5xmlgui5",
  "libkf5xmlrpcclient-data",
  "libkf5xmlrpcclient-dev",
  "libkf5xmlrpcclient-doc",
  "libkf5xmlrpcclient5",
  "libkf5modemmanagerqt-doc",
  "libkf5modemmanagerqt6",
  "modemmanager-qt-dev",
  "libkf5networkmanagerqt-dev",
  "libkf5networkmanagerqt-doc",
  "libkf5networkmanagerqt6",
  "oxygen-icon-theme",
  "libkf5plasma-dev",
  "libkf5plasma-doc",
  "libkf5plasma5",
  "libkf5plasmaquick5",
  "plasma-framework",
  "libkf5prison-dev",
  "libkf5prison-doc",
  "libkf5prison5",
  "libkf5prisonscanner5",
  "qml-module-org-kde-prison",
  "libkf5purpose-bin",
  "libkf5purpose-dev",
  "libkf5purpose5",
  "qml-module-org-kde-purpose",
  "libkf5qqc2desktopstyle-dev",
  "qml-module-org-kde-qqc2desktopstyle",
  "libkf5solid-bin",
  "libkf5solid-dev",
  "libkf5solid-doc",
  "libkf5solid5",
  "libkf5solid5-data",
  "qml-module-org-kde-solid",
  "qtdeclarative5-kf5solid",
  "libkf5sonnet-dev",
  "libkf5sonnet-dev-bin",
  "libkf5sonnet-doc",
  "libkf5sonnet5-data",
  "libkf5sonnetcore5",
  "libkf5sonnetui5",
  "sonnet-plugins",
  "qml-module-org-kde-sonnet",
  "libkf5syndication-dev",
  "libkf5syndication5abi1",
  "libkf5syndication5",
  "libkf5syndication-doc",
  "libkf5syntaxhighlighting-data",
  "libkf5syntaxhighlighting-dev",
  "libkf5syntaxhighlighting-doc",
  "libkf5syntaxhighlighting-tools",
  "libkf5syntaxhighlighting5",
  "qml-module-org-kde-syntaxhighlighting",
  "libkf5threadweaver-dev",
  "libkf5threadweaver-doc",
  "libkf5threadweaver5"
]
