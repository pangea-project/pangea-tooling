# frozen_string_literal: true
#
# Copyright (C) 2016-2017 Harald Sitter <sitter@kde.org>
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

require 'aptly'
require 'logger'
require 'logger/colors'

require_relative '../../ci-tooling/lib/repo_abstraction'
require_relative 'cmake_dep_verify/package'
require_relative 'cmake_dep_verify/junit'

module Lint
  class CMakePackages
    attr_reader :repo

    def initialize(type, dist)
      @log = Logger.new(STDOUT)
      @log.level = Logger::INFO
      @log.progname = self.class.to_s
      @type = type
      aptly_repo = Aptly::Repository.get("#{type}_#{dist}")
      @repo = ChangesSourceFilterAptlyRepository.new(aptly_repo, @type)
      @package_results = {}
    end

    def run
      repo.add || raise
      # Call actual code for missing detection.
      run_internal
      write
    ensure
      repo.remove
    end

    private

    def write
      puts 'Writing...'
      @package_results.each do |package, cmake_package_results|
        suite = CMakeDepVerify::JUnit::Suite.new(package, cmake_package_results)
        puts "Writing #{package}.xml"
        File.write("#{package}.xml", suite.to_xml)
      end
    end

    def run_internal
      repo.binaries.each do |package, version|
        next if package.end_with?('-dbg', '-dbgsym', '-data', '-bin', '-common', '-udeb')
        pkg = CMakeDepVerify::Package.new(package, version)
        @log.info "Checking #{package}: #{version}"
        @package_results[package] = pkg.test
      end
    end
  end
end
