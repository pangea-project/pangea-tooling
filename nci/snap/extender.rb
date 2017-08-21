# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require 'json'
require 'rugged'
require 'tmpdir'
require 'yaml'

require_relative 'snapcraft_config'

module NCI
  module Snap
    # Extends a snapcraft file with code necessary to use the content snap.
    module Extender
      module_function

      STAGED_CONTENT_PATH = 'https://build.neon.kde.org/job/kde-frameworks-5-release_amd64.snap/lastSuccessfulBuild/artifact/stage-content.json'.freeze
      STAGED_DEV_PATH = 'https://build.neon.kde.org/job/kde-frameworks-5-release_amd64.snap/lastSuccessfulBuild/artifact/stage-dev.json'.freeze

      def snapname
        @snapname ||= ENV.fetch('APPNAME')
      end

      def content_stage
        @content_stage ||= JSON.parse(open(STAGED_CONTENT_PATH).read)
      end

      def dev_stage
        @dev_stage ||= begin
          stage = JSON.parse(open(STAGED_DEV_PATH).read)
          stage.reject { |x| x.include?('doctools') }
        end
      end

      def add_runtime(name, part)
        debs = part.stage_packages.dup
        part.stage_packages.clear

        runtime = SnapcraftConfig::Part.new
        runtime.plugin = 'stage-debs'
        runtime.debs = debs
        runtime.exclude_debs = content_stage.uniq.compact
        # Part has a standard exclusion rule for priming which should be fine.
        runname = "runtime-of-#{name}"
        @data['parts'][runname] = runtime
        part.after << runname
      end

      def add_buildtime(name, part)
        debs = part.build_packages.dup
        part.build_packages.clear

        buildtime = SnapcraftConfig::Part.new
        buildtime.plugin = 'stage-debs'
        buildtime.debs = debs
        buildtime.exclude_debs = (dev_stage + content_stage).uniq.compact
        buildtime.snap = ['-*']
        buildname = "buildtime-of-#{name}"
        data['parts'][buildname] = buildtime
        part.after << buildname
      end

      def convert_to_git!
        # FIXME: this should be based on our overrides crap
        repo_url = "https://anongit.kde.org/#{snapname}"
        repo_branch = 'master'
        Dir.mktmpdir do |tmpdir|
          repo = Rugged::Repository.init_at(tmpdir)
          remote = repo.remotes.create_anonymous(repo_url)
          ref = remote.ls.find do |name:, **|
            name == "refs/heads/#{repo_branch}"
          end
          data['parts'][snapname].source = repo_url
          data['parts'][snapname].source_type = 'git'
          data['parts'][snapname].source_commit = ref.fetch(:oid)
          # FIXME: I want an @ here
          # https://bugs.launchpad.net/snapcraft/+bug/1712061
          data['version'] = "#{repo_branch.tr('/', '.')}+#{ref.fetch(:oid)}"
        end
      end

      def data
        @data
      end

      def load(file)
        @data = YAML.load_file(file)
        require 'pp'
        pp data
        data['parts'].each do |k, v|
          data['parts'][k] = SnapcraftConfig::Part.new(v)
        end
      end

      def buildtimes
        data['parts'].reject do |_name, part|
          part.build_packages.empty? || part.plugin == 'stage-debs'
        end.to_h
      end

      def runtimes
        data['parts'].reject do |_name, part|
          part.stage_packages.empty? || part.plugin == 'stage-debs'
        end.to_h
      end

      def convert_to_deb_staging!
        buildtimes.each { |name, part| add_buildtime(name, part) }
        runtimes.each { |name, part| add_runtime(name, part) }
      end

      def add_plugins!
        target = "#{Dir.pwd}/snap/"
        FileUtils.mkpath(target)
        FileUtils.cp_r("#{__dir__}/plugins", target, verbose: true)
      end

      def extend(file)
        load(file)

        convert_to_git!
        convert_to_deb_staging!
        add_plugins!

        p Dir.pwd
        p file
        File.write('snapcraft.yaml', YAML.dump(data))
      end

      def run
        extend(ARGV.fetch(0, "#{Dir.pwd}/snapcraft.yaml"))
      end
    end
  end
end
