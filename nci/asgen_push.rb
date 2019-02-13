#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016-2019 Harald Sitter <sitter@kde.org>
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

require 'fileutils'
require 'net/sftp'
require 'net/ssh'
require 'tmpdir'
require 'tty-command'

require_relative '../ci-tooling/lib/debian/release'
require_relative '../ci-tooling/lib/nci'

class NCI::AppstreamGeneratorPush
  APTLY_HOME = "/home/neonarchives"

  Sum = Struct.new(:file, :value)

  class RSync
    def self.sync(from, to)
      ssh_command = "ssh -o StrictHostKeyChecking=no -i #{ENV.fetch('SSH_KEY_FILE')}"
      rsync_opts = "-av -e '#{ssh_command}'"
      system("rsync #{rsync_opts} #{from} #{to}") || raise
    end
  end

  def dist
    ENV.fetch('DIST')
  end

  def type
    ENV.fetch('TYPE')
  end

  def aptly_repository
    ENV.fetch('APTLY_REPOSITORY')
  end

  def exist?(sftp, path)
    sftp.stat!(path)
    true
  rescue Net::SFTP::StatusException
    false
  end

  def symlink?(sftp, path)
    sftp.readlink!(path)
    true
  rescue Net::SFTP::StatusException
    false
  end

  def run
    run_dir = File.absolute_path('run')

    # Move data into basic dir structure of repo skel.
    export_dir = "#{run_dir}/export"
    export_data_dir = "#{export_dir}/data"
    repo_dir = "#{export_dir}/repo"
    dep11_dir = "#{repo_dir}/main/dep11"

    unless File.exist?(export_data_dir)
      warn "The data dir #{export_data_dir} does not exist." \
          ' It seems asgen found no new data. Skipping publish!'
      return
    end

    FileUtils.rm_r(repo_dir) if Dir.exist?(repo_dir)
    FileUtils.mkpath(dep11_dir)
    FileUtils.cp_r("#{export_data_dir}/#{dist}/main/.", dep11_dir, verbose: true)

    tmpdir = "#{APTLY_HOME}/asgen_push.#{aptly_repository.tr('/', '-')}"
    targetdir = "#{APTLY_HOME}/aptly/skel/#{aptly_repository}/dists/#{dist}"

    # This depends on https://github.com/aptly-dev/aptly/pull/473
    # Aptly versions must take care to actually have the PR applied to them until
    # landed upstream!
    # NB: this is updating off-by-one. i.e. when we run the old data is published,
    #   we update the data but it will only be updated the next time the publish
    #   is updated (we may do this in the future as acquire-by-hash is desired for
    #   such quick update runs).

    # We need the checksum of the uncompressed file in the Release file of the repo,
    # this is currently not correctly handled in the aptly skel system. As a quick
    # stop-gap we'll simply make sure an uncompressed file is around.
    # https://github.com/aptly-dev/aptly/pull/473#issuecomment-391281324
    Dir.glob("#{dep11_dir}/**/*.gz") do |compressed|
      next if compressed.include?('by-hash') # do not follow by-hash
      system('gunzip', '-k', compressed) || raise
    end


    keys_and_tools = {
      'MD5Sum' => 'md5sum',
      'SHA1' => 'sha1sum',
      'SHA256' => 'sha256sum',
      'SHA512' => 'sha512sum'
    }

    keys_and_sums = {}

    cmd = TTY::Command.new

    # Create a sum map for all files, we'll then by-hash each of them.
    Dir.glob("#{dep11_dir}/*") do |file|
      next if File.basename(file) == 'by-hash'
      raise "Did not expect !file: #{file}" unless File.file?(file)
      keys_and_tools.each do |key, tool|
        keys_and_sums[key] ||= []
        sum = cmd.run(tool, file).out.split(' ')[0]
        keys_and_sums[key] << Sum.new(File.absolute_path(file), sum)
      end
    end

    Net::SFTP.start('archive-api.neon.kde.org', 'neonarchives',
                    keys: ENV.fetch('SSH_KEY_FILE'), keys_only: true) do |sftp|
      dep11_targetdir = "#{targetdir}/main/dep11/"
      dep11_tmpdir = "#{tmpdir}/main/dep11/"

      puts sftp.session.exec!("rm -rf #{tmpdir}")
      puts sftp.session.exec!("mkdir -p #{tmpdir}")

      sftp.upload!("#{repo_dir}/.", tmpdir)

      # merge in original by-hash data, so we can update it
      puts sftp.session.exec!("cp -rv #{dep11_targetdir}/by-hash/. #{dep11_tmpdir}/by-hash/")

      by_hash = "#{dep11_tmpdir}/by-hash/"
      sftp.mkdir!(by_hash) unless exist?(sftp, by_hash)

      keys_and_sums.each do |key, sums|
        dir = "#{by_hash}/#{key}/"
        sftp.mkdir!(dir) unless exist?(sftp, dir)

        sums.each do |sum|
          basename = File.basename(sum.file)
          base_path = File.join(dir, basename)

          old = "#{basename}.old"
          old_path = File.join(dir, old)
          if symlink?(sftp, old_path)
            # If we had an old variant, drop it.
            sftp.remove!(old_path)
          end
          if symlink?(sftp, base_path)
            # If we have a current variant, make it the old variant.
            sftp.rename!(base_path, old_path,
              Net::SFTP::Constants::RenameFlags::OVERWRITE | Net::SFTP::Constants::RenameFlags::ATOMIC)
          end

          # Use our current data as the new current variant.
          sftp.upload!(sum.file, File.join(dir, sum.value))
          sftp.symlink!(sum.value, base_path)
        end

        # Get a list of all blobs and drop all which aren't referenced by any of
        # the marker symlinks. This should give super reliable cleanup.
        used_blobs = []
        blobs = []

        sftp.dir.glob(dir, '*') do |entry|
          path = File.join(dir, entry.name)
          puts path
          if entry.symlink?
            used_blobs << File.absolute_path(sftp.readlink!(path).name, dir)
          else
            blobs << File.absolute_path(path)
          end
        end

        warn "All blobs in #{key}: #{used_blobs}"
        warn "Used blobs in #{key}: #{blobs}"
        warn "Blobs to delete in #{key}: #{(blobs - used_blobs)}"

        (blobs - used_blobs).each do |blob|
          sftp.remove!(blob)
        end
      end

      puts sftp.session.exec!("rm -r #{targetdir}/")
      puts sftp.session.exec!("mkdir -p #{targetdir}/")
      puts sftp.session.exec!("cp -rv #{tmpdir}/. #{targetdir}/")
      puts sftp.session.exec!("rm -rv #{tmpdir}")
    end
    FileUtils.rm_rf(repo_dir)

    pubdir = "/srv/www/metadata.neon.kde.org/appstream/#{type}_#{dist}"

    # This is the export dep11 data, we don't need it, so throw it away
    system("rm -rf #{export_data_dir}")
    # NB: We use rsync here because a) SFTP is dumb and may require copying things
    #   to tmp path, removing pubdir and moving tmpdir to pubdir, while rsync will
    #   be faster.
    remote_dir = "metadataneon@charlotte.kde.org:#{pubdir}"
    RSync.sync("#{export_dir}/*", "#{remote_dir}/")
  end
end

NCI::AppstreamGeneratorPush.new.run if $PROGRAM_NAME == __FILE__
