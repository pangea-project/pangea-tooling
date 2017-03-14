# frozen_string_literal: true
#
# Copyright (C) 2014-2017 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/ci/upstream_scm'
require_relative 'lib/testcase'

# Test ci/upstream_scm
class UpstreamSCMTest < TestCase
  def test_defaults
    scm = CI::UpstreamSCM.new('breeze-qt4', 'kubuntu_unstable', '/')
    assert_equal('git', scm.type)
    assert_equal('git://anongit.kde.org/breeze', scm.url)
    assert_equal('master', scm.branch)
  end

  def test_releasme_adjust
    scm = CI::UpstreamSCM.new('breeze-qt4', 'kubuntu_unstable', '/')
    assert_equal('git', scm.type)
    assert_equal('git://anongit.kde.org/breeze', scm.url)
    assert_equal('master', scm.branch)
    scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE)
    assert_equal('git', scm.type)
    assert_equal('git://anongit.kde.org/breeze', scm.url)
    assert_equal('Plasma/5.9', scm.branch)
  end

  def test_releasme_adjust_uninteresting
    # Not changing non kde.org stuff.
    scm = CI::UpstreamSCM.new('breeze-qt4', 'kubuntu_unstable', '/')
    assert_equal('git', scm.type)
    assert_equal('git://anongit.kde.org/breeze', scm.url)
    assert_equal('master', scm.branch)
    scm.instance_variable_set(:@url, 'git://kittens')
    assert_nil(scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE))
    assert_equal('git', scm.type)
    assert_equal('git://kittens', scm.url)
    assert_equal('master', scm.branch)
  end
end
