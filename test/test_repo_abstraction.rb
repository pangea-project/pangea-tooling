# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>

require_relative 'lib/testcase'
require_relative '../lib/repo_abstraction'

require 'mocha/test_unit'
require 'webmock/test_unit'
require '../lib/gir_ffi'

# Fake mod
module PackageKitGlib
  module FilterEnum
    module_function

    def [](x)
      {
        arch: 18
      }.fetch(x)
    end
  end

  # rubocop:disable Lint/EmptyClass
  class Client
  end
  # rubocop:enable Lint/EmptyClass

  class Result
    attr_reader :package_array

    def initialize(package_array)
      @package_array = package_array
    end
  end

  class Package
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def self.from_array(array)
      array.collect { |x| new(x) }
    end
  end
end

class RepoAbstractionAptlyTest < TestCase
  required_binaries('dpkg')

  def setup
    WebMock.disable_net_connect!

    # More slective so we can let DPKG through.
    Apt::Repository.expects(:system).never
    Apt::Repository.expects(:`).never
    Apt::Abstrapt.expects(:system).never
    Apt::Abstrapt.expects(:`).never
    Apt::Cache.expects(:system).never
    Apt::Cache.expects(:`).never

    Apt::Repository.send(:reset)
    # Disable automatic update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
  end

  def teardown
    NCI.send(:reset!)
  end

  def test_init
    AptlyRepository.new('repo', 'prefix')
  end

  def test_sources
    repo = mock('repo')
    repo
      .stubs(:packages)
      .with(q: '$Architecture (source)')
      .returns(['Psource kactivities-kf5 3 ghi',
                'Psource kactivities-kf5 4 jkl',
                'Psource kactivities-kf5 2 def']) # Make sure this is filtered

    r = AptlyRepository.new(repo, 'prefix')
    assert_equal(['Psource kactivities-kf5 4 jkl'], r.sources.collect(&:to_s))
  end

  # implicitly tests #packages
  def test_install
    repo = mock('repo')
    repo
      .stubs(:packages)
      .with(q: '$Architecture (source)')
      .returns(['Psource kactivities-kf5 4 jkl']) # Make sure this is filtered
    repo
      .stubs(:packages)
      .with(q: '!$Architecture (source), $PackageType (deb), $Source (kactivities-kf5), $SourceVersion (4)')
      .returns(['Pamd64 libkactivites 4 abc'])

    Apt::Abstrapt.expects(:system).with do |*x|
      x.include?('install') && x.include?('libkactivites=4')
    end.returns(true)

    r = AptlyRepository.new(repo, 'prefix')
    r.install
  end

  def test_purge_exclusion
    repo = mock('repo')
    repo
      .stubs(:packages)
      .with(q: '$Architecture (source)')
      .returns(['Psource kactivities-kf5 4 jkl'])
    repo
      .stubs(:packages)
      .with(q: '!$Architecture (source), $PackageType (deb), $Source (kactivities-kf5), $SourceVersion (4)')
      .returns(['Pamd64 libkactivites 4 abc', 'Pamd64 kitteh 5 efd', 'Pamd64 base-files 5 efd'])
    # kitteh we filter, base-files should be default filtered
    Apt::Abstrapt
      .expects(:system)
      .with('apt-get', *Apt::Abstrapt.default_args, '--allow-remove-essential', 'purge', 'libkactivites')
      .returns(true)

    r = AptlyRepository.new(repo, 'prefix')
    r.purge_exclusion << 'kitteh'
    r.purge
  end

  def test_diverted_init
    # Trivial test to ensure the /tmp/ prefix is injected when repo diversion is enabled.
    # This was broken in the past so let's guard against it breaking again. The code is a super concerned
    # with internals though :(
    repo = mock('repo')
    NCI.send(:data_dir=, Dir.pwd)
    File.write('nci.yaml', YAML.dump('repo_diversion' => true, 'divertable_repos' => ['whoopsiepoosie']))
    r = AptlyRepository.new(repo, 'whoopsiepoosie')
    assert(r.instance_variable_get(:@_name).include?('/tmp/'))
  end
end

class RepoAbstractionRootOnAptlyTest < TestCase
  required_binaries('dpkg')

  def setup
    WebMock.disable_net_connect!

    # Do not let gir through!
    GirFFI.expects(:setup).never
    # And Doubly so for dbus!
    RootOnAptlyRepository.any_instance.expects(:dbus_run).yields

    # More slective so we can let DPKG through.
    Apt::Repository.expects(:system).never
    Apt::Repository.expects(:`).never
    Apt::Abstrapt.expects(:system).never
    Apt::Abstrapt.expects(:`).never
    Apt::Cache.expects(:system).never
    Apt::Cache.expects(:`).never

    Apt::Repository.send(:reset)
    # Disable automatic update
    Apt::Abstrapt.send(:instance_variable_set, :@last_update, Time.now)
    Apt::Cache.send(:instance_variable_set, :@last_update, Time.now)
  end

