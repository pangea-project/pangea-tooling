# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

class ProjectsFactory
  # Base class.
  class Base
    DEFAULT_PARAMS = {
      branch: 'kubuntu_unstable' # FIXME: kubuntu
    }.freeze

    class << self
      def from_type(type)
        return nil unless understand?(type)
        new(type)
      end

      def understand?(_type)
        false
      end
    end

    attr_accessor :default_params

    # Factorize from data. Defaults to data being an array.
    def factorize(data)
      # fail unless data.is_a?(Array)
      data.collect do |entry|
        next from_string(entry) if entry.is_a?(String)
        next from_hash(entry) if entry.is_a?(Hash)
        # FIXME: use a proper error here.
        raise 'unkown type'
      end.flatten.compact
    end

    private

    class << self
      private

      def reset!
        instance_variables.each do |v|
          next if v == :@mocha
          remove_instance_variable(v)
        end
      end
    end

    def initialize(type)
      @type = type
      @default_params = DEFAULT_PARAMS
    end

    def symbolize(hsh)
      Hash[hsh.map { |(key, value)| [key.to_sym, value] }]
    end

    # Joins path parts but skips empties and nils.
    def join_path(*parts)
      File.join(*parts.reject { |x| x.nil? || x.empty? })
    end

    # FIXME: this is a workaround until Project gets entirely redone
    def new_project(name:, component:, url_base:, branch:)
      # puts "new_project(#{name}, #{component}, #{url_base})"
      Project.new(name, component, url_base, branch: branch)
    end
  end
end
