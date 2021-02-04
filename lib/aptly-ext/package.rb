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

require 'addressable/uri'
require 'aptly/representation'

module Aptly
  module Ext
    # A Package respresentation.
    # TODO: should go into aptly once happy with API
    class Package < Representation
      # A package short key (key without uid)
      # e.g.
      # "Psource kactivities-kf5 5.18.0+git20160312.0713+15.10-0"
      class ShortKey
        attr_reader :architecture
        attr_reader :name
        attr_reader :version

        private

        def initialize(architecture:, name:, version:)
          @architecture = architecture
          @name = name
          @version = version
        end

        def to_s
          "P#{@architecture} #{@name} #{@version}"
        end
      end

      # A package key
      # e.g.
      # Psource kactivities-kf5 5.18.0+git20160312.0713+15.10-0 8ebad520d672f51c
      class Key < ShortKey
        # FIXME: maybe should be called hash?
        attr_reader :uid

        def self.from_string(str)
          match = REGEX.match(str)
          unless match
            raise ArgumentError,
                  "String doesn't appear to match our regex: #{str}"
          end
          kwords = Hash[match.names.map { |name| [name.to_sym, match[name]] }]
          new(**kwords)
        end

        def to_s
          "#{super} #{@uid}"
        end

        # TODO: maybe to_package? should be in base one presumes?

        private

        REGEX = /
          ^
          P(?<architecture>[^\s]+)
          \s
          (?<name>[^\s]+)
          \s
          (?<version>[^\s]+)
          \s
          (?<uid>[^\s]+)
          $
        /x

        def initialize(architecture:, name:, version:, uid:)
          super(architecture: architecture, name: name, version: version)
          @uid = uid
        end
      end

      class << self
        def get(key, connection = Connection.new)
          path = "/packages/#{key}"
          response = connection.send(:get, Addressable::URI.escape(path))
          o = new(connection, JSON.parse(response.body, symbolize_names: true))
          o.Key = key.is_a?(Key) ? key : Key.from_string(o.Key)
          o
        end
      end
    end
  end
end
