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

require_relative '../debian/version'
require_relative 'package'

module Aptly
  module Ext
    # Filter latest versions out of an enumerable of strings.
    module LatestVersionFilter
      module_function

      # @param array_of_package_keys [Array<String>]
      # @return [Array<Package::Key>]
      def filter(array_of_package_keys, keep_amount = 1)
        packages = array_of_package_keys.collect do |key|
          key.is_a?(Package::Key) ? key : Package::Key.from_string(key)
        end

        packages_by_name = packages.group_by(&:name)
        packages_by_name.collect do |_name, names_packages|
          versions = debian_versions(names_packages).sort.to_h
          versions.shift while versions.size > keep_amount
          versions.values
        end.flatten
      end

      # Group the keys in a Hash by their version. This is so we can easily
      # sort the versions.
      def debian_versions(names_packages)
        # Group the keys in a Hash by their version. This is so we can easily
        # sort the versions.
        versions = names_packages.group_by(&:version)
        # Pack them in a Debian::Version object for sorting
        Hash[versions.map { |k, v| [Debian::Version.new(k), v] }]
      end
    end
  end
end
