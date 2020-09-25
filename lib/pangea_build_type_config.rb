# frozen_string_literal: true

# SPDX-FileCopyrightText: 2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

# Whether to mutate build type away from debian native.
module PangeaBuildTypeConfig
  class << self
    def release_lts?
      ENV.fetch('TYPE', '') == 'release-lts'
    end

    def override?
      enabled? && ubuntu? && (release_lts? || arm?)
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
