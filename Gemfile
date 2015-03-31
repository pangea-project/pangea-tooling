source 'https://rubygems.org'

gem 'docker-api'
gem 'git'
gem 'logger-colors'
gem 'jenkins_api_client'
gem 'oauth'

group :development, :test do
  gem 'ci_reporter_test_unit',
      git: 'https://github.com/apachelogger/ci_reporter_test_unit',
      branch: 'test-unit-3'
  gem 'equivalent-xml'
  gem 'rake'
  gem 'simplecov'
  gem 'simplecov-rcov'
  gem 'test-unit', '>= 3.0'
  gem 'rack'
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter'
  gem 'vcr'
  gem 'webmock'
end

group :s3 do
  gem 'aws-sdk-v1'
  gem 'nokogiri'
end
