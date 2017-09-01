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
    # Simple slave helper. Helps translating slave namaes to CPU core counts.
    class Slave
      # This is the input cores! Depending on the node name we'll determine how
      # many cores the build used.
      PREFIX_TO_CORES = {
        'jenkins-do-2core.' => 2,
        'jenkins-do-4core.' => 4,
        'jenkins-do-8core.' => 8,
        'jenkins-do-12core.' => 12,
        'jenkins-do-16core.' => 16,
        'jenkins-do-20core.' => 20,
        # High CPU - these are used as drop in replacements with 'off' core
        # count but semi reasonable disk space.
        'jenkins-do-c.8core.' => 4,
        'jenkins-do-c.16core.' => 8,
        'jenkins-do-c.32core.' => 8,
        # Compat
        'do-builder' => 2,
        'persistent.do-builder' => 2,
        'do-' => 2,
        '46.' => 2
      }.freeze

      # Translates a slave name to a core count.
      def self.cores(name)
        PREFIX_TO_CORES.each do |prefix, value|
          return value if name.start_with?(prefix)
        end
        raise "unknown slave type of #{name}"
      end
    end
  end
end
