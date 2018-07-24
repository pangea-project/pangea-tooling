#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require_relative 'jenkins_jobs_update_nci'

SNAPS = %w[
  blinken
  bomber
  bovo
  granatier
  katomic
  kblackbox
  kbruch
  kblocks
  kcalc
  kgeography
  kmplot
  kollision
  konversation
  kruler
  ksquares
  kteatime
  ktuberling
  ktouch
  okular
  picmi
].freeze

# Updates Jenkins Projects
class OpenQAProjectUpdater < ProjectUpdater
  private

  def populate_queue
    NCI.series.each_key do |series|
      # TODO: maybe we should have an editions list?
      NCI.types.each do |type|
        # FIXME: I totally don't like how testing is a regular type permutation
        #   when there is absolutely nothing regular about it!
        next if type == 'testing'

        # FIXME: extend as we extend testing!!!
        next unless series == 'bionic'
        next unless type == 'unstable' || type == 'release'

        # Standard install
        enqueue(OpenQAInstallJob.new(series: series, type: type))
        enqueue(OpenQAInstallOfflineJob.new(series: series, type: type))
        enqueue(OpenQAInstallSecurebootJob.new(series: series, type: type))
        enqueue(OpenQAInstallBIOSJob.new(series: series, type: type))

        if %w[release release.lts].include?(type)
          # TODO: l10n with cala should work nowadays, but needs needles created
          enqueue(OpenQAInstallNonEnglishJob.new(series: series, type: type))
          enqueue(OpenQAInstallOEMJob.new(series: series, type: type))
        end
      end
    end

    SNAPS.each do |snap|
      enqueue(OpenQASnapJob.new(snap, channel: 'candidate'))
    end
  end

  # Don't do a template check. It doesn't support only listing openqa_*
  def check_jobs_exist; end
end

if $PROGRAM_NAME == __FILE__
  updater = OpenQAProjectUpdater.new
  updater.update
  updater.install_plugins
end
