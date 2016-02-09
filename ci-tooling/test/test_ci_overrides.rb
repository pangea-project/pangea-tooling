# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

# frozen_string_literal: true

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

    def test_definitive_match
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
      pend('needs test impl. applications/* should have override and applications/yolo should override the override but otherwise cascade')
    end
  end
end
