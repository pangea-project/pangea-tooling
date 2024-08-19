#!/usr/bin/env ruby
# frozen_string_literal: true
#
# SPDX-FileCopyrightText: 2015-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../../lib/nci'

DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
# NB: DO NOT CHANGE THIS LIGHTLY!!!!
# The series guards prevent the !current series from publishing over the current
# series. When the ISO should change you'll want to edit nci.yaml and shuffle
# the series entries around there.
REMOTE_DIR = case DIST
             # release is for dev purposes only
             when TYPE == 'release'
               "neon/images/#{DIST}-preview/#{TYPE}/"
             when NCI.current_series
               "neon/images/#{TYPE}/"
             when NCI.future_series
               # Subdir if not the standard version
               "neon/images/#{DIST}-preview/#{TYPE}/"
             when NCI.old_series
               raise "The old series ISO built but it shouldn't have!" \
                     ' Remove the jobs or smth.'
             else
               raise 'No DIST env var defined; no idea what to do!'
             end
