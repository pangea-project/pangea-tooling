#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2017-2021 Harald Sitter <sitter@kde.org>

require_relative 'lint/versions'

our = NCI::DirPackageLister.new('result/')
their = NCI::CachePackageLister.new(filter_select: our.packages.map(&:name))
NCI::VersionsTest.init(ours: our.packages, theirs: their.packages)
ENV['CI_REPORTS'] = "#{Dir.pwd}/reports"
ARGV << '--ci-reporter'
require 'minitest/autorun'
