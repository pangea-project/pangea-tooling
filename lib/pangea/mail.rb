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

require 'yaml'
require 'net/smtp'

module Pangea
  # Net/SMTP wrapper using pangea config to initialize.
  class SMTP
    attr_reader :address
    attr_reader :port
    attr_reader :helo
    attr_reader :user
    attr_reader :secret
    attr_reader :authtype

    class << self
      def config_path
        File.expand_path(ENV.fetch('PANGEA_MAIL_CONFIG_PATH'))
      end

      def start(path = config_path, &block)
        new(path).start(&block)
      end
    end

    def initialize(path = self.class.config_path)
      data = YAML.load_file(path)
      data.fetch('smtp').each do |key, value|
        value = value.to_sym if value && value[0] == ':'
        value = nil if value == 'nil' # coerce nilly strings
        instance_variable_set("@#{key}".to_sym, value)
      end
    end

    def start(&block)
      smtp = Net::SMTP.new(address, port)
      smtp.enable_starttls_auto
      smtp.start(helo, user, secret, authtype, &block)
      # No finish as we expect a block which auto-finishes upon return
    end
  end
end
