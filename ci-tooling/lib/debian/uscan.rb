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

require 'nokogiri'

module Debian
  class UScan
    # State identifier strings.
    module States
      NEWER_AVAILABLE = 'Newer version available'.freeze
      UP_TO_DATE = 'up to date'.freeze
      DEBIAN_NEWER = 'Debian version newer than remote site'.freeze
      OLDER_ONLY = 'only older package available'.freeze

      # Compatiblity map because uscan randomly changes the bloody strings.
      # @param [String] string actual uscan string we want to map
      # @return [String] const representation of that string
      def self.map(string)
        case string
        when 'newer package available'
          NEWER_AVAILABLE
        else
          string
        end
      end
    end

    # UScan's debian external health status format parser.
    class DEHS
      class ParseError < StandardError; end

      # A Package status report.
      class Package
        attr_reader :name
        attr_reader :status
        attr_reader :upstream_version
        attr_reader :upstream_url

        def initialize(name)
          @name = name
        end

        # Sets instance variable according to XML element.
        def _apply_element(element)
          instance_variable_set(to_instance(element.name), element.content)
        end

        private

        def to_instance(str)
          "@#{str.tr('-', '_')}".to_sym
        end
      end

      class << self
        def parse_packages(xml)
          packages = []
          Nokogiri::XML(xml).root.elements.each do |element|
            if element.name == 'package'
              next packages << Package.new(element.content)
            end
            verify_status(element)
            packages[-1]._apply_element(element)
          end
          packages
        end

        private

        def verify_status(element)
          return unless element.name == 'status'
          # Edit the content to the mapped value, so we always get consistent
          # strings.
          element.content = States.map(element.content)
          return if States.constants.any? do |const|
            States.const_get(const) == element.content
          end
          raise ParseError, "Unmapped status: '#{element.content}'"
        end
      end
    end
  end
end
