# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require 'net/sftp'
require 'tty/command'

require_relative '../nci/imager_img_push_support.rb'

# NB: this test wraps a script, it does not formally contribute to coverage
#   statistics but is better than no testing. the script should be turned
#   into a module with a run so we can require it without running it so we can
#   avoid the fork.
module NCI
  class ImagerImgPushSupportTest < TestCase
    def test_old_directories_to_remove
      img_directories = ['current', '20190218-1206', '20180319-1110']
      img_directories = old_directories_to_remove(img_directories)
      assert_equal([], img_directories)

      img_directories = ['current', '20190218-1206', '20180319-1110', '20180319-1112']
      img_directories = old_directories_to_remove(img_directories)
      assert_equal([], img_directories)

      img_directories = ['current', '20190218-1206', '20180319-1110', '20180218-1210', '20180319-1112', '20180218-1255', '20180319-1155']
      img_directories = old_directories_to_remove(img_directories)
      assert_equal(["20180218-1210", "20180218-1255", "20180319-1110"], img_directories)
    end
  end
end
