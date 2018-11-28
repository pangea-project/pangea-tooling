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

module NCI
  module Snap
    # Splits a snapcraft channel definition string into its components.
    # e.g. kde-frameworks-5-core18-sdk/latest/edge
    # https://docs.snapcraft.io/channels/551
    class Identifier
      attr_reader :name
      attr_reader :track
      attr_reader :risk
      attr_reader :branch

      def initialize(str)
        @str = str
        @name, @track, @risk, @branch = str.split('/')
        @track ||= 'latest'
        @risk ||= 'stable'
        @branch ||= nil
        validate!
      end

      def validate!
        # We run the channel definition through `snap download` which only
        # supports a subset of the channel definition aspects in snapcraft.
        # We therefore need to assert that the channel definiton is in fact
        # something we can deal with, which basically amounts to nothing
        # other than risk must specified.

        # Mustn't be empty
        raise "Failed to parse build-snap #{@str}" unless name
        # Mustn't be anything but latest
        unless track == 'latest'
          raise "Unsupported track #{track} (via #{@str})"
        end
        # Mustn't be nil
        raise "Unsupported risk #{risk} (via #{@str})" unless risk
        # Must be nil
        raise "Unsupported branch #{branch} (via #{@str})" unless branch.nil?
      end
    end
  end
end
