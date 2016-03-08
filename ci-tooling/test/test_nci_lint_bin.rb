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

class NCILintBinTest < TestCase
  def setup
    ENV['BUILD_URL'] = '/'
  end

  def teardown
    ENV.delete('BUILD_URL')
  end

  def run!
    `ruby #{__dir__}/../nci/lint_bin.rb 2> /dev/stdout`
  end

  description 'fail to run on account of no url file'
  def test_fail
    output = run!

    assert_not_equal(0, $?.to_i, output)
    assert_path_not_exist('reports')
  end

  description 'should work with a good url'
  def test_run
    ENV['BUILD_URL'] = data
    File.write('build_url', data)

    FileUtils.mkpath('build') # Dump a fake debian in.
    FileUtils.cp_r("#{@datadir}/debian", "#{Dir.pwd}/build")

    output = run!

    assert_equal(0, $?.to_i, output)
    assert_path_exist('reports')
    Dir.glob("#{data('reports')}/*").each do |r|
      assert_path_exist("reports/#{File.basename(r)}")
    end
  end
end