=begin
  def test_init
    Apt::Abstrapt
      .expects(:system)
      .with('apt-get', *Apt::Abstrapt.default_args, 'install', 'packagekit', 'libgirepository1.0-dev', 'gir1.2-packagekitglib-1.0', 'dbus-x11')
      .returns(true)
    GirFFI.expects(:setup).with(:PackageKitGlib, '1.0').returns(true)
    PackageKitGlib::Client.any_instance.expects(:get_packages).with(18).returns(PackageKitGlib::Result.new([]))

    repo = RootOnAptlyRepository.new
    assert_empty(repo.send(:packages))
    # Should not hit mocha never-expectations.
    repo.add
    repo.remove
  end
  def test_packages
    mock_repo1 = mock('mock_repo1')
    mock_repo1
      .stubs(:packages)
      .with(q: '$Architecture (source)')
      .returns(['Psource kactivities-kf5 4 jkl'])
    mock_repo1
      .stubs(:packages)
      .with(q: '!$Architecture (source), $PackageType (deb), $Source (kactivities-kf5), $SourceVersion (4)')
      .returns(['Pamd64 libkactivites 4 abc'])

    mock_repo2 = mock('mock_repo2')
    mock_repo2
      .stubs(:packages)
      .with(q: '$Architecture (source)')
      .returns(['Psource kactivities-kf5 4 jkl', 'Psource trollomatico 3 abc'])
    mock_repo2
      .stubs(:packages)
      .with(q: '!$Architecture (source), $PackageType (deb), $Source (kactivities-kf5), $SourceVersion (4)')
      .returns(['Pamd64 libkactivites 4 abc'])
    mock_repo2
      .stubs(:packages)
      .with(q: '!$Architecture (source), $PackageType (deb), $Source (trollomatico), $SourceVersion (3)')
      .returns(['Pamd64 trollomatico 3 edf', 'Pamd64 unicornsparkles 4 xyz'])

    Apt::Abstrapt
      .expects(:system)
      .with('apt-get', *Apt::Abstrapt.default_args, 'install', 'packagekit', 'libgirepository1.0-dev', 'gir1.2-packagekitglib-1.0', 'dbus-x11')
      .returns(true)

    GirFFI.expects(:setup).with(:PackageKitGlib, '1.0').returns(true)
    packages = PackageKitGlib::Package.from_array(%w[libkactivites trollomatico])
    result = PackageKitGlib::Result.new(packages)
    PackageKitGlib::Client.any_instance.expects(:get_packages).with(18).returns(result)

    aptly_repo1 = AptlyRepository.new(mock_repo1, 'mock1')
    aptly_repo2 = AptlyRepository.new(mock_repo2, 'mock2')

    Apt::Abstrapt
      .expects(:system)
      .with('apt-get', *Apt::Abstrapt.default_args, 'install', 'ubuntu-minimal', 'libkactivites', 'trollomatico')
      .returns(true)
    assert(RootOnAptlyRepository.new([aptly_repo1, aptly_repo2]).install)
  end
=end
end
