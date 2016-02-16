require 'bundler/setup' # Make sure we have git gems available (ci_reporter...)

require 'simplecov'
require 'simplecov-rcov'

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::RcovFormatter
]

SimpleCov.start

require 'ci/reporter/rake/test_unit_loader'
