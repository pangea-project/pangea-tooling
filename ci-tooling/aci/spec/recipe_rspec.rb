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
require_relative '../libs/recipe'
require_relative '../libs/sources'
require 'yaml'
require 'erb'

metadata = YAML.load_file("/in/data/metadata.yml")
deps = metadata['dependencies']
puts metadata

describe Recipe do
  app = Recipe.new(name: metadata['name'], binary: metadata['binary'])
  describe "#initialize" do
    it "Sets the application name" do
      expect(app.name).to eq metadata['name']
      expect(app.binary).to eq metadata['binary']
    end
  end

  describe 'clean_workspace' do
    it "Cleans the environment" do
      unless Dir["/in/#{app.name}"].empty? && Dir["/app.Dir/*"].empty?
        Dir.chdir('/')
        app.clean_workspace(name: app.name)
      end
      expect(Dir["/app.Dir/*"].empty?).to be(true), "Please clean up from last build"
    end
  end



  describe 'build_non_kf5_dep_sources' do
    it 'Builds source dependencies that do not depend on kf5' do
      sources = Sources.new
      deps = metadata['dependencies']
      deps.each do |dep|
        name =  dep.values[0]['depname']
        type = dep.values[0]['source'].values_at('type').to_s.gsub(/\,|\[|\]|\"/, '')
        url = dep.values[0]['source'].values_at('url').to_s.gsub(/\,|\[|\]|\"/, '')
        branch = dep.values[0]['source'].values_at('branch').to_s.gsub(/\,|\[|\]|\"/, '')
        buildsystem = dep.values[0]['build'].values_at('buildsystem').to_s.gsub(/\,|\[|\]|\"/, '')
        options = dep.values[0]['build'].values_at('buildoptions').to_s.gsub(/\,|\[|\]|\"/, '')
        autoreconf = dep.values[0]['build'].values_at('autoreconf').to_s.gsub(/\,|\[|\]|\"/, '')
        insource = dep.values[0]['build'].values_at('insource').to_s.gsub(/\,|\[|\]|\"/, '')
        path = "/app/src/#{name}"
        expect(sources.get_source(name, type, url, branch)).to be(0), " Expected 0 exit Status"
        unless name == 'cpan'
          expect(Dir.exist?("/app/src/#{name}")).to be(true), "#{name} directory does not exist, something went wrong with source retrieval"
        end
        unless buildsystem == 'make'
          expect(sources.run_build(name, buildsystem, options, path)).to be(0), " Expected 0 exit Status"
        end
        if buildsystem == 'make'
          expect(sources.run_build(name, buildsystem, options, path, autoreconf, insource)).to be(0), " Expected 0 exit Status"
        end
      end
    end
  end

  describe 'build_kf5' do
    it 'Builds KDE Frameworks from source' do
      sources = Sources.new
      system('pwd && ls')
      kf5 = metadata['frameworks']
      need = kf5['build_kf5']
      frameworks = kf5['frameworks']
      if need == true
        frameworks.each do |framework|
          path = "/app/src/#{framework}"
          if framework == 'phonon' || framework == 'phonon-gstreamer'
            options = '-DCMAKE_INSTALL_PREFIX:PATH=/opt/usr  -DKDE_INSTALL_SYSCONFDIR=/opt/etc -DPHONON_LIBRARY_PATH=/opt/usr/plugins -DBUILD_TESTING=OFF -DPHONON_BUILD_PHONON4QT5=ON -DPHONON_INSTALL_QT_EXTENSIONS_INTO_SYSTEM_QT=TRUE'
            expect(sources.get_source(framework, 'git', "https://anongit.kde.org/#{framework}")).to be(0), "Expected 0 exit status"
            expect(Dir.exist?("/app/src/#{framework}")).to be(true), "#{framework} directory does not exist, something went wrong with source retrieval"
            expect(sources.run_build(framework, 'cmake', options, path)).to be(0), " Expected 0 exit Status"
          elsif framework == 'breeze-icons'
            options = '-DCMAKE_INSTALL_PREFIX:PATH=/opt/usr  -DKDE_INSTALL_SYSCONFDIR=/opt/etc -DBUILD_TESTING=OFF -DBINARY_ICONS_RESOURCE=ON'
            expect(sources.get_source(framework, 'git', "https://anongit.kde.org/#{framework}")).to be(0), "Expected 0 exit status"
            expect(Dir.exist?("/app/src/#{framework}")).to be(true), "#{framework} directory does not exist, something went wrong with source retrieval"
            expect(sources.run_build(framework, 'cmake', options, path)).to be(0), " Expected 0 exit Status"
          elsif framework == 'akonadi'
            options = '-DCMAKE_INSTALL_PREFIX:PATH=/opt/usr  -DKDE_INSTALL_SYSCONFDIR=/opt/etc -DBUILD_TESTING=OFF -DMYSQLD_EXECUTABLE:STRING=/usr/sbin/mysqld-akonadi'
            expect(sources.get_source(framework, 'git', "https://anongit.kde.org/#{framework}")).to be(0), "Expected 0 exit status"
            expect(Dir.exist?("/app/src/#{framework}")).to be(true), "#{framework} directory does not exist, something went wrong with source retrieval"
            expect(sources.run_build(framework, 'cmake', options, path)).to be(0), " Expected 0 exit Status"
          else
            options = '-DCMAKE_INSTALL_PREFIX:PATH=/opt/usr -DKDE_INSTALL_SYSCONFDIR=/opt/etc -DBUILD_TESTING=OFF'
            expect(sources.get_source(framework, 'git', "https://anongit.kde.org/#{framework}")).to be(0), "Expected 0 exit status"
            expect(Dir.exist?("/app/src/#{framework}")).to be(true), "#{framework} directory does not exist, something went wrong with source retrieval"
            expect(sources.run_build(framework, 'cmake', options, path)).to be(0), " Expected 0 exit Status"
          end
        end
      end
    end
  end

    describe 'build_kf5_dep_sources' do
      it 'Builds source dependencies that depend on kf5' do
        sources = Sources.new
        kf5 = metadata['frameworks']
        need = kf5['build_kf5']
        frameworks = kf5['frameworks']
        if need == true
          deps = metadata['kf5_deps']
          if deps
            deps.each do |dep|
              name =  dep.values[0]['depname']
              type = dep.values[0]['source'].values_at('type').to_s.gsub(/\,|\[|\]|\"/, '')
              url = dep.values[0]['source'].values_at('url').to_s.gsub(/\,|\[|\]|\"/, '')
              branch = dep.values[0]['source'].values_at('branch').to_s.gsub(/\,|\[|\]|\"/, '')
              buildsystem = dep.values[0]['build'].values_at('buildsystem').to_s.gsub(/\,|\[|\]|\"/, '')
              options = dep.values[0]['build'].values_at('buildoptions').to_s.gsub(/\,|\[|\]|\"/, '')
              path = "/app/src/#{name}"
              expect(sources.get_source(name, type, url, branch)).to be(0), " Expected 0 exit Status"
              expect(Dir.exist?("/app/src/#{name}")).to be(true), "#{name} directory does not exist, something went wrong with source retrieval"
              expect(sources.run_build(name, buildsystem, options, path)).to be(0), " Expected 0 exit Status"
            end
          end
        end
      end
    end


    describe 'build_project' do
        it 'Retrieves sources that need to be built from source' do
          #Main project
          sources = Sources.new
          name = metadata['name']
          path = "/in/#{name}"
          buildsystem = metadata['buildsystem']
          options = metadata['buildoptions']
          expect(Dir.exist?("/in/#{name}")).to be(true), "#{name} directory does not exist, things will fail"
          expect(sources.run_build(name, buildsystem, options, path)).to be(0), " Expected 0 exit Status"
          p system("qmlimportscanner -rootPath /in/#{name}")
        end
    end

  describe 'generate_appimage' do
    it 'Generate the appimage' do
      arch = `arch`
      File.write('/in/Recipe', app.render)
      expect(app.generate_appimage()).to eq 0
      expect(Dir["/appimage/*"].empty?).to be(false), "No Appimage"
      `rm -rfv /app/*`
      `rm -f functions.sh`
      expect(Dir["/app/*"].empty?).to be(true), "Please clean up"
    end
  end
end
