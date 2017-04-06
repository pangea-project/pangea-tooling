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

require 'open-uri'

require_relative '../../lib/lint/log'
require_relative '../../lib/retry'
require_relative '../lib/lint/result_test'

module Lint
  # Test build log data.
  # @note needs LOG_URL defined!
  class TestLog < ResultTest
    class << self
      def log_orig
        @log_orig ||= Retry.retry_it(times: 2, sleep: 8) do
          uri = ENV.fetch('LOG_URL')
          open(uri).read.freeze
        end
      end
    end

    def initialize(*args)
      super
    end

    def setup
      @log = self.class.log_orig.dup
    end

    def result_lintian
      @result_lintian ||= Log::Lintian.new.lint(@log)
    end

    def result_listmissing
      @result_listmissing ||= Log::ListMissing.new.lint(@log)
    end

    def result_cmake
      @result_cmake ||= Log::CMake.new.tap do |cmake|
        cmake.load_include_ignores('build/debian/meta/cmake-ignore')
        cmake.ignores << CI::IncludePattern.new('Qt5TextToSpeech')
      end.lint(@log)
    end

    %i[CMake Lintian ListMissing].each do |klass_name|
      %w[warnings informations errors].each do |meth_type|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def test_#{klass_name.downcase}_#{meth_type}
            assert_meth = "assert_#{meth_type}".to_sym
            send(assert_meth, result_#{klass_name.downcase})
          end
        RUBY
      end
    end
  end
end
