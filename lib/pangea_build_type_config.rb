# frozen_string_literal: true

# SPDX-FileCopyrightText: 2020-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

# Whether to mutate build type away from debian native.
module PangeaBuildTypeConfig
  class << self
    # Whether to override the build type at all (i.e. strip dpkg-buildflags)
    def override?
      enabled? && ubuntu? && arm?
    end

    # Whether this build should be run as release build (i.e. no ddebs or symbols)
    def release_build?
      false # we currently have nothing that qualifies. previously LTS was a type of this
    end

    private

    def enabled?
      !ENV.key?('PANGEA_NO_BUILD_TYPE')
    end

    def ubuntu?
      File.read('/etc/os-release').include?('ubuntu')
    end

    def arm?
      %w[armhf arm64].any? { |x| ENV.fetch('NODE_LABELS', '').include?(x) }
    end
  end
end
