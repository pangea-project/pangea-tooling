# frozen_string_literal: true
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

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
          warn "Loading Build Log: #{uri}"
          io = open(uri)
          io.read.freeze
        end
      end
    end

    def initialize(*args)
      super
    end

    def setup
      @log = self.class.log_orig.dup
    end

    def result_listmissing
      @result_listmissing ||= Log::ListMissing.new.lint(@log)
    end

    def result_cmake
      @result_cmake ||= Log::CMake.new.tap do |cmake|
        cmake.load_include_ignores('build/debian/meta/cmake-ignore')
      end.lint(@log)
    end

    def result_dhmissing
      @result_dhmissing ||= Log::DHMissing.new.lint(@log)
    end

    %i[CMake ListMissing DHMissing].each do |klass_name|
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
