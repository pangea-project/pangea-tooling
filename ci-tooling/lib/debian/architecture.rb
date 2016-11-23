# frozen_string_literal: true
#
# Copyright (C) 2016 Rohan Garg <rohan@garg.io>
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

module Debian
  # A class to represent a debian architecture
  class Architecture
    attr_accessor :arch

    def initialize(arch)
      @arch = arch.delete('!')
      @negated = arch.start_with?('!')
    end

    def negated?
      @negated
    end

    def qualify?(other)
      other = Architecture.new(other) if other.is_a?(String)
      success = system('dpkg-architecture', '-a', "#{@arch}",
                       '-i', "#{other.arch}", '-f')
      other.negated? ^ negated? ? !success : success
    end

    def to_s
      negated? ? "!#{@arch}" : @arch
    end
  end
end
