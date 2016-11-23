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

require_relative 'architecturequalifier'

module Debian
  # A package relationship.
  class Relationship
    # Name of the package related to
    attr_reader :name
    # Architecture qualification of the package (foo:amd64)
    attr_accessor :architecture
    # Version relationship operator (>=, << etc.)re
    attr_accessor :operator
    # Related to version of the named package
    attr_accessor :version
    # Next OR'd dep if any
    attr_accessor :next

    # architecture restriction for package
    # [architecture restriction] https://www.debian.org/doc/debian-policy/ch-customized-programs.html#s-arch-spec
    attr_accessor :architectures

    # Not public because not needed for now.
    # <build profile restriction> https://wiki.debian.org/BuildProfileSpec
    # attr_accessor :profiles

    # Borrowed from Deps.pm. Added capture group names:
    #   [name, architecture, operator, architectures, restrictions]
    REGEX = /
      ^\s*                           # skip leading whitespace
       (?<name>
        [a-zA-Z0-9][a-zA-Z0-9+.-]*)  # package name
       (?:                           # start of optional part
         :                           # colon for architecture
         (?<architecture>
          [a-zA-Z0-9][a-zA-Z0-9-]*)  # architecture name
       )?                            # end of optional part
       (?:                           # start of optional part
         \s* \(                      # open parenthesis for version part
         \s* (?<operator>
              <<|<=|=|>=|>>|[<>])    # relation part
         \s* (?<version>.*?)         # do not attempt to parse version
         \s* \)                      # closing parenthesis
       )?                            # end of optional part
       (?:                           # start of optional architecture
         \s* \[                      # open bracket for architecture
         \s* (?<architectures>
              .*?)                   # don't parse architectures now
         \s* \]                      # closing bracket
       )?                            # end of optional architecture
       (?:                           # start of optional restriction
         \s* <                       # open bracket for restriction
         \s* (?<profiles>
              .*)                    # do not parse restrictions now
         \s* >                       # closing bracket
       )?                            # end of optional restriction
       \s*$                          # trailing spaces at end
     /x

    def initialize(string)
      string = string.strip
      return if string.empty?

      first, everything_else = string.split('|', 2)

      @next = Debian::Relationship.new(everything_else) if everything_else

      match = first.match(REGEX)
      if match
        process_match(match)
      else
        @name = string
      end
    end

    def substvar?
      @name.start_with?('${') && @name.end_with?('}')
    end

    def <=>(other)
      if substvar? || other.substvar? # any is a substvar
        return -1 unless other.substvar? # substvar always looses
        return 1 unless substvar? # non-substvar always wins
        return substvarcmp(other) # substvars are compared among themself
      end
      @name <=> other.name
    end

    def to_s
      output = @name
      output += f(':%s', @architecture)
      output += f(' (%s %s)', @operator, @version)
      output += f(' [%s]', @architectures)
      output += f(' <%s>', @profiles)
      output += f(' | %s', @next) if @next
      output
    end

    private

    def substvarcmp(other)
      ours = @name.gsub('${', '').tr('}', '')
      theirs = other.name.gsub('${', '').tr('}', '')
      ours <=> theirs
    end

    def f(str, *params)
      return '' if params.any?(&:nil?)
      format(str, *params)
    end

    def process_match(match)
      match.names.each do |name|
        data = match[name]
        data.strip! if data
        next unless data
        data = ArchitectureQualifier.new(data) if name == 'architectures'
        instance_variable_set("@#{name}".to_sym, data)
      end
    end
  end
end
