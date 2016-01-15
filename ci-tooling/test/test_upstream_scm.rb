require_relative '../lib/ci/upstream_scm'
require_relative 'lib/testcase'

# Test ci/upstream_scm
class UpstreamSCMTest < TestCase
  def test_defaults
    scm = UpstreamSCM.new('breeze-qt4', 'kubuntu_unstable', '/')
    assert_equal('git', scm.type)
    assert_equal('git://anongit.kde.org/breeze', scm.url)
    assert_equal('master', scm.branch)
  end

  # FIXME: this currenctly tests live config because upstream_scm has no way
  # to override the global config
  def test_global_override
    base = 'git.debian.org:/git/pkg-kde'
    workspace = "#{base}/plasma/plasma-workspace"
    wallpapers = "#{base}/yolo/kittens"
    qt = "#{base}/qt/qtbase"
    scm = UpstreamSCM.new(workspace, 'kubuntu_stable', '/')
    assert_equal('Plasma/5.5', scm.branch)
    scm = UpstreamSCM.new(workspace, 'kubuntu_unstable', '/')
    assert_equal('master', scm.branch)
    scm = UpstreamSCM.new(qt, 'kubuntu_unstable', '/')
    assert_equal('5.4', scm.branch)
    assert_equal('http://code.qt.io/git/qt/qtbase.git', scm.url)
    # Wallpapers is in SVN, make sure the SVN override works as expected.
    # This should implicitly test sorting as well as the specific wallpaper rule
    # is written after the generic plasma rule.
    scm = UpstreamSCM.new(wallpapers, 'kubuntu_unstable', '/')
    assert_equal('svn', scm.type)
    assert_equal('svn://anonsvn.kde.org/home/kde/trunk/KDE/plasma-workspace-wallpapers', scm.url)
  end

  def test_override
    scm = UpstreamSCM.new('trololo', 'kubuntu_unstable', data)
    assert_equal('git2', scm.type)
    assert_equal('urlolo', scm.url)
    assert_equal('brunch', scm.branch)
  end

  def test_override_branch_only
    # Make sure defaults fall through correctly. If only branch is overridden
    # the rest should use the default values.
    scm = UpstreamSCM.new('trololo', 'kubuntu_unstable', data)
    assert_equal('git', scm.type)
    assert_equal('git://anongit.kde.org/trololo', scm.url)
    assert_equal('brunch', scm.branch)
  end
end
