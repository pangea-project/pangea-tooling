# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

require 'net/ping/tcp'
require 'open-uri'

require_relative '../../lib/retry'

module NCI
  # Mirror helpers.
  module Mirrors
    # Wrap around Net::Ping and pick a suitable time.
    # This class uses Net::Ping::TCP as ICMP would require root, equally it
    # doesn't use the ping tool as that would require us to parse stdout, which
    # is mighty ugh.
    class Pinger
      def initialize(url)
        uri = URI.parse(url)
        @tcp = Net::Ping::TCP.new(uri.host, uri.port, 1)
      end

      # @return [Float] best time
      # @return [nil] on ping error no time, but nil, is returned
      def best_time
        puts "Pinging #{@tcp.host}"
        time = times.sort[0]
        puts "____ #{time}"
        return time
      rescue StandardError => e
        puts "Ping failed => #{e}"
        return nil
      end

      private

      def times
        Array.new(2) do
          @tcp.ping
          raise @tcp.exception if @tcp.exception
          sleep 0.2
          @tcp.duration
        end
      end
    end

    class << self
      # @return best mirror URL to replace archive.ubuntu.com
      def best
        @best ||= begin
          durations = list.inject({}) do |hash, url|
            time = Pinger.new(url).best_time
            next hash unless time
            hash.merge!(time => url)
          end
          durations.sort.to_h.values[0]
        end
      end

      def reset!
        @best = nil
        @list = nil
      end

      private

      def list
        @list ||= begin
          data = nil
          Retry.retry_it(times: 2) do
            data = open('http://mirrors.ubuntu.com/mirrors.txt').read
          end
          data = data.split($/).compact
          data.reject! { |x| x.include?('mirror.23media.de/ubuntu') }
          data.freeze
        end
      end
    end
  end
end
