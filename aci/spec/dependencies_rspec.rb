#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Scarlett Clark <sgclark@kde.org>
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

require_relative '../libs/scm'
require_relative '../libs/build'
require_relative '../libs/sources'
require_relative '../libs/packages'
require_relative '../libs/metadata'
require 'yaml'

exit_status = 'Expected 0 exit Status'

describe 'install_packages' do
  it 'Installs distribution packages' do
    expect(
      Packages.install_packages(
        kde: Metadata::BUILDKF5, projectpackages: Metadata::PROJECTPACKAGES
      )
    ).to be(0), exit_status
  end
end

describe 'build_non_kf5_dep_sources' do
  it 'Builds source dependencies that do not depend on kf5' do
    deps = Metadata::EXTERNALDEPENDENCIES
    if deps
      deps.each do |dep|
        name =  dep.values[0]['depname']
        type = dep.values[0]['source'].values_at('type').to_s.gsub(/\,|\[|\]|\"/, '')
        url = dep.values[0]['source'].values_at('url').to_s.gsub(/\,|\[|\]|\"/, '')
        file = dep.values[0]['source'].values_at('file').to_s.gsub(/\,|\[|\]|\"/, '')
        branch = dep.values[0]['source'].values_at('branch').to_s.gsub(/\,|\[|\]|\"/, '')
        buildsystem = dep.values[0]['build'].values_at('buildsystem').to_s.gsub(/\,|\[|\]|\"/, '')
        options = dep.values[0]['build'].values_at('buildoptions').to_s.gsub(/\,|\[|\]|\"/, '')
        autoreconf = dep.values[0]['build'].values_at('autoreconf').to_s.gsub(/\,|\[|\]|\"/, '')
        insource = dep.values[0]['build'].values_at('insource').to_s.gsub(/\,|\[|\]|\"/, '')
        dir = '/source/'
        source = SCM.new(url: url, branch: branch, dir: dir, type: type, file: file, name: name)
        expect(source.select_type).to be(0), exit_status
        build = Build.new(
          name: name,
          buildsystem: buildsystem,
          options: options,
          insource: insource,
          dir: dir,
          autoreconf: autoreconf
        )
        build.run(select_buildsystem)
        FileUtils.rm_rf(File.join(Dir.pwd,  name))
      end
    end
  end
end

describe 'build_kf5' do
  it 'Builds KDE Frameworks from source' do
    frameworks = Frameworks.generatekf5_buildorder(Metadata::FRAMEWORKS)
    KF5 = YAML.load_file(File.join(__dir__, '../data/kf5.yaml'))
    if Metadata::BUILDKF5
      frameworks.each do |framework|
        dir = '/source/'
        url = "https://anongit.kde.org/#{framework}"
        source = SCM.new(
          url: url,
          branch: 'master',
          dir: dir,
          type: 'git',
          name: framework
        )
        expect(source.select_type).to be(0), exit_status
        name = framework
        buildsystem = 'cmake'
        extra_options = KF5[framework]['options']
        options = '-DCMAKE_INSTALL_PREFIX:PATH=/opt/usr \
        -DKDE_INSTALL_SYSCONFDIR=/opt/etc \
        -DCMAKE_PREFIX_PATH=/opt/usr:/usr'
        options += extra_options if extra_options
        insource = false
        build = Build.new(
          name: name,
          buildsystem: buildsystem,
          options: options,
          insource: insource,
          dir: dir
        )
        build.run(select_buildsystem)
        FileUtils.rm_rf(File.join(Dir.pwd,  name))
      end
    end
  end
end

describe 'build_kde_dep' do
  it 'Builds KDE project dependencies from source' do
    dir = '/source/'
    deps = Metadata::KDEDEPS
    if deps
      deps.each do |dep|
        url = "https://anongit.kde.org/#{dep}"
        source = SCM.new(
          url: url,
          branch: 'master',
          dir: dir,
          type: 'git',
          name: dep
        )
        expect(source.select_type).to be(0), exit_status
        name = dep
        buildsystem = 'cmake'
        options = '-DCMAKE_INSTALL_PREFIX:PATH=/opt/usr \
        -DKDE_INSTALL_SYSCONFDIR=/opt/etc \
        -DCMAKE_PREFIX_PATH=/opt/usr:/usr'
        insource = false
        build = Build.new(
          name: name,
          buildsystem: buildsystem,
          options: options,
          insource: insource,
          dir: dir
        )
        build.run(select_buildsystem)
        FileUtils.rm_rf(File.join(Dir.pwd, name))
      end
    end
  end
end

describe 'build_kf5_dep_sources' do
  it 'Builds source dependencies that depend on kf5' do
    deps = Metadata::DEPSONKF5
    if deps
      deps.each do |dep|
        dir = '/source/'
        name = dep.values[0]['depname']
        type = dep.values[0]['source'].values_at('type').to_s.gsub(/\,|\[|\]|\"/, '')
        url = dep.values[0]['source'].values_at('url').to_s.gsub(/\,|\[|\]|\"/, '')
        branch = dep.values[0]['source'].values_at('branch').to_s.gsub(/\,|\[|\]|\"/, '')
        buildsystem = dep.values[0]['build'].values_at('buildsystem').to_s.gsub(/\,|\[|\]|\"/, '')
        options = dep.values[0]['build'].values_at('buildoptions').to_s.gsub(/\,|\[|\]|\"/, '')
        source = SCM.new(
          url: url,
          branch: branch,
          dir: dir,
          type: type,
          name: dep
        )
        expect(source.select_type).to be(0), exit_status
        expect(Dir.exist?("/source/#{name}")).to be(true), "#{name} directory does not exist, something went wrong with source retrieval"
        name = framework
        buildsystem = 'cmake'
        insource = false
        build = Build.new(
          name: name,
          buildsystem: buildsystem,
          options: options,
          insource: insource,
          dir: dir
        )
        build.run(select_buildsystem)
        FileUtils.rm_rf(File.join(Dir.pwd,  name))
      end
    end
  end
end
