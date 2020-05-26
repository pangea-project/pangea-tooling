# frozen_string_literal: true
#
# SPDX-FileCopyrightText: 2014-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/ci/upstream_scm'
require_relative 'lib/testcase'

require 'mocha/test_unit'

# Test ci/upstream_scm
class UpstreamSCMTest < TestCase
  def setup
    # Disable releaseme adjustments by default. To be overridden as needed.
    ReleaseMe::Project.stubs(:from_repo_url).returns([])
    ReleaseMe::Project.stubs(:from_find).returns([])
  end

  def teardown
    CI::UpstreamSCM::ProjectCache.reset!
  end

  def test_defaults
    scm = CI::UpstreamSCM.new('breeze-qt4', 'kubuntu_unstable', '/')
    assert_equal('git', scm.type)
    assert_equal('https://anongit.kde.org/breeze', scm.url)
    assert_equal('master', scm.branch)
  end

  def test_releasme_adjust
    ReleaseMe::Project.unstub(:from_repo_url)
    breeze = mock('breeze-qt4')
    breeze.stubs(:i18n_trunk).returns('master')
    breeze.stubs(:i18n_stable).returns('Plasma/5.10')
    vcs = mock('breeze-qt4-vcs')
    vcs.stubs(:repository).returns('https://invent.kde.org/breeze')
    breeze.stubs(:vcs).returns(vcs)
    ReleaseMe::Project.stubs(:from_repo_url).returns([breeze])

    scm = CI::UpstreamSCM.new('breeze-qt4', 'kubuntu_unstable', '/')
    assert_equal('git', scm.type)
    assert_equal('https://anongit.kde.org/breeze', scm.url)
    assert_equal('master', scm.branch)
    scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE)
    assert_equal('git', scm.type)
    assert_equal('https://invent.kde.org/breeze', scm.url)
    assert_equal('Plasma/5.10', scm.branch)
  end

  def test_releasme_adjust_uninteresting
    # Not changing non kde.org stuff.
    scm = CI::UpstreamSCM.new('breeze-qt4', 'kubuntu_unstable', '/')
    assert_equal('git', scm.type)
    assert_equal('https://anongit.kde.org/breeze', scm.url)
    assert_equal('master', scm.branch)
    scm.instance_variable_set(:@url, 'git://kittens')
    assert_nil(scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE))
    assert_equal('git', scm.type)
    assert_equal('git://kittens', scm.url)
    assert_equal('master', scm.branch)
  end

  def test_unknown_url
    # URL is on KDE but for some reason not in the projects. Should raise.
    ReleaseMe::Project.unstub(:from_repo_url)
    ReleaseMe::Project.stubs(:from_repo_url).returns([])
    scm = CI::UpstreamSCM.new('bububbreeze-qt4', 'kubuntu_unstable', '/')
    assert_raises do
      scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE)
    end
  end

  def test_preference_fallback
    # A special fake thing 'no-stable' should come back with master as no
    # stable branch is set.
    ReleaseMe::Project.unstub(:from_repo_url)
    proj = mock('project')
    proj.stubs(:i18n_trunk).returns(nil)
    proj.stubs(:i18n_stable).returns('supertrunk')
    vcs = mock('vcs')
    vcs.stubs(:repository).returns('https://invent.kde.org/no-stable')
    proj.stubs(:vcs).returns(vcs)
    ReleaseMe::Project.stubs(:from_repo_url).with('https://anongit.kde.org/no-stable').returns([proj])

    scm = CI::UpstreamSCM.new('no-stable', 'kubuntu_unstable', '/')
    scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE)
    assert_equal('supertrunk', scm.branch)
  end

  def test_preference_default
    # A special fake thing 'no-i18n' should come back with master as no
    # stable branch is set and no trunk branch is set, i.e. releaseme has no
    # data to give us.
    ReleaseMe::Project.unstub(:from_repo_url)
    proj = mock('project')
    proj.stubs(:i18n_trunk).returns(nil)
    proj.stubs(:i18n_stable).returns(nil)
    vcs = mock('vcs')
    vcs.stubs(:repository).returns('https://invent.kde.org/no-i18n')
    proj.stubs(:vcs).returns(vcs)
    ReleaseMe::Project.stubs(:from_repo_url).with('https://anongit.kde.org/no-i18n').returns([proj])

    scm = CI::UpstreamSCM.new('no-i18n', 'kubuntu_unstable', '/')
    scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE)
    assert_equal('master', scm.branch)
  end

  def test_releaseme_url_suffix
    # In overrides people sometimes use silly urls with a .git suffix, this
    # should still lead to correct adjustments regardless.
    ReleaseMe::Project.unstub(:from_repo_url)
    proj = mock('project')
    proj.stubs(:i18n_trunk).returns('master')
    proj.stubs(:i18n_stable).returns('Plasma/5.9')
    vcs = mock('vcs')
    vcs.stubs(:repository).returns('https://invent.kde.org/breeze')
    proj.stubs(:vcs).returns(vcs)
    ReleaseMe::Project.stubs(:from_repo_url).with('https://invent.kde.org/breeze').returns([proj])

    scm = CI::UpstreamSCM.new('breeze-qt4', 'kubuntu_unstable', '/')
    scm.instance_variable_set(:@url, 'https://invent.kde.org/breeze.git')
    scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE)
    assert_equal('Plasma/5.9', scm.branch)
  end

  def test_releaseme_invent_transition
    # When moving to invent.kde.org the lookup tech gets slightly more involved
    # since we construct deterministic flat urls based on the packaging repo
    # name everything falls apart because invent urls are no longer
    # deterministically flat.
    # To mitigate we have fallback logic which tries to resolve based on
    # basename. This is fairly unreliable and only meant as a short term
    # measure. The final heuristics will have to gather more data sources to
    # try and determine the repo url.

    proj = mock('project')
    proj.stubs(:i18n_trunk).returns(nil)
    proj.stubs(:i18n_stable).returns(nil)
    vcs = mock('vcs')
    vcs.stubs(:repository).returns('https://invent.kde.org/plasma/drkonqi')
    proj.stubs(:vcs).returns(vcs)

    # primary request... fails to reoslve
    ReleaseMe::Project.unstub(:from_repo_url)
    ReleaseMe::Project.stubs(:from_repo_url).with('https://anongit.kde.org/drkonqi').returns([])

    # fallback request... succeeds
    ReleaseMe::Project.unstub(:from_find)
    ReleaseMe::Project.stubs(:from_find).with('drkonqi').returns([proj])

    scm = CI::UpstreamSCM.new('drkonqi', 'kubuntu_unstable', Dir.pwd)
    scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE)
    assert_equal('master', scm.branch)
    # url was also adjusted!
    assert_equal('https://invent.kde.org/plasma/drkonqi', scm.url)
  end

  def test_releasme_adjust_fail
    # anongit.kde.org must not be used and will raise!
    scm = CI::UpstreamSCM.new('breeze-qt4', 'kubuntu_unstable', '/')
    # fake that the skip over adjust somehow. this will make adjust noop
    # BUT run the internal assertion tech to prevent anongit!
    scm.stubs(:adjust?).returns(false)
    assert_raises do
      scm.releaseme_adjust!(CI::UpstreamSCM::Origin::STABLE)
    end
    assert_equal('https://anongit.kde.org/breeze', scm.url)
  end
end
