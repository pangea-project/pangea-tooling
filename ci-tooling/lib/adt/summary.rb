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

module ADT
  # An autopkgtest summary.
  class Summary
    attr_reader :path
    attr_reader :entries

    module Result
      PASS = :pass
      FAIL = :fail
    end.freeze

    # A Summary Entry.
    class Entry
      attr_reader :name
      attr_reader :result
      attr_reader :detail

      REGEX = /(?<name>[^\s]+)\s+(?<result>[^\s]+)\s?(?<detail>.*)/

      def self.from_line(line)
        data = line.match(REGEX)
        send(:new, data[:name], data[:result], data[:detail])
      end

      private

      def initialize(name, result, detail)
        @name = name
        @result = case result
                  when 'PASS' then Summary::Result::PASS
                  when 'FAIL' then Summary::Result::FAIL
                  else raise "unknown result type #{result}"
                  end
        @detail = detail
      end
    end

    def self.from_file(file)
      send(:new, file)
    end

    private

    def initialize(file)
      @path = File.absolute_path(file)
      @entries = []
      parse!
    end

    def parse!
      data = File.read(@path)
      data.split($/).each do |line|
        line.strip!
        next if line.empty?
        @entries << Entry.from_line(line)
      end
    end
  end
end
