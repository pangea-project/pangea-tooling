# frozen_string_literal: true
#
# Copyright (C) 2016-2018 Harald Sitter <sitter@kde.org>
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

require_relative '../lib/ci/tarball'

module CI
  class TarballTest < TestCase
    def test_string
      s = File.absolute_path('d_1.0.orig.tar')
      t = Tarball.new(s)
      assert_equal(s, t.to_s)
      assert_equal(s, t.to_str)
      assert_equal(s, "#{t}") # coerce
    end

    def test_orig
      assert_false(Tarball.orig?('a-1.0.tar'))
      assert_false(Tarball.orig?('b_1.0.tar'))
      assert_false(Tarball.orig?('c-1.0.orig.tar'))
      assert(Tarball.orig?('d_1.0.orig.tar'))
      # More advanced but valid version with characters and a plus
      assert(Tarball.orig?('qtbase-opensource-src_5.5.1+dfsg.orig.tar.xz'))
    end

    def test_origify
      t = Tarball.new('d_1.0.orig.tar').origify
      assert_equal('d_1.0.orig.tar', File.basename(t.path))
      t = Tarball.new('a-1.0.tar').origify
      assert_equal('a_1.0.orig.tar', File.basename(t.path))

      # fail
      assert_raise RuntimeError do
        Tarball.new('a.tar').origify
      end
    end

    def test_extract
      t = Tarball.new(data('test-1.tar'))
      t.extract("#{Dir.pwd}/test-2")
      assert_path_exist('test-2')
      assert_path_exist('test-2/a')
      assert_path_not_exist('test-1')

      t = Tarball.new(data('test-flat.tar'))
      t.extract("#{Dir.pwd}/test-1")
      assert_path_exist('test-1')
      assert_path_exist('test-1/test-flat')
    end

    def test_extract_flat_hidden_things
      t = Tarball.new(data('test.tar'))

      t.extract("#{Dir.pwd}/test")

      assert_path_exist('test/.hidden-dir')
      assert_path_exist('test/.hidden-file')
      assert_path_exist('test/visible-file')
    end

    def test_copy
      FileUtils.cp_r(Dir["#{data}/*"], Dir.pwd)
      t = Tarball.new('test-1.tar.xz')
      assert_false(t.orig?)
      t.origify!
      assert_equal('test_1.orig.tar.xz', File.basename(t.path))
      assert_path_exist('test_1.orig.tar.xz')
    end

    def test_version
      t = Tarball.new('qtbase-opensource-src_5.5.1+dfsg.orig.tar.xz')
      assert_equal('5.5.1+dfsg', t.version)
    end

    def test_basename
      t = Tarball.new('qtbase-opensource-src_5.5.1+dfsg.orig.tar.xz')
      assert_equal('qtbase-opensource-src_5.5.1+dfsg.orig.tar.xz', t.basename)
    end

    def test_dsc_extract
      # dsc tarball should unpack via dsc so it includes everything
      DSCTarball.new(data('test_2.10.tar.gz'),
                     dsc: data('test_2.10.dsc')).extract('x')
      assert_path_exist('x/debian/control')
      assert_path_exist('x/debian/compat')
    end
  end
end
