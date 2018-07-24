# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

require_relative 'pipelinejob'

# openqa installation test
class OpenQAInstallJob < PipelineJob
  attr_reader :series
  attr_reader :edition

  def initialize(series:, type:)
    @series = series
    @edition = edition_from_type(type)
    name = "openqa_#{series}_#{edition}_installation"
    name += "_#{suffix}" if suffix
    super(name, job_template: 'openqa_install',
                template: '') # there is no script template, it is in-repo
  end

  def script_path
    'Jenkinsfile'
  end

  def env
    []
  end

  def suffix
    match = self.class.to_s.match(/OpenQAInstall(?<suffix>\w+)Job/)
    return nil unless match
    match[:suffix].downcase
  end

  private

  def edition_from_type(type)
    {
      'unstable' => 'devedition-gitunstable',
      'stable' => 'devedition-gitstable',
      'release' => 'useredition',
      'release-lts' => 'useredition-lts'
    }.fetch(type)
  end
end

# openqa secureboot installation test
class OpenQAInstallSecurebootJob < OpenQAInstallJob
  def script_path
    'Jenkinsfile.secureboot'
  end
end

# openqa offline installation test
class OpenQAInstallOfflineJob < OpenQAInstallJob
  def env
    %w[OPENQA_INSTALLATION_OFFLINE=1]
  end
end

# openqa bios installation test
class OpenQAInstallBIOSJob < OpenQAInstallJob
  def env
    %w[OPENQA_BIOS=1]
  end
end

# openqa oem installation test
class OpenQAInstallOEMJob < OpenQAInstallJob
  def script_path
    'Jenkinsfile.oem'
  end
end

# openqa nonenglish installation test
class OpenQAInstallNonEnglishJob < OpenQAInstallJob
  def env
    %w[OPENQA_INSTALLATION_NONENGLISH=1]
  end
end
