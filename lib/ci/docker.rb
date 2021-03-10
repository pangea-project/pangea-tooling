# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2016-2017 Rohan Garg <rohan@garg.io>
# SPDX-FileCopyrightText: 2017-2021 Harald Sitter <sitter@kde.org>

require 'docker'

class Docker::Connection
  def podman?
    # We don't use podman. Meanwhile docker-api 2.1 would make a /version request in this method that'd
    # require re-recording of our VCR cassettes. Instead always return false.
    false
  end
end

# Reset connection in order to pick up any connection options one might set
# after requiring this file
Docker.reset_connection!
