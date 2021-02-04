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

module Debian
  # A build profile.
  class Profile
    attr_reader :name

    def initialize(name)
      @negated = name[0] == '!'
      @name = name.tr('!', '')
      @str = name
    end

    def negated?
      @negated
    end

    def to_s
      @str
    end

    def matches?(other)
      return other.to_s != name.to_s if negated?

      other.name == name
    end
  end

  # A profile group
  class ProfileGroup < Array
    def initialize(group_or_profile)
      # may be nil == empty group; useful for input applicability checks mostly
      return unless group_or_profile

      ary = [*group_or_profile]
      if group_or_profile.is_a?(String) && group_or_profile.include?(' ')
        ary = ary[0].split(' ')
      end
      super(ary.map { |x| x.is_a?(Profile) ? x : Profile.new(x) })
    end

    # Determine if an input Profile(Group) is applicable to this ProfileGroup
    # @param [Array, Profile] array_or_profile
    def matches?(array_or_profile)
      ary = [*array_or_profile]

      # A Group is an AND relationship between profiles, so all our Profiles
      # must match at least one search profile.
      # If we are 'cross nocheck' the input must have at least
      # 'cross' and 'nocheck'.
      all? do |profile|
        ary.any? { |check_profile| profile.matches?(check_profile) }
      end
    end

    def to_s
      join(' ')
    end
  end
end
