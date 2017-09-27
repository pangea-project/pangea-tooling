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

# A Shebang validity parser.
class Shebang
  attr_reader :valid
  attr_reader :parser

  def initialize(line)
    @valid = false
    @parser = nil
    @line = line
    parse
  end

  private

  def proper_line?
    return false unless @line&.start_with?('#!')
    true
  end

  def parse
    return unless proper_line?

    parts = @line.split(' ')
    return unless parts.size >= 1 # shouldn't even happen as parts is always 1
    return unless valid_parts?(parts)

    @valid = true
  end

  def valid_parts?(parts)
    if parts[0].end_with?('/env')
      return false unless parts.size >= 2
      @parser = parts[1]
    elsif !parts[0].include?('/') || parts[0].end_with?('/')
      return false # invalid
    else
      @parser = parts[0].split('/').pop
    end
    true
  end
end
