# frozen_string_literal: true
# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative '../../lib/dpkg'
require_relative '../../lib/lint/control'
require_relative '../../lib/lint/lintian'
require_relative '../../lib/lint/merge_marker'
require_relative '../../lib/lint/series'
require_relative '../../lib/lint/symbols'
require_relative '../lib/lint/result_test'

module Lint
  # Test static files.
  class TestPackaging < ResultTest
    def self.arch_all?
      DPKG::HOST_ARCH == 'amd64'
    end

    def setup
      @dir = 'build' # default dir
      # dir override per class
      @klass_to_dir = {
        Lintian => '.' # lint on the source's changes
      }
    end

    %i[Control Series Symbols Lintian].each do |klass_name|
      # Because this is invoked as a kind of blackbox test we'd have a really
      # hard time of testing lintian without either tangling the test up
      # with the build test or adding binary artifacts to the repo. I dislike
      # both so lets assume Lintian doesn't mess up its two function
      # API.
      next if ENV['PANGEA_TEST_NO_LINTIAN'] && klass_name == :Lintian
      # only run source lintian on amd64, the source is the same across arches.
      next if klass_name == :Lintian && !arch_all?

      %w[warnings informations errors].each do |meth_type|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def test_#{klass_name.downcase}_#{meth_type}
            log_klass = #{klass_name}
            assert_meth = "assert_#{meth_type}".to_sym
            dir = @klass_to_dir.fetch(log_klass, @dir)

            # NB: test-unit runs each test in its own instance, this means we
            # need to use a class variable as otherwise the cache wouldn't
            # persiste across test_ invocations :S
            result = @@result_#{klass_name} ||= log_klass.new(dir).lint
            send(assert_meth, result)
          end
        RUBY
      end
    end

    # FIXME: merge_marker disabled as we run after build and after build
    #   debian/ contains debian/tmp and others with binary artifacts etcpp..
    # def test_merge_markers
    #   assert_result MergeMarker.new("#{@dir}/debian").lint
    # end
  end
end
