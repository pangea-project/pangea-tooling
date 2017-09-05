# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require_relative 'lib/testcase'

require_relative '../lib/jenkins'

class AutoConfigJenkinsClientTest < TestCase
  def setup
    ENV['HOME'] = Dir.pwd
    p Dir.home
  end

  def standard_config
    {
      server_ip: 'yoloip.com',
      username: 'userino',
      password: 'passy',
      server_port: '443',
      ssl: true
    }
  end

  def test_init_defaults
    # init without any config
    stub_request(:get, 'http://kci.pangea.pub/')
      .to_return(status: 200, body: '')
    JenkinsApi::Client.new.get_root
  end

  def test_init_config
    # init from default path config
    Dir.mkdir('.config')
    File.write('.config/pangea-jenkins.json', JSON.generate(standard_config))

    stub_request(:get, 'https://yoloip.com/')
      .with(headers: { 'Authorization' => 'Basic dXNlcmlubzpwYXNzeQ==' })
      .to_return(status: 200, body: '', headers: {})

    JenkinsApi::Client.new.get_root
  end

  def test_init_config_path
    # init from custom path config
    File.write('fancy-config.json', JSON.generate(standard_config))

    stub_request(:get, 'https://yoloip.com/')
      .with(headers: { 'Authorization' => 'Basic dXNlcmlubzpwYXNzeQ==' })
      .to_return(status: 200, body: '', headers: {})

    JenkinsApi::Client.new(config_file: 'fancy-config.json').get_root
  end
end
