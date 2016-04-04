# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
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
  # A package relationship.
  class Relationship
    attr_reader :name
    attr_reader :operator
    attr_reader :version

    def initialize(string)
      @name = nil
      @operator = nil
      @version = nil

      string.strip!
      return if string.empty?

      # Fancy plain text description:
      # - Start of line
      # - any word character, at least once
      # - 0-n space characters
      # - at the most once:
      #  - (
      #  - any of the version operators, but only once
      #  - anything before closing ')'
      #  - )
      # Random note: all matches are stripped, so we don't need to
      #              handle whitespaces being in the matches.
      match = string.match(/^(\S+)\s*(\((<|<<|<=|=|>=|>>|>){1}(.*)\))?/)
      # 0 full match
      # 1 name
      # 2 version definition (or nil)
      # 3  operator
      # 4  version
      @name = match[1] ? match[1].strip : nil
      @operator = match[3] ? match[3].strip : nil
      @version = match[4] ? match[4].strip : nil
    end
  end
end
