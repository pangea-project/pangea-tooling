#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'fileutils'

require_relative '../lib/nci'
require_relative '../lib/rsync'
require_relative 'lib/asgen_remote'
require_relative 'lib/repo_content_pusher'

# appstream pusher
class NCI::AppstreamGeneratorPush < NCI::AppstreamGeneratorRemote
  APTLY_HOME = '/home/neonarchives'

  Sum = Struct.new(:file, :value)

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
    # Move data into basic dir structure of repo skel.
    export_data_dir = "#{export_dir}/data"
    repo_dir = "#{export_dir}/repo"
    content_dir = "#{repo_dir}/main/dep11"

    unless File.exist?(export_data_dir)
      warn "The data dir #{export_data_dir} does not exist." \
          ' It seems asgen found no new data. Skipping publish!'
      return
    end

    FileUtils.rm_r(repo_dir) if Dir.exist?(repo_dir)
    FileUtils.mkpath(content_dir)
    FileUtils.cp_r("#{export_data_dir}/#{dist}/main/.", content_dir, verbose: true)

    NCI::RepoContentPusher.new(content_name: 'dep11', repo_dir: repo_dir, dist: dist).run

    FileUtils.rm_rf(repo_dir)

    # This is the export dep11 data, we don't need it, so throw it away
    system("rm -rf #{export_data_dir}")
    RSync.sync(from: "#{export_dir}/*", to: "#{rsync_pubdir_expression}/")
  end
end

NCI::AppstreamGeneratorPush.new.run if $PROGRAM_NAME == __FILE__
