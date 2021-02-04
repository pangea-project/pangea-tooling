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
require_relative '../lib/ci/deb822_lister'

require 'mocha/test_unit'

module CI
  class Deb822ListerTest < TestCase
    def setup
      Digest::Class.expects(:hexdigest).never
    end

    def test_changes
      digest_seq = sequence('digests')
      Digest::SHA256
        .expects(:hexdigest)
        .in_sequence(digest_seq)
        .returns('e4e5cdbd2e3a89b8850d2aef5011d92679546bd4d65014fb0f016ff6109cd3d3')
      Digest::SHA256
        .expects(:hexdigest)
        .in_sequence(digest_seq)
        .returns('af3e1908e68d22e5fd99bd4cb4cf5561801a7e90e8f0000ec3c211c88bd5e09e')

      files = Deb822Lister.files_to_upload_for("#{data}/file.changes")
      assert_equal(2, files.size)
      assert_equal(["#{data}/libkf5i18n-data_5.21.0+p16.04+git20160418.1009-0_all.deb",
                    "#{data}/libkf5i18n-dev_5.21.0+p16.04+git20160418.1009-0_amd64.deb"],
                   files)
    end

    def test_dsc
      digest_seq = sequence('digests')
      Digest::SHA256
        .expects(:hexdigest)
        .in_sequence(digest_seq)
        .returns('4a4d22f395573c3747caa50798dcdf816ae0ca620acf02b961c1239c94746232')
      Digest::SHA256
        .expects(:hexdigest)
        .in_sequence(digest_seq)
        .returns('51c5f6d895d2ef1ee9ecd35f2e0f76c908c4a13fa71585c135bfe456f337f72c')

      files = Deb822Lister.files_to_upload_for("#{data}/file.changes")
      assert_equal(3, files.size)
      assert_equal(["#{data}/ki18n_5.21.0+p16.04+git20160418.1009.orig.tar.xz",
                    "#{data}/ki18n_5.21.0+p16.04+git20160418.1009-0.debian.tar.xz",
                    "#{data}/ki18n_5.21.0+p16.04+git20160418.1009-0.dsc"],
                   files)
    end
  end
end
