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

require 'json'

module NCI
  module DebianMerge
    # Merge data wrapper
    class Data
      class << self
        def from_file
          new(JSON.parse(File.read('data.json')))
        end
      end

      def initialize(data)
        @data = data
      end

      # @return String e.g. 'debian/5.25' as the tag base to look for
      def tag_base
        @data.fetch('tag_base')
      end

      # @return Array<String> array of repo urls to work with.
      def repos
        @data.fetch('repos')
      end
    end
  end
end
