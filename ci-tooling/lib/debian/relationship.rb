# frozen_string_literal: true
#
# Copyright (C) 2015-2018 Harald Sitter <sitter@kde.org>
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
require_relative 'profile'

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

    # architecture restriction for package
    # [architecture restriction] https://www.debian.org/doc/debian-policy/ch-customized-programs.html#s-arch-spec
    attr_accessor :architectures

    # profile groups for a package
    # <build profile restriction> https://wiki.debian.org/BuildProfileSpec
    #
    # This is somewhat complicated stuff. One relationship may have one or more
    # ProfileGroup. A ProfileGroup is an AND relationship on one or more
    # Profile. e.g. `<nocheck !cross> <nocheck>` would result in an array of the
    # size 2. The 2 entires are each an instance of ProfileGroup. The
    # first group contains two Profiles, only if both eval to true the group
    # applies. The second group contains one Profile. For the most part, unless
    # you actualy want to know the involved profiles, you should only need to
    # talk to the ProfileGroup instances as groups always apply entirely.
    # Do note that the above example could also be split in two relationships
    # with each one ProfileGroup.
    # See the spec page for additional information.
    #
    # @return Array[ProfileGroup[Profile]]
    attr_accessor :profiles

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
         \s* (?<version>
              [^\)\s]+)              # do not attempt to parse version
         \s* \)                      # closing parenthesis
       )?                            # end of optional part
       (?:                           # start of optional architecture
         \s* \[                      # open bracket for architecture
         \s* (?<architectures>
              [^\]]+)                  # don't parse architectures now
         \s* \]                      # closing bracket
       )?                            # end of optional architecture
       (?<profiles>
         (?:                           # start of optional restriction
           \s* <                       # open bracket for restriction
           \s* ([^>]+)                    # do not parse restrictions now
           \s* >                       # closing bracket
         )+                            # end of optional restriction
       )?
       \s*$                          # trailing spaces at end
     /x

    def initialize(string)
      init_members_to_nil
      string = string.strip
      return if string.empty?

      match = string.match(REGEX)
      if match
        process_match(match)
      else
        @name = string
      end
    end

    # Checks if the Relationship's profiles make it applicable.
    # Note that a single string is generally assumed to be a Profile unless
    # it contains a space, in which case it will be split and treated as a Group
    # @param array_or_profile [ProfileGroup,Array<String>,Profile,String]
    def applicable_to_profile?(array_or_profile)
      group = array_or_profile
      group = ProfileGroup.new(group) unless group.is_a?(ProfileGroup)
      profiles_ = profiles || [ProfileGroup.new(nil)]
      profiles_.any? { |x| x.matches?(group) }
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
      output += f(' %s', @profiles&.map { |x| "<#{x}>" }&.join(' '))
      output
    end

    private

    def init_members_to_nil
      # ruby -w takes offense with us not always initializing everything
      # explicitly. Rightfully so. Make everything nil by default, so we know
      # fields are nil later on regardless of whether we were able to process
      # the input string.
      @name = nil
      @architecture = nil
      @operator = nil
      @version = nil
      @architectures = nil
      @profiles = nil
    end

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
        data&.strip!
        next unless data

        data = parse(name, data)
        instance_variable_set("@#{name}".to_sym, data)
      end
    end

    def parse(name, data)
      case name
      when 'architectures'
        ArchitectureQualifier.new(data)
      when 'profiles'
        parse_profiles(data)
      else
        data
      end
    end

    def parse_profiles(str)
      # str without leading and trailing <>
      str = str.gsub(/^\s*<\s*(.*)\s*>\s*/, '\1')
      # str split by >< inside (if any)
      rules = str.split(/\s*>\s+<\s*/)
      # Split by spaces and convert into groups
      rules.map { |x| ProfileGroup.new(x.split(' ')) }
    end
  end
end
