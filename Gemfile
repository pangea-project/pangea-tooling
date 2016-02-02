source 'https://rubygems.org'

gem 'aptly-api'
gem 'docker-api', '~> 1.24' # Container.refresh! only introduced in 1.23
gem 'git'
gem 'jenkins_api_client'
gem 'logger-colors'
gem 'oauth'
gem 'octokit'
gem 'net-ssh-gateway'

# Git URI management
gem 'git_clone_url', '~> 2.0'
gem 'uri-ssh_git', '~> 2.0'

group :development, :test do
  gem 'ci_reporter_test_unit',
      git: 'https://github.com/apachelogger/ci_reporter_test_unit',
      branch: 'test-unit-3'
  gem 'equivalent-xml'
  gem 'net-scp'
  gem 'rack'
  gem 'rake'
  gem 'rake-notes'
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter'
  gem 'ruby-progressbar'
  gem 'simplecov'
  gem 'simplecov-rcov'
  gem 'test-unit', '>= 3.0'
  gem 'vcr', '~> 2'
  gem 'webmock'
end

group :s3 do
  gem 'aws-sdk-v1'
  gem 'nokogiri'
end
