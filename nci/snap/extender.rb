# frozen_string_literal: true
#
# Copyright (C) 2017-2018 Harald Sitter <sitter@kde.org>
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
require 'open-uri'
require 'rugged'
require 'tmpdir'
require 'yaml'

require_relative 'snapcraft_config'

module NCI
  module Snap
    # Extends a snapcraft file with code necessary to use the content snap.
    class Extender
      module Core16
        STAGED_CONTENT_PATH = 'https://build.neon.kde.org/job/kde-frameworks-5-release_amd64.snap/lastSuccessfulBuild/artifact/stage-content.json'
        STAGED_DEV_PATH = 'https://build.neon.kde.org/job/kde-frameworks-5-release_amd64.snap/lastSuccessfulBuild/artifact/stage-dev.json'
      end
      module Core18
        STAGED_CONTENT_PATH = 'https://build.neon.kde.org/job/kde-frameworks-5-core18-release_amd64.snap/lastSuccessfulBuild/artifact/stage-content.json'
        STAGED_DEV_PATH = 'https://build.neon.kde.org/job/kde-frameworks-5-core18-release_amd64.snap/lastSuccessfulBuild/artifact/stage-dev.json'
      end

      class << self
        def extend(file)
          new(file).extend
        end

        def run
          extend(ARGV.fetch(0, "#{Dir.pwd}/snapcraft.yaml"))
        end
      end

      def initialize(file)
        @data = YAML.load_file(file)
        data['parts'].each do |k, v|
          data['parts'][k] = SnapcraftConfig::Part.new(v)
        end
        setup_base
      end

      def extend
        convert_source!
        add_plugins!

        File.write('snapcraft.yaml', YAML.dump(data))
      end

      private

      attr_reader :data

      def setup_base
        case data['base']
        when 'core18'
          @base = Core18
          raise 'Trying to build core18 snap on not 18.04' unless bionic?
        when 'core16', nil
          @base = Core16
          raise 'Trying to build core16 snap on not 18.04' unless xenial?
        else
          raise "Do not know how to handle base value #{data[base].inspects}"
        end
      end

      def bionic?
        ENV.fetch('DIST') == 'bionic'
      end

      def xenial?
        ENV.fetch('DIST') == 'xenial'
      end

      def snapname
        @snapname ||= ENV.fetch('APPNAME')
      end

      def content_stage
        @content_stage ||= JSON.parse(open(@base::STAGED_CONTENT_PATH).read)
      end

      def dev_stage
        @dev_stage ||= JSON.parse(open(@base::STAGED_DEV_PATH).read)
      end

      def convert_to_git!
        repo = Rugged::Repository.new("#{Dir.pwd}/source")
        repo_branch = repo.branches[repo.head.name].name if repo.head.branch?
        data['parts'][snapname].source = repo.remotes['origin'].url
        data['parts'][snapname].source_type = 'git'
        data['parts'][snapname].source_commit = repo.last_commit.oid
        # FIXME: I want an @ here
        # https://bugs.launchpad.net/snapcraft/+bug/1712061
        oid = repo.last_commit.oid[0..6]
        # Versions cannot have slashes, branches can though, so convert to .
        data['version'] = [repo_branch, oid].join('+').tr('/', '.')
      end

      def add_plugins!
        target = "#{Dir.pwd}/snap/"
        FileUtils.mkpath(target)
        FileUtils.cp_r("#{__dir__}/plugins", target, verbose: true)
      end

      def dangerous_git_part?(part)
        part.source.include?('git.kde') &&
          !part.source.include?('snap-kf5-launcher')
      end

      def convert_source!
        if ENV.fetch('TYPE', 'unstable').include?('release')
          raise "Devel grade can't be TYPE release" if data['grade'] == 'devel'

          data['parts'].each_value do |part|
            # Guard against accidently building git parts for the stable
            # channel.
            raise 'Contains git source' if dangerous_git_part?(part)
          end
        else
          convert_to_git!
        end
      end
    end
  end
end
