# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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
  module JenkinsBin
    # CPU Core helper. Implementing simple logic to upgrade/downgrade core count
    class Cores
      # This controls the output cores! Raising the cap here directly results in
      # larger machines getting assigned if necessary.
      CORES = [2, 4, 8].freeze

      def self.downgrade(cores)
        # Get either 0 or whatever is one below the input.
        new_cores_idx = [0, CORES.index(cores) - 1].max
        CORES[new_cores_idx]
      end

      def self.upgrade(cores)
        # Get either -1 or whatever is one above the input.
        new_cores_idx = [CORES.size - 1, CORES.index(cores) + 1].min
        CORES[new_cores_idx]
      end

      def self.know?(cores)
        CORES.include?(cores)
      end

      # Given any core count we'll coerce it into a known core count with
      # the smallest possible diff. Assuming two options the worse will be
      # picked to allow for upgrades which happen more reliably than downgrades
      # through automatic scoring.
      def self.coerce(cores)
        pick = nil
        diff = nil
        CORES.each do |c|
          new_diff = c - cores
          # Skip if absolute diff is worse than the diff we have
          next if diff && new_diff.abs > diff.abs
          # If the diff is equal pick the lower value. It will get upgraded
          # eventually if it is too low.
          next if diff && diff.abs == new_diff.abs && c > pick
          pick = c
          diff = new_diff
        end
        pick
      end
    end
  end
end
