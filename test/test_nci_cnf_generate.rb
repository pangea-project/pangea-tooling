# frozen_string_literal: true

# SPDX-FileCopyrightText: 2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'lib/testcase'
require_relative '../nci/cnf_generate'

module NCI
  class CNFGeneratorTest < TestCase
    def setup
      ENV['TYPE'] = 'release'
      ENV['REPO'] = 'user'
      ENV['DIST'] = 'focal'
      ENV['ARCH'] = 'amd64'
    end

    def test_run
      pkg1 = mock('pkg1')
      pkg1.stubs(:name).returns('atcore-bin')
      pkg1.stubs(:version).returns('1.0')
      pkg2 = mock('pkg2')
      pkg2.stubs(:name).returns('qtav-players')
      pkg2.stubs(:version).returns('2.0')

      remote = mock('Aptly::Ext::Remote.neon')
      lister = mock('NCI::RepoPackageLister')
      lister.stubs(:packages).returns([pkg1, pkg2])

      Aptly::Ext::Remote.stubs(:neon).yields(remote)
      NCI::RepoPackageLister.stubs(:new).returns(lister)

      stub_request(:get, 'https://contents.neon.kde.org/v2/find/archive.neon.kde.org/user/dists/focal?q=*/bin/*')
        .to_return(status: 200, body: File.read(data('json')))

      CNFGenerator.new.run
      # Not using this but the expectation is that we can run the generator in the same dir multiple times for different archies
      ENV['ARCH'] = 'armhf'
      CNFGenerator.new.run

      assert_path_exist('repo/main/cnf/Commands-amd64')
      assert_path_exist('repo/main/cnf/Commands-armhf')
      # Stripping to ignore \n differences, I don't really care.
      assert_equal(File.read(data('Commands-amd64')).strip, File.read('repo/main/cnf/Commands-amd64').strip)
    end
  end
end
