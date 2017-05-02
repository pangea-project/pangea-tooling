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

require 'logger'
require 'logger/colors'

require_relative 'qml_dep_verify/aptly'
require_relative 'qml_dep_verify/package'

# A QML dependency verifier. It verifies by installing each built package
# and verifying the deps of the installed qml files are met.
# This depends on Launchpad at the time of writing.
class QMLDependencyVerifier
  attr_reader :repo

  def initialize(repo)
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
    @log.progname = self.class.to_s
    @repo = repo
  end

  def missing_modules
    repo.add || raise
    # Call actual code for missing detection.
    missing_modules_internal
  ensure
    repo.remove
  end

  private

  def missing_modules_internal
    missing_modules = {}
    repo.binaries.each do |package, version|
      next if package.end_with?('-dbg', '-dbgsym', '-dev')
      pkg = QMLDepVerify::Package.new(package, version)
      @log.info "Checking #{package}: #{version}"
      next if pkg.missing.empty?
      missing_modules[package] = pkg.missing
    end
    @log.info "Done looking for missing modules\n#{missing_modules}"
    missing_modules
  end
end
