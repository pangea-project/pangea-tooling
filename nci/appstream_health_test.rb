#!/usr/bin/env ruby
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

require 'minitest/test'
require 'open-uri'

# Tests dep11 data being there
class DEP11Test < Minitest::Test
  SERIES = 'xenial'
  POCKETS = %w[main].freeze

  IN_RELEASES = {
    'user' =>
      "https://archive.neon.kde.org/user/dists/#{SERIES}/InRelease",
    'user_lts' =>
      "https://archive.neon.kde.org/user/lts/dists/#{SERIES}/InRelease"
  }.freeze

  IN_RELEASES.each do |name, in_release_uri|
    define_method("test_#{name}") do
      wanted_pockets = POCKETS.dup
      open(in_release_uri) do |f|
        f.each_line do |line|
          pocket = wanted_pockets.find { |x| line.include?("#{x}/dep11") }
          next unless pocket
          wanted_pockets.delete(pocket)
        end
      end
      assert_equal([], wanted_pockets,
                   'Some pockets are in need of dep11 data.')
    end
  end
end

require 'minitest/autorun' if $PROGRAM_NAME == __FILE__
