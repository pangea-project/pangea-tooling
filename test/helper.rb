require 'bundler/setup' # Make sure we have git gems available (ci_reporter...)

require 'simplecov'
require 'simplecov-rcov'

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::RcovFormatter
]

SimpleCov.start

if ENV.include?('JENKINS_HOME')
  # Compatibility output to JUnit format.
  require 'ci/reporter/rake/test_unit_loader'

  # Force VCR to not ever record anything.
  require 'vcr'
  VCR.configure do |c|
    c.default_cassette_options = { record: :none }
  end
end
