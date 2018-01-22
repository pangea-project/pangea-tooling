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
require_relative '../nci/sourcer'

require 'mocha/test_unit'

class NCISourcerTest < TestCase
  def setup
    ENV['DIST'] = 'xenial'
    ENV['BUILD_NUMBER'] = '123'
  end

  def teardown
  end

  def test_run_fallback
    fake_builder = mock('fake_builder')
    fake_builder.stubs(:run)
    CI::VcsSourceBuilder.expects(:new).returns(fake_builder)
    # Runs fallback
    NCISourcer.run
  end

  def test_run_tarball
    Dir.mkdir('source')
    File.write('source/url', 'http://yolo')

    fake_tar = mock('fake_tar')
    fake_tar.stubs(:origify).returns(fake_tar)
    fake_fetcher = mock('fake_fetcher')
    fake_fetcher.stubs(:fetch).with('source').returns(fake_tar)
    CI::URLTarFetcher.expects(:new).with('http://yolo').returns(fake_fetcher)

    fake_builder = mock('fake_builder')
    fake_builder.stubs(:build)
    CI::OrigSourceBuilder.expects(:new).with(strip_symbols: true).returns(fake_builder)

    NCISourcer.run('tarball')
  end

  def test_run_uscan
    fake_tar = mock('fake_tar')
    fake_tar.stubs(:origify).returns(fake_tar)
    fake_fetcher = mock('fake_fetcher')
    fake_fetcher.stubs(:fetch).with('source').returns(fake_tar)
    CI::WatchTarFetcher.expects(:new).with('packaging/debian/watch', mangle_download: true).returns(fake_fetcher)

    fake_builder = mock('fake_builder')
    fake_builder.stubs(:build)
    CI::OrigSourceBuilder.expects(:new).with(strip_symbols: true).returns(fake_builder)

    NCISourcer.run('uscan')
  end

  def test_args
    assert_equal({:strip_symbols=>true}, NCISourcer.sourcer_args)
  end

  def test_settings_args
    NCI::Settings.expects(:for_job).returns(
      { 'sourcer' => { 'restricted_packaging_copy' => true } }
    )
    assert_equal({:strip_symbols=>true, :restricted_packaging_copy=>true},
                 NCISourcer.sourcer_args)
  end
end
