#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'git'
require 'json'
require 'logger'
require 'logger/colors'
require 'tmpdir'

require_relative '../../ci-tooling/lib/projects/factory/neon'
require_relative 'data'

# Finds latest tag of ECM and then makes sure all other frameworks
# have the same base version in their tag (i.e. the tags are consistent)
module NCI
  module DebianMerge
    # Finds latest tag of ECM and then compile a list of all frameworks
    # that have this base version tagged as well. It asserts that all frameworks
    # should have the same version tagged. They may have a newer version tagged.
    class TagDetective
      ORIGIN = 'origin/master'
      ECM = 'kde/extra-cmake-modules'

      # exclusion should only include proper non-frameworks, if something
      # is awray with an actual framework that is released it should either
      # be fixed for the detective logic needs to be adapted to skip it.
      EXCLUSION = %w[
        kde/akonadi-calendar-tools
        kde/akonadi-calendar
        kde/akonadi-contacts
        kde/akonadi-import-wizard
        kde/akonadi-mime
        kde/akonadi-notes
        kde/akonadi-search
        kde/akonadi
        kde/akonadiconsole
        kde/akregator
        kde/analitza
        kde/ark
        kde/artikulate
        kde/audiocd-kio
        kde/baloo-widgets
        kde/blinken
        kde/blogilo
        kde/bluedevil
        kde/bomber
        kde/bovo
        kde/breeze-grub
        kde/breeze-gtk
        kde/breeze-plymouth
        kde/breeze-qt4
        kde/breeze
        kde/calendarsupport
        kde/cantor
        kde/cervisia
        kde/dolphin-plugins
        kde/dolphin
        kde/dragon
        kde/drkonqi
        kde/eventviews
        kde/ffmpegthumbs
        kde/filelight
        kde/granatier
        kde/grantlee-editor
        kde/grantleetheme
        kde/gwenview
        kde/incidenceeditor
        kde/jovie
        kde/juk
        kde/kb
        kde/kaccessible
        kde/kaccounts-integration
        kde/kaccounts-mobile
        kde/kaccounts-providers
        kde/kactivitymanagerd
        kde/kaddressbook
        kde/kajongg
        kde/kalarm
        kde/kalarmcal
        kde/kalgebra
        kde/kalzium
        kde/kamera
        kde/kamoso
        kde/kanagram
        kde/kapman
        kde/kapptemplate
        kde/kate
        kde/katomic
        kde/kbackup
        kde/kblackbox
        kde/kblocks
        kde/kblog
        kde/kbounce
        kde/kbreakout
        kde/kbruch
        kde/kcachegrind
        kde/kcalc
        kde/kcalcore
        kde/kcalutils
        kde/kcharselect
        kde/kcm-touchpad
        kde/kcolorchooser
        kde/kcontacts
        kde/kcron
        kde/kdav
        kde/kde-base-artwork
        kde/kde-baseapps
        kde/kde-cli-tools
        kde/kde-dev-scripts
        kde/kde-dev-utils
        kde/kde-gtk-config
        kde/kde-l0n
        kde/kde-runtime
        kde/kde4libs
        kde/kdebugsettings
        kde/kdecoration
        kde/kdeedu-data
        kde/kdegraphics-mobipocket
        kde/kdegraphics-thumbnailers
        kde/kdenetwork-filesharing
        kde/kdepim-addons
        kde/kdepim-apps-libs
        kde/kdepim-runtime
        kde/kdepimlibs
        kde/kdeplasma-addons
        kde/kdesdk-kioslaves
        kde/kdesdk-thumbnailers
        kde/kdewebdev
        kde/kdf
        kde/kdialog
        kde/kdiamond
        kde/keditbookmarks
        kde/kfind
        kde/kfloppy
        kde/kfourinline
        kde/kgamma5
        kde/kgeography
        kde/kget
        kde/kgoldrunner
        kde/kgpg
        kde/khangman
        kde/khelpcenter
        kde/kholi
        kde/khotkeys
        kde/kin
        kde/kidentitymanagement
        kde/kig
        kde/kigo
        kde/killbots
        kde/kimagemapeditor
        kde/kimap
        kde/kinfocenter
        kde/kio-extras
        kde/kiriki
        kde/kiten
        kde/kitinerary
        kde/kjumpingcube
        kde/kldap
        kde/kleopatra
        kde/klettres
        kde/klickety
        kde/klines
        kde/kmag
        kde/kmahjongg
        kde/kmail-account-wizard
        kde/kmail
        kde/kmailtransport
        kde/kmbox
        kde/kmediaplayer
        kde/kmenuedit
        kde/kmime
        kde/kmines
        kde/kmix
        kde/kmousetool
        kde/kmouth
        kde/kmplot
        kde/knavalbattle
        kde/knetwalk
        kde/knights
        kde/knotes
        kde/kolf
        kde/kollision
        kde/kolourpaint
        kde/kompare
        kde/konqueror
        kde/konquest
        kde/konsole
        kde/kontact
        kde/kontactinterface
        kde/kopete
        kde/korganizer
        kde/kpat
        kde/kpimtextedit
        kde/kpkpass
        kde/kppp
        kde/kqtquickcharts
        kde/krdc
        kde/kremotecontrol
        kde/kreversi
        kde/krfb
        kde/kross-interpreters
        kde/kruler
        kde/kscd
        kde/kscreen
        kde/kscreenlocker
        kde/kshisen
        kde/ksirk
        kde/ksmtp
        kde/ksnakeduel
        kde/ksnapshot
        kde/kspaceduel
        kde/ksquares
        kde/ksshaskpass
        kde/ksudoku
        kde/ksysguard
        kde/ksystemlog
        kde/kteatime
        kde/ktimer
        kde/ktnef
        kde/ktouch
        kde/ktp-accounts-kcm
        kde/ktp-approver
        kde/ktp-auth-handler
        kde/ktp-call-ui
        kde/ktp-common-internals
        kde/ktp-contact-list
        kde/ktp-contact-runner
        kde/ktp-desktop-applets
        kde/ktp-filetransfer-handler
        kde/ktp-kded-module
        kde/ktp-send-file
        kde/ktp-text-ui
        kde/ktuberling
        kde/kturtle
        kde/ktux
        kde/kubrick
        kde/kwallet-pam
        kde/kwalletmanager
        kde/kwave
        kde/kwayland-integration
        kde/kwordquiz
        kde/kwrited
        kde/libbluedevil
        kde/libgravatar
        kde/libkcddb
        kde/libkcompactdisc
        kde/libkdcraw
        kde/libkdegames
        kde/libkdegames4
        kde/libkdepim
        kde/libkeduvocdocument
        kde/libkexiv2
        kde/libkface
        kde/libkgapi
        kde/libkgeomap
        kde/libkipi
        kde/libkleo
        kde/libkmahjongg
        kde/libkomparediff2
        kde/libksane
        kde/libkscreen
        kde/libksieve
        kde/libksysguard
        kde/libmm-qt
        kde/lokalize
        kde/lskat
        kde/mailcommon
        kde/mailimporter
        kde/marble
        kde/mbox-importer
        kde/messagelib
        kde/meta-kde-telepathy
        kde/meta-kde
        kde/milou
        kde/okular
        kde/oxygen-fonts
        kde/oxygen-qt4
        kde/oxygen
        kde/pairs
        kde/palapeli
        kde/parley
        kde/picmi
        kde/pim-data-exporter
        kde/pim-sieve-editor
        kde/pimcommon
        kde/plasma-browser-integration
        kde/plasma-desktop
        kde/plasma-discover
        kde/plasma-mediacenter
        kde/plasma-nm
        kde/plasma-pa
        kde/plasma-sdk
        kde/plasma-tests
        kde/plasma-vault
        kde/plasma-workspace-wallpapers
        kde/plasma-workspace
        kde/plymouth-kcm
        kde/polkit-kde-agent
        kde/powerdevil
        kde/poxml
        kde/print-manager
        kde/rocs
        kde/sddm-kcm
        kde/signon-kwallet-extension
        kde/spectacle
        kde/step
        kde/svgpart
        kde/sweeper
        kde/systemsettings
        kde/umbrello
        kde/user-manager
        kde/xdg-desktop-portal-kde
        kde/zeroconf-ioslave
      ].freeze

      def initialize
        @log = Logger.new(STDOUT)
      end

      def list_frameworks
        @log.info 'listing frameworks'
        ProjectsFactory::Neon.ls.select do |x|
          x.start_with?('kde/') && !EXCLUSION.include?(x)
        end
      end

      def frameworks
        @frameworks ||= list_frameworks.collect do |x|
          File.join(ProjectsFactory::Neon.url_base, x)
        end
      end

      def last_tag_base
        @last_tag_base ||= begin
          @log.info 'finding latest tag of ECM'
          ecm = frameworks.find { |x| x.include?(ECM) }
          raise unless ecm
          Dir.mktmpdir do |tmpdir|
            git = Git.clone(ecm, tmpdir)
            last_tag = git.describe(ORIGIN, tags: true, abbrev: 0)
            last_tag.reverse.split('-', 2)[-1].reverse
          end
        end
      end

      def investigation_data
        # TODO: this probably should be moved to Data class
        data = {}
        data[:tag_base] = last_tag_base
        data[:repos] = frameworks.dup.keep_if do |url|
          include?(url)
        end
        data
      end

      def valid_and_released?(url)
        remote = Git.ls_remote(url)
        valid = remote.fetch('tags', {}).keys.any? do |x|
          version = x.split('4%').join.split('5%').join
          version.start_with?(last_tag_base)
        end
        released = remote.fetch('branches', {}).keys.any? do |x|
          x == 'Neon/release'
        end
        [valid, released]
      end

      def include?(url)
        @log.info "Checking if tag matches on #{url}"
        valid, released = valid_and_released?(url)
        if valid
          @log.info " looking good #{url}"
          return true
        elsif !valid && released
          raise "found no #{last_tag_base} tag in #{url}" unless valid
        end
        # Skip repos that have no release branch AND aren't valid.
        # They are unreleased, so we don't expect them to have a tag and can
        # simply skip them but don't raise an error.
        @log.warn "  skipping #{url} as it is not released and has no tag"
        false
      end

      def reuse_old_data?
        return false unless Data.file_exist?
        olddata = Data.from_file
        olddata.tag_base == last_tag_base
      end

      def run
        return if reuse_old_data?
        Data.write(investigation_data)
      end
      alias investigate run
    end
  end
end

# :nocov:
NCI::DebianMerge::TagDetective.new.run if $PROGRAM_NAME == __FILE__
# :nocov:
