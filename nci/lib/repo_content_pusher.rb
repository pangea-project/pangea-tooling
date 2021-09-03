#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'fileutils'
require 'net/sftp'
require 'net/ssh'
require 'tmpdir'
require 'tty-command'

require_relative '../../lib/debian/release'
require_relative '../../lib/nci'

class NCI::RepoContentPusher
  APTLY_HOME = '/home/neonarchives'

  Sum = Struct.new(:file, :value)

  attr_reader :content_name
  attr_reader :repo_dir
  attr_reader :dist

  def initialize(content_name:, repo_dir:, dist:)
    @content_name = content_name
    @repo_dir = repo_dir
    @dist = dist
  end

  def repository_path
    # NB: the env var is called aply repo but it is in fact the repo path
    #   i.e. not 'unstable_focal' but dev/unstable
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
    content_dir_suffix = "main/#{content_name}"
    content_dir = "#{repo_dir}/#{content_dir_suffix}"

    tmpdir = "#{APTLY_HOME}/asgen_push.#{repository_path.tr('/', '-')}"
    targetdir = "#{APTLY_HOME}/aptly/skel/#{repository_path}/dists/#{dist}"

    # This depends on https://github.com/aptly-dev/aptly/pull/473
    # Aptly versions must take care to actually have the PR applied to them
    # until landed upstream!
    # NB: this is updating off-by-one. i.e. when we run the old data is
    #   published, we update the data but it will only be updated the next
    #   time the publish is updated (we may do this in the future as
    #   acquire-by-hash is desired for such quick update runs).

    # We need the checksum of the uncompressed file in the Release file
    # of the repo, this is currently not correctly handled in the aptly
    # skel system. As a quick stop-gap we'll simply make sure an
    # uncompressed file is around.
    # https://github.com/aptly-dev/aptly/pull/473#issuecomment-391281324
    Dir.glob("#{content_dir}/**/*.gz") do |compressed|
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
    Dir.glob("#{content_dir}/*") do |file|
      next if File.basename(file) == 'by-hash'
      raise "Did not expect !file: #{file}" unless File.file?(file)

      keys_and_tools.each do |key, tool|
        keys_and_sums[key] ||= []
        sum = cmd.run(tool, file).out.split[0]
        keys_and_sums[key] << Sum.new(File.absolute_path(file), sum)
      end
    end

    Net::SFTP.start('archive-api.neon.kde.org', 'neonarchives',
                    keys: ENV.fetch('SSH_KEY_FILE'), keys_only: true) do |sftp|
      content_targetdir = "#{targetdir}/#{content_dir_suffix}"
      content_tmpdir = "#{tmpdir}/#{content_dir_suffix}"

      puts sftp.session.exec!("rm -rf #{tmpdir}")
      puts sftp.session.exec!("mkdir -p #{content_tmpdir}")

      sftp.upload!("#{repo_dir}/.", tmpdir)

      # merge in original by-hash data, so we can update it
      puts sftp.session.exec!("cp -rv #{content_targetdir}/by-hash/. #{content_tmpdir}/by-hash/")

      by_hash = "#{content_tmpdir}/by-hash/"
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
                         Net::SFTP::Constants::RenameFlags::OVERWRITE |
                         Net::SFTP::Constants::RenameFlags::ATOMIC)
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

      puts sftp.session.exec!("rm -r #{content_targetdir}/")
      puts sftp.session.exec!("mkdir -p #{content_targetdir}/")
      puts sftp.session.exec!("cp -rv #{content_tmpdir}/. #{content_targetdir}/")
      puts sftp.session.exec!("rm -rv #{tmpdir}")
    end
  end
end
