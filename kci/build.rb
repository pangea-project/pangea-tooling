#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require_relative '../ci-tooling/lib/kci'
require_relative '../ci-tooling/lib/retry'
require_relative '../lib/ci/containment'

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

JENKINS_PATH = '/var/lib/jenkins'.freeze
# This is a valid path on the host forwarded into the container.
# Necessary because we stored some configs in there.
OLD_TOOLING_PATH = "#{JENKINS_PATH}/tooling".freeze
# This is only a valid path in the container.
TOOLING_PATH = "#{JENKINS_PATH}/ci-tooling/kci".freeze
SSH_PATH = "#{JENKINS_PATH}/.ssh".freeze

COMPONENT = ENV.fetch('COMPONENT')
DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
JOB_NAME = ENV.fetch('JOB_NAME')

FileUtils.rm_rf(['_anchor-chain'] + Dir.glob('logs/*') + Dir.glob('build/*'))

binds = [
  "#{OLD_TOOLING_PATH}:#{OLD_TOOLING_PATH}",
  "#{SSH_PATH}:#{SSH_PATH}",
  "#{Dir.pwd}:#{Dir.pwd}"
]

c = CI::Containment.new(JOB_NAME,
                        image: CI::PangeaImage.new(:ubuntu, DIST),
                        binds: binds)
Retry.retry_it(times: 2, errors: [Docker::Error::NotFoundError]) do
  status_code = c.run(Cmd: ["#{TOOLING_PATH}/builder.rb", JOB_NAME, Dir.pwd])
  exit status_code unless status_code == 0
end

if DIST == KCI.latest_series
  Dir.chdir('packaging') do
    system("git push packaging HEAD:kubuntu_#{TYPE}")
  end
end

exec('/var/lib/jenkins/tooling3/ci-tooling/kci/ppa_copy_package.rb')
