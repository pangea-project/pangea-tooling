#!/usr/bin/env ruby
# frozen_string_literal: true
#
# SPDX-FileCopyrightText: 2023 Jonthan Esk-Riddell <jr@jriddell.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
#
# A test to install i386 packages steam and wine32 from the ubuntu archive
# These are popular and we can easily break installs of them by e.g. backporting some
# library they depend on without making an i386 build

require 'aptly'
require 'date'

require_relative 'lib/setup_repo'
require_relative 'lib/i386_install_check'

TYPE = ENV.fetch('TYPE')
REPO_KEY = "#{TYPE}_#{ENV.fetch('DIST')}"

NCI.setup_proxy!
NCI.add_repo_key!

# Force a higher time out. We are going to do one or two heavy queries.
Faraday.default_connection_options =
  Faraday::ConnectionOptions.new(timeout: 15 * 60)

Aptly.configure do |config|
  config.uri = URI::HTTPS.build(host: 'archive-api.neon.kde.org')
  # This is read-only.
end

proposed = AptlyRepository.new(Aptly::Repository.get(REPO_KEY), 'release')

checker = I386InstallCheck.new
checker.run
