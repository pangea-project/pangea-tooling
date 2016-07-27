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
require_relative '../nci/lib/snap'

require 'mocha/test_unit'

class NCISnapTest < TestCase
  def setup
  end

  def test_app
    a = Snap::App.new('yolo')
    assert_equal(a.name, 'yolo')
  end

  def test_to_yaml
    assert_equal("---\nyolo:\n  command: qt5-launch usr/bin/yolo\n  plugs:\n  - x11\n  - unity7\n  - home\n  - opengl\n",
                 Snap::App.new('yolo').to_yaml)
  end

  def test_snap_write
    s = Snap.new('name', nil)
    s.stagedepends = ['stagedep']
    s.apps = [Snap::App.new('yolo')]
    ref_yaml = YAML.load(File.read(data))
    rend_yaml = YAML.load(s.render)
    assert_equal(ref_yaml, rend_yaml)
  end

  def test_snap_dupes
    s = Snap.new('name', nil)
    s.stagedepends = ['stagedep', 'stagedep']
    s.apps = [Snap::App.new('yolo')]
    rend_yaml = YAML.load(s.render)
    assert_equal(["name", "stagedep"],
                 rend_yaml['parts']['name']['stage-packages'])
  end

  def test_minimal_render
    s = Snap.new('meow', '2.0')
    s.render # mustn't raise
  end
end
