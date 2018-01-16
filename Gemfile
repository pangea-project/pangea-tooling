source 'https://gem.cache.pangea.pub'

# These are built by our geminabox tech
# https://github.com/blue-systems/pangea-geminabox
# and pushed into our gem cache for consumption. See Gemfile.git for info.
# These are actual gems in our cache, they mustn't have a git: argument.
source 'https://gem.cache.pangea.pub' do
  gem 'releaseme' # Not released as gem at all
end

gem 'aptly-api', '~> 0.8.2'
gem 'concurrent-ruby'
gem 'deep_merge', '~> 1.0'
gem 'docker-api', '~> 1.24' # Container.refresh! only introduced in 1.23
gem 'gir_ffi'
gem 'git'
gem 'gitlab'
gem 'htmlentities'
gem 'insensitive_hash'
gem 'jenkins_api_client'
gem 'jenkins_junit_builder', '~> 0.0.6' # Don't pickup v0.0.1
gem 'logger-colors'
gem 'mercurial-ruby'
gem 'net-sftp'
gem 'net-ssh', '~> 4.2.0'
gem 'net-ssh-gateway'
gem 'nokogiri'
gem 'octokit'
gem 'rake', '~> 12.0'
gem 'rugged'
gem 'tty-command'

# Git URI management
gem 'git_clone_url', '~> 2.0'
gem 'uri-ssh_git', '~> 2.0'

# Test logging as junit (also used at runtime for linting)
gem 'ci_reporter_test_unit'
gem 'ci_reporter_minitest'
gem 'test-unit', '~> 3.0'
gem 'minitest'

group :development, :test do
  gem 'droplet_kit'
  gem 'equivalent-xml'
  gem 'mocha'
  gem 'parallel_tests'
  gem 'rake-notes'
  gem 'rubocop', '>= 0.38'
  gem 'rubocop-checkstyle_formatter'
  gem 'ruby-progressbar'
  gem 'simplecov'
  gem 'simplecov-rcov'
  gem 'terminal-table'
  gem 'vcr', '>= 3.0.1'
  gem 'webmock'
end
