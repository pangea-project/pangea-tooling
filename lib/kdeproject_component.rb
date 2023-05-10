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
# downloads and makes available as arrays lists of KDE projects which
# are part of Plasma, Applications and Frameworks

require 'httparty'
require 'tmpdir'

class KDEProjectsComponent
  class << self
    @@projects_to_jobs = {'discover'=>'plasma-discover', 'kcalendarcore'=>'kcalcore', 'kdeconnect-kde'=>'kdeconnect', 'kdev-php'=>'kdevelop-php', 'kdev-python'=>'kdevelop-python'}
    @@projects_without_jobs = ['plasma-tests', 'akonadi-airsync', 'akonadi-exchange', 'akonadi-phabricator-resource', 'kpeoplesink', 'akonadiclient', 'kblog']
    ## The only way to get a list of what is in PlaMo Gear releases seems to be a manually maintained list from 
    ## https://plasma-mobile.org/info/plasma-mobile-gear-22-09/
    ## And manually remove the ones that announce says are unstable
    @@plasma_mobile = %w{
      alligator
      angelfish
      audiotube
      calindori
      kalk
      kasts
      kclock
      keysmith
      khealthcertificate
      koko
      kongress
      krecorder
      ktrip
      kweather
      neochat
      plasma-dialer
      plasma-phonebook
      plasma-settings
      plasmatube
      qmlkonsole
      spacebar
      telly-skout
      tokodon
      vakzination
      kweathercore
      kirigami-addons
    }.sort
    @@plasma_mobile = @@plasma_mobile - %w{
      kclock
      krecorder
      qmlkonsole
      tokodon
      plasmatube
      khealthcertificate
      vakzination
    }

    def frameworks
      @frameworks ||= to_names(projects('frameworks'))
    end

    def frameworks_jobs
      @frameworks_packages ||= to_jobs(frameworks)
    end

    def pim
      @pim ||= to_names(projects('pim'))
      @pim << 'kalendar'
    end

    def pim_jobs
      @pim_packgaes ||= to_jobs(pim)
    end

    def mobile
      @@plasma_mobile
    end

    def mobile_jobs
      @@plasma_mobile ||= to_jobs(mobile)
    end

    def gear
      # the way to get what is in KDE Gear (the release service) is from release-tools list
      @release_service ||= begin
        modules = []
        url = "http://embra.edinburghlinux.co.uk/~jr/release-tools/modules.git"
        response = HTTParty.get(url)
        body = response.body
        body.each_line("release/23.04\n") do |line|
          modules << line.split(/\s/, 2)[0]
        end
        modules
      end.sort
    end

    def gear_jobs
      @gear_jobs ||= to_jobs(gear).reject {|x| @@projects_without_jobs.include?(x)}
    end

    def plasma
      # the way to get what is in plasma is from this list in plasma release tools
      @plasma ||= begin
        url = "https://raw.githubusercontent.com/KDE/releaseme/master/plasma/git-repositories-for-release"
        response = HTTParty.get(url)
        body = response.body
        modules = body.split
        modules.sort
      end
    end

    def plasma_jobs
      @plasma_jobs ||= to_jobs(plasma).reject {|x| @@projects_without_jobs.include?(x)}
    end

    private

    def to_jobs(projects)
      projects.collect { |x| @@projects_to_jobs[x]? @@projects_to_jobs[x] : x }
    end

    def to_names(projects)
      projects.collect { |project| project.split('/')[-1] }
    end

    def projects(filter)
      url = "https://projects.kde.org/api/v1/projects/#{filter}"
      response = HTTParty.get(url)
      response.parsed_response
    end
  end
end
