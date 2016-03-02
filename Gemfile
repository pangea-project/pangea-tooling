source 'https://rubygems.org'

gem 'aptly-api'
gem 'deep_merge', '~> 1.0'
gem 'docker-api', '~> 1.24' # Container.refresh! only introduced in 1.23
gem 'git'
gem 'jenkins_api_client'
gem 'logger-colors'
gem 'oauth', '~> 0.4'
gem 'octokit'
gem 'gitlab',
    git: 'https://github.com/NARKOZ/gitlab',
    branch: 'master'
gem 'net-ssh-gateway'

# Git URI management
gem 'git_clone_url', '~> 2.0'
gem 'uri-ssh_git', '~> 2.0'

# Test logging as junit (also used at runtime for linting)
gem 'test-unit', '~> 3.0'
gem 'ci_reporter_test_unit',
     git: 'https://github.com/apachelogger/ci_reporter_test_unit',
     branch: 'test-unit-3'

group :development, :test do
  gem 'equivalent-xml'
  gem 'mocha'
  gem 'net-scp'
  gem 'parallel_tests'
  gem 'rack'
  gem 'rake'
  gem 'rake-notes'
  gem 'rubocop', '>= 0.37'
  gem 'rubocop-checkstyle_formatter'
  gem 'rugged'
  gem 'ruby-progressbar'
  gem 'simplecov'
  gem 'simplecov-rcov'
  gem 'vcr', '>= 3.0.1'
  gem 'webmock'
end

group :s3 do
  gem 'aws-sdk-v1'
  gem 'nokogiri'
end
