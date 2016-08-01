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
require_relative '../dpkg'
require_relative '../qml/ignore_rule'
require_relative '../qml/module'
require_relative '../qml/static_map'

module QMLDepVerify
  # Wrapper around a package we want to test.
  class Package
    attr_reader :package # FIXME: change to name
    attr_reader :version

    def initialize(name, version)
      @package = name
      @version = version
    end

    def missing
      @missing ||= begin
        ignores = QML::IgnoreRule.read("packaging/debian/#{package}.qml-ignore")
        p modules
        missing = modules.reject do |mod|
          ignores.include?(mod) || mod.installed?
        end
        raise "failed to purge #{package}" unless Apt.purge(package)
        # We do not autoremove here, because chances are that the next package
        # will need much of the same deps, so we can speed things up a bit by
        # delaying the autoremove until after the next package is installed.
        missing
      end
    end

    private

    def files
      # FIXME: need to fail otherwise, the results will be skewed
      Apt.install("#{package}=#{version}")
      Apt::Get.autoremove(args: '--purge')

      DPKG.list(package).select { |f| File.extname(f) == '.qml' }
    end

    def modules
      @modules ||= files.collect do |file|
        QML::Module.read_file(file)
      end.flatten
    end
  end
end
