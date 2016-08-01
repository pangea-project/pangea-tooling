# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
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

require_relative '../apt'
require_relative '../ci/source'
require_relative '../dpkg'
require_relative '../lp'
require_relative '../lsb'
require_relative '../repo_abstraction'

module QMLDepVerify
  class PPA
    def initialize
      @log = Logger.new(STDOUT)
      @log.level = Logger::INFO
      @log.progname = self.class.to_s
    end

    def source
      ## Read source defintion
      @source ||= CI::Source.from_json(File.read('source.json'))
    end

    def binaries
      ## Build binary package list from source defintion
      # FIXME: lots of logic dup from install_check
      ppa_base = '~kubuntu-ci/+archive/ubuntu'
      series = Launchpad::Rubber.from_path("ubuntu/#{LSB::DISTRIB_CODENAME}")
      series = series.self_link
      host_arch = Launchpad::Rubber.from_url("#{series}/#{DPKG::HOST_ARCH}")
      ppa = Launchpad::Rubber.from_path("#{ppa_base}/#{source.type}")

      sources = ppa.getPublishedSources(status: 'Published',
                                        source_name: source.name,
                                        version: source.version)
      raise 'more than one source package match on launchpad' if sources.size > 1
      raise 'no source package match on launchpad' if sources.empty?
      source = sources[0]
      binaries = source.getPublishedBinaries
      packages = {}
      binaries.each do |binary|
        next if binary.binary_package_name.end_with?('-dbg')
        next if binary.binary_package_name.end_with?('-dev')
        if binary.architecture_specific
          next unless binary.distro_arch_series_link == host_arch.self_link
        end
        packages[binary.binary_package_name] = binary.binary_package_version
      end
      @log.info "Built package hash: #{packages}"
      # Sort packages such that * > -data > -dev to make time saved from
      # partial-autoremove most likely.
      packages.sort_by do |package, _version|
        next 2 if package.end_with?('-dev')
        next 1 if package.end_with?('-data')
        0
      end.to_h
    end

    def add
      ## Add correct PPA
      Apt.update
      Apt::Repository.new("ppa:kubuntu-ci/#{source.type}").add
      Apt.update
    end
    alias add_ppa add

    def remove
      # TODO: wasn't part of orignial behavior
    end
  end
end
