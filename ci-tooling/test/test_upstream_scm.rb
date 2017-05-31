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

  def test_unknown_url
    # URL is on KDE but for some reason not in the projects. Should raise.
    scm = CI::UpstreamSCM.new('bububbreeze-qt4', 'kubuntu_unstable', '/')
    assert_raises do
      scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE)
    end
  end

  def test_preference_fallback
    # A special fake thing 'no-stable' should come back with master as no
    # stable branch is set.
    scm = CI::UpstreamSCM.new('no-stable', 'kubuntu_unstable', '/')
    scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE)
    assert_equal('supertrunk', scm.branch)
  end

  def test_preference_default
    # A special fake thing 'no-i18n' should come back with master as no
    # stable branch is set and no trunk branch is set, i.e. releaseme has no
    # data to give us.
    scm = CI::UpstreamSCM.new('no-i18n', 'kubuntu_unstable', '/')
    scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE)
    assert_equal('master', scm.branch)
  end

  def test_releaseme_url_suffix
    # In overrides people sometimes use silly urls with a .git suffix, this
    # should still lead to correct adjustments regardless.
    scm = CI::UpstreamSCM.new('breeze-qt4', 'kubuntu_unstable', '/')
    scm.instance_variable_set(:@url, 'git://anongit.kde.org/breeze.git')
    scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE)
    assert_equal('Plasma/5.9', scm.branch)
  end
end
