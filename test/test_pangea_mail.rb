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

require_relative '../ci-tooling/test/lib/testcase'

require_relative '../lib/pangea/mail'

require 'mocha/test_unit'

module Pangea
  class MailTest < TestCase
    def setup
      ENV['PANGEA_MAIL_CONFIG_PATH'] = "#{Dir.pwd}/mail.yaml"
    end

    def test_start
      config = {
        'smtp' => {
          'address' => 'fish.local',
          'port' => 587,
          'helo' => 'drax.kde.org',
          'user' => 'fancyuser',
          'secret' => 'pewpewpassword'
        }
      }
      File.write(ENV.fetch('PANGEA_MAIL_CONFIG_PATH'), YAML.dump(config))

      smtp = mock('smtp')
      # To talk to bluemchen we need to enable starttls
      smtp.expects(:enable_starttls_auto)
      # Starts a thingy
      session = mock('smtp.session')
      session.expects('dud')
      smtp.expects(:start).with('drax.kde.org', 'fancyuser', 'pewpewpassword', nil).yields(session)
      Net::SMTP.expects(:new).with('fish.local', 587).returns(smtp)

      SMTP.start(&:dud)
    end
  end
end
