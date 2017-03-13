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

require_relative '../ci-tooling/test/lib/testcase'

require_relative '../lib/jenkins/timestamp'

require 'mocha/test_unit'

module Jenkins
  class TimestampTest < TestCase
    def test_time
      utime = '1488887711165'
      time = Jenkins::Timestamp.time(utime)
      assert_equal([11, 55, 11, 7, 3, 2017, 2, 66, false, 'UTC'], time.utc.to_a)
      # Make sure we have preserved full precision. Jenkins timestamps have
      # microsecond precision, we rational them by /1000 for Time.at. The
      # precision should still be passed into the Time object though.
      assert_equal(165_000, time.usec)
    end

    def test_date
      utime = '1488887711165'
      assert_equal('2017-03-07', Jenkins::Timestamp.date(utime).to_s)
    end
  end
end
