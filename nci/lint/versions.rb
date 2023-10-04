# frozen_string_literal: true
# SPDX-FileCopyrightText: 2017-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'minitest'

require_relative '../../lib/apt'

require_relative 'cache_package_lister'
require_relative 'dir_package_lister'
require_relative 'package_version_check'
require_relative 'repo_package_lister'

# rubocop:disable Style/BeginBlock
BEGIN {
  # Use 4 threads in minitest parallelism, apt-cache is heavy, so we can't
  # bind this to the actual CPU cores. 4 Is reasonably performant on SSDs.
  ENV['MT_CPU'] ||= '4'
}
# rubocop:enable

module NCI
  # Very special test type.
  #
  # When in a pangea testing scope this test while aggregate will not
  # report any test methods (even if there are), this is to avoid problems
  # if/when we use minitest for pangea testing at large
  #
  # The purpose of this class is to easily get jenkins-converted data
  # out of a "test". Test in this case not being a unit test of the tooling
  # but a test of the package versions in our repo vs. on the machine we
  # are on (i.e. repo vs. ubuntu or other repo).
  # Before doing anything this class needs a lister set. A lister
  # implements a `packages` method which returns an array of objects with
  # `name` and `version` attributes describing the packages we have.
  # It then constructs checks if these packages' versions are greater than
  #  the ones we have presently available in the system.
  class VersionsTest < Minitest::Test
    parallelize_me!

    class << self
      # :nocov:
      def runnable_methods
        return if ENV['PANGEA_UNDER_TEST']

        super
      end
      # :nocov:

      def reset!
        @ours = nil
        @theirs = nil
      end

      def init(ours:, theirs:)
        # negative test to ensure tests aren't forgetting to run reset!
        raise 'ours mustnt be set twice' if @ours
        raise 'theirs mustnt be set twice' if @theirs

        @ours = ours.freeze
        @theirs = theirs.freeze

        Apt.update if Process.uid.zero? # update if root

        define_tests
      end

      # This is a tad meh. We basically need to meta program our test
      # methods as we'll want individual meths for each check so we get
      # this easy to read in jenkins, but since we only know which lister
      # to use once the program runs we'll have to extend ourselves lazily
      # via class_eval which allows us to edit the class from within
      # a class method.
      # The ultimate result is a bunch of test_pkg_version methods.
      def define_tests
        @ours.each do |pkg|
          their = @theirs.find { |x| x.name == pkg.name }
          class_eval do
            define_method("test_#{pkg.name}_#{pkg.version}") do
              PackageVersionCheck.new(ours: pkg, theirs: their).run
            end
          end
        end
      end
    end

    def initialize(name = self.class.to_s)
      # Override and provide a default param for name so our tests can
      # pass without too much internal knowledge.
      super
    end
  end
end
