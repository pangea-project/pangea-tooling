# frozen_string_literal: true
#
# Copyright (C) 2016-2018 Harald Sitter <sitter@kde.org>
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

require 'net/http'
require 'open-uri'

require_relative '../../lib/apt'
require_relative '../../lib/lsb'
require_relative '../../lib/retry'
require_relative '../../lib/nci'

# Neon CI specific helpers.
module NCI
  # NOTE: we talk to squid directly to reduce forwarding overhead, if we routed
  #   through apache we'd be spending between 10 and 25% of CPU on the forward.
  PROXY_URI = URI::HTTP.build(host: 'apt.cache.pangea.pub', port: 8000)

  module_function

  def add_repo_key!
    Retry.retry_it(times: 3, sleep: 8) do
      if Apt::Key.add('444D ABCF 3667 D028 3F89  4EDD E6D4 7362 5575 1E5D')
        return
      end
      raise 'Failed to import key'
    end
  end

  def setup_repo!
    setup_proxy!
    add_repo!
    if ENV.fetch('TYPE').include?('testing')
      puts 'Setting up apt preference for testing repository.'
      @testing_preference = Apt::Preference.new('pangea-neon-testing', content: <<-PREFERENCE)
Package: *
Pin: release l=Neon - Testing
Pin-Priority: 1001
    PREFERENCE
      @testing_preference.write
      ENV['TYPE'] = 'release'
      add_repo!
    end
    Retry.retry_it(times: 5, sleep: 4) { raise unless Apt.update }
    # Make sure we have the latest pkg-kde-tools, not whatever is in the image.
    raise 'failed to install deps' unless Apt.install(%w[pkg-kde-tools])
  end

  def setup_proxy!
    puts "Set proxy to #{PROXY_URI}"
    File.write('/etc/apt/apt.conf.d/proxy',
               "Acquire::http::Proxy \"#{PROXY_URI}\";")
  end

  def maybe_setup_apt_preference
    return unless ENV.fetch('DIST', NCI.current_series) == NCI.future_series
    puts 'Setting up apt preference.'
    @preference = Apt::Preference.new('pangea-neon', content: <<-PREFERENCE)
Package: *
Pin: release o=neon
Pin-Priority: 1001
    PREFERENCE
    @preference.write
  end

  def maybe_teardown_apt_preference
    return unless @preference
    puts 'Discarding apt preference.'
    @preference.delete
    @preference = nil
  end

  def maybe_teardown_testing_apt_preference
    return unless @testing_preference
    puts 'Discarding testing apt preference.'
    @testing_preference.delete
    @testing_preference = nil
  end

  class << self
    private

    def add_repo!
      add_repo_key!
      debline = format('deb http://archive.neon.kde.org/%<type>s %<dist>s main',
                       type: ENV.fetch('TYPE'),
                       dist: LSB::DISTRIB_CODENAME)
      Retry.retry_it(times: 5, sleep: 4) do
        raise 'adding repo failed' unless Apt::Repository.add(debline)
      end
    end
  end
end
