# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../lib/ci/overrides'
require_relative '../lib/ci/scm'
require_relative 'lib/testcase'

# Test ci/overrides
module CI
  class OverridesTest < TestCase
    def setup
      CI::Overrides.default_files = [] # Disable overrides by default.
    end

    def teardown
      CI::Overrides.default_files = nil # Reset
    end

    def test_pattern_match
      # FIXME: this uses live data
      o = Overrides.new([data('o1.yaml')])
      scm = SCM.new('git', 'git://packaging.neon.kde.org.uk/plasma/kitten', 'kubuntu_stable')
      overrides = o.rules_for_scm(scm)
      refute_nil overrides
      assert_equal({"upstream_scm"=>{"branch"=>"Plasma/5.5"}}, overrides)
    end

    def test_cascading
      o = Overrides.new([data('o1.yaml'), data('o2.yaml')])
      scm = SCM.new('git', 'git://packaging.neon.kde.org.uk/plasma/kitten', 'kubuntu_stable')

      overrides = o.rules_for_scm(scm)

      refute_nil overrides
      assert_equal({"packaging_scm"=>{"branch"=>"yolo"}, "upstream_scm"=>{"branch"=>"kitten"}},
                   overrides)
    end

    def test_cascading_reverse
      o = Overrides.new([data('o2.yaml'), data('o1.yaml')])
      scm = SCM.new('git', 'git://packaging.neon.kde.org.uk/plasma/kitten', 'kubuntu_stable')

      overrides = o.rules_for_scm(scm)

      refute_nil overrides
      assert_equal({"packaging_scm"=>{"branch"=>"kitten"}, "upstream_scm"=>{"branch"=>"kitten"}},
                   overrides)
    end

    def test_specific_overrides_generic
      o = Overrides.new([data('o1.yaml')])
      scm = SCM.new('git', 'git://packaging.neon.kde.org.uk/qt/qt5webkit', 'kubuntu_vivid_mobile')

      overrides = o.rules_for_scm(scm)

      refute_nil overrides
      expected = {
        'upstream_scm' => {
          'branch' => nil,
          'type' => 'tarball',
          'url' => 'http://http.debian.net/qtwebkit.tar.xz'
        }
      }
      assert_equal(expected, overrides)
    end

    def test_branchless_scm
      o = Overrides.new([data('o1.yaml')])
      scm = SCM.new('bzr', 'lp:fishy', nil)

      overrides = o.rules_for_scm(scm)

      refute_nil overrides
      expected = {
        'upstream_scm' => {
          'url' => 'http://meow.git'
        }
      }
      assert_equal(expected, overrides)
    end

    def test_nil_upstream_scm
      # standalone deep_merge would overwrite properties set to nil explicitly, but
      # we want them preserved!
      o = Overrides.new([data('o1.yaml')])
      scm = SCM.new('git', 'git://packaging.neon.kde.org.uk/qt/qt5webkit', 'test_nil_upstream_scm')

      overrides = o.rules_for_scm(scm)

      refute_nil overrides
      expected = {
        'upstream_scm' => nil
      }
      assert_equal(expected, overrides)
    end

    def test_scm_with_pointgit_suffix
      # make sure things work when .git is involved. we must have urls with .git
      # for gitlab instances.
      o = Overrides.new([data('o1.yaml')])
      scm = SCM.new('git', 'git://packaging.neon.kde.org.uk/qt/qt5webkit.git', 'kubuntu_vivid_mobile')

      overrides = o.rules_for_scm(scm)

      refute_nil overrides
      expected = {
        'upstream_scm' => {
          'branch' => nil,
          'type' => 'tarball',
          'url' => 'http://http.debian.net/qtwebkit.tar.xz'
        }
      }
      assert_equal(expected, overrides)
    end
  end
end
