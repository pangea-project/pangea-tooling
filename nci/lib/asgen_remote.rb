#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

class NCI::AppstreamGeneratorRemote
  def dist
    ENV.fetch('DIST')
  end

  def type
    ENV.fetch('TYPE')
  end

  def run_dir
    @run_dir ||= File.absolute_path('run')
  end

  def export_dir
    "#{run_dir}/export"
  end

  def export_dir_data
    "#{run_dir}/export/data"
  end

  def rsync_pubdir_expression
    pubdir = "/srv/www/metadata.neon.kde.org/appstream/#{type}_#{dist}"
    "metadataneon@charlotte.kde.org:#{pubdir}"
  end
end
