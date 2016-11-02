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

require 'git'
require 'git_clone_url'
require 'net/ssh'
require 'rugged'

module NCI
  module DebianMerge
    # A merging repo.
    class Repository
      attr_accessor :tag_base
      attr_accessor :url

      class << self
        def clone_into(url, dir)
          unless Rugged.features.include?(:ssh)
            raise 'this rugged doesnt support ssh. need that to push!'
          end
          new(url, dir)
        end
      end

      def initialize(url, dir)
        path = "#{dir}/#{File.basename(url)}"
        # Use shell git wrapper to describe master, Rugged doesn't implement
        # git_describe_workdir yet.
        # Also cloning through a subprocess allows proper parallelism even with
        # ruby MRI
        @git = Git.clone(url, path)
        @rug = Rugged::Repository.init_at(path)
        @url = url
        config_repo
      end

      def config_repo
        @git.config('merge.dpkg-mergechangelogs.name',
                    'debian/changelog merge driver')
        @git.config('merge.dpkg-mergechangelogs.driver',
                    'dpkg-mergechangelogs -m %O %A %B %A')
        repo_path = @git.repo.path
        FileUtils.mkpath("#{repo_path}/info")
        File.write("#{repo_path}/info/attributes",
                   "debian/changelog merge=dpkg-mergechangelogs\n")
        @git.config('user.name', 'Neon CI')
        @git.config('user.email', 'neon@kde.org')
      end

      def merge
        assert_tag_valid

        # If the ancestor is the tag then the tag has been
        # merged already (i.e. the ancestor would be the tag itself)
        return if tag.target == ancestor

        merge_commit
      end

      def push
        mangle_push_path!
        @rug.remotes['origin'].push(
          [branch.canonical_name.to_s],
          update_tips: ->(*args) { puts "tip:: #{args}" },
          credentials: method(:credentials)
        )
      end

      private

      def branch
        @branch ||= begin
          branch = @rug.branches.find do |b|
            b.name == 'origin/Neon/pending-merge'
          end
          branch ||= @rug.branches.find { |b| b.name == 'origin/Neon/unstable' }
          raise 'couldnt find a branch to merge into' unless branch
          @rug.branches.create('Neon/pending-merge', branch.name)
        end
      end

      def ancestor
        @ancestor ||= begin
          ancestor_oid = @rug.merge_base(tag.target, branch.target)
          unless ancestor_oid
            raise "repo #{@url} has no ancestor on #{tag.name} & #{branch.name}"
          end
          @rug.lookup(ancestor_oid)
        end
      end

      def merge_commit
        @git.checkout(branch.name)
        @git.merge(tag.target_id, "Automatic merging of Debian's #{tag.name}")
      end

      def mangle_push_path!
        remote = @rug.remotes['origin']
        puts "pull url #{remote.url}"
        return unless remote.url.include?('anongit.neon.kde')
        pull_path = GitCloneUrl.parse(remote.url).path[1..-1]
        puts "mangle to neon@git.neon.kde.org:#{pull_path}"
        remote.push_url = "neon@git.neon.kde.org:#{pull_path}"
      end

      def credentials(url, username, types)
        raise unless types.include?(:ssh_key)
        config = Net::SSH::Config.for(GitCloneUrl.parse(url).host)
        default_key = "#{Dir.home}/.ssh/id_rsa"
        key = File.expand_path(config.fetch(:keys, [default_key])[0])
        Rugged::Credentials::SshKey.new(
          username: username,
          publickey: key + '.pub',
          privatekey: key,
          passphrase: ''
        )
      end

      def tag
        # Dir.chdir(@git.dir.path) do
        #   system 'gitk'
        # end
        @tag ||= begin
          tag_name = @git.tags.sort_by { |x| x.tagger.date }[-1].name
          @rug.tags.find { |t| t.name == tag_name }
        end
      end

      def assert_tag_valid
        raise unless @tag_base || tag
        unless tag.name.start_with?(@tag_base)
          raise "unexpected last tag #{tag.name} on #{@git.dir.path}"
        end
        puts "#{@git.dir.path} : #{tag.name}"
      end
    end
  end
end
