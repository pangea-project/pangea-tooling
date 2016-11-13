# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

require_relative 'lib/testcase'
require_relative '../nci/lib/appstreamer'
require_relative '../nci/lib/snap'

require 'mocha/test_unit'

module AppStream
  class Database
  end
end

class NCIAppStreamerTest < TestCase
  def setup
    GirFFI.stubs(:setup).with(:AppStream)
    @fake_db = mock('database')
    @fake_db.stubs(:open)
    AppStream::Database.stubs(:new).returns(@fake_db)
  end

  def test_no_component
    @fake_db.stubs(:component_by_id).returns(nil)

    fake_snap = Snap.new('fake', nil)
    a = AppStreamer.new('abc')
    a.expand(fake_snap)
    #assert_equal(fake_snap.summary, 'No appstream summary, needs bug filed')
    #assert_equal(fake_snap.description, 'No appstream description, needs bug filed')
    #assert_nil(a.icon_url)
  end

  def test_component
    fake_icon = mock('icon')
    fake_icon.stubs(:kind).returns(:cached)
    fake_icon.stubs(:url).returns('/kitteh.png')

    fake_comp = mock('component')
    fake_comp.stubs(:summary).returns('summary')
    fake_comp.stubs(:description).returns('description')
    fake_comp.stubs(:icons).returns([fake_icon])
    @fake_db.expects(:component_by_id).returns(fake_comp)

    fake_snap = Snap.new('fake', nil)
    a = AppStreamer.new('abc')
    a.expand(fake_snap)
  #  assert_equal(fake_snap.summary, 'summary')
  #  assert_equal(fake_snap.description, 'description')
  #  assert_equal(a.icon_url, '/kitteh.png')
  end
end
