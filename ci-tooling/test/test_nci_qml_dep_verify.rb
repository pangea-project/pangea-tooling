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
require_relative '../lib/qml_dependency_verifier'

require_relative '../nci/lib/lint/qml'

require 'mocha/test_unit'

class NCIQMLDepVerifyTest < TestCase
  def setup
    Object.any_instance.expects(:system).never
    Object.any_instance.expects(:`).never

    # Apt::Repository.send(:reset)
    # # Disable automatic update
    # Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)

    # We'll temporary mark packages as !auto, mock this entire thing as we'll
    # not need this for testing.
    Apt::Mark.stubs(:tmpmark).yields
  end

  def test_dis
    # Write a fake dsc, we'll later intercept the unpack call.
    File.write('yolo.dsc', '')
    FileUtils.cp_r("#{data}/.", Dir.pwd, verbose: true)
    Apt.stubs(:install).returns(true)
    Apt.stubs(:update).returns(true)
    Apt.stubs(:purge).returns(true)
    Apt::Get.stubs(:autoremove).returns(true)
    DPKG.stubs(:list).returns([])
    Object.any_instance.stubs(:`).with('dpkg-architecture -qDEB_HOST_ARCH').returns('amd64')

    fake_repo = mock('repo')
    # FIXME: require missing
    # fake_repo.responds_like_instance_of(Aptly::Repository)

    fake_repo
      .stubs(:packages)
      .with(q: 'kcoreaddons (= 5.21.0-0neon) {source}')
      .returns(['Psource kcoreaddons 5.21.0-0neon abc'])
    fake_repo
      .stubs(:packages)
      .with(q: '!$Architecture (source), $Source (kcoreaddons), $SourceVersion (5.21.0-0neon)')
      .returns(['Pamd64 libkf5coreaddons-bin-dev 5.21.0-0neon abc',
                'Pall libkf5coreaddons-data 5.21.0-0neon abc',
                'Pamd64 libkf5coreaddons-dev 5.21.0-0neon abc',
                'Pamd64 libkf5coreaddons5 5.21.0-0neon abc'])

    Aptly::Repository.expects(:get).with('trollus_maximus').returns(fake_repo)

    fake_apt_repo = mock('apt_repo')
    fake_apt_repo.stubs(:add).returns(true)
    fake_apt_repo.stubs(:remove).returns(true)
    Apt::Repository.expects(:new)
                   .with('http://archive.neon.kde.org/trollus')
                   .returns(fake_apt_repo)
                   .at_least_once

    DPKG.expects(:list).with('libkf5coreaddons-data')
        .returns(["#{Dir.pwd}/main.qml"])
    # Does a static check only. We'll let it fail.
    QML::Module.any_instance.expects(:system)
               .with('dpkg -s plasma-framework 2>&1 > /dev/null')
               .returns(false)

    Lint::QML.any_instance.expects(:system).with('dpkg-source', '-x', 'yolo.dsc', 'packaging').returns(true)

    # v = QMLDependencyVerifier.new(QMLDependencyVerifier::AptlyRepository.new(fake_repo, 'unstable'))
    # missing = v.missing_modules
    # assert_not_empty(missing)

    Lint::QML.new('trollus', 'maximus').lint
    assert_path_exist('junit.xml')
  end

  # Detect when the packaging/* has no qml files inside and skip the entire
  # madness.
  def test_skip
    File.write('yolo.dsc', '')
    Lint::QML.any_instance.expects(:system).with('dpkg-source', '-x', 'yolo.dsc', 'packaging').returns(true)
    Lint::QML.new('trollus', 'maximus').lint
    # Nothing should have happened.
    assert_path_not_exist('junit.xml')
  end
end
