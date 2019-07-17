# frozen_string_literal: true
#
# Copyright (C) 2019 Harald Sitter <sitter@kde.org>
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

class Violation
  attr_reader :name

  def to_s
    raise 'not implemented'
  end
end

class MissingPackageViolation < Violation
  def initialize(name, corrections)
    @name = name
    @corrections = corrections
  end

  def to_s
    s = "The source #{@name} appears not available in our repo!"
    if @corrections && !@corrections.empty?
      if @corrections&.size == 1
        s += "\nLooks like this needs a map (double check this!!!):"
        s += "\n  '#{@corrections[0]}' => '#{@name}',"
      else
        s += "\n  Did you mean?\n         #{@corrections.join("\n         ")}"
      end
    end
    s
  end
end

class WrongVersionViolation < Violation
  def initialize(name, expected, found)
    @name = name
    @expected = expected
    @found = found
  end

  def to_s
    "Version for #{@name} found '#{@found}' but expected '#{@expected}'!"
  end
end
