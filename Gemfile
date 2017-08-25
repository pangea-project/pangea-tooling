source 'https://gem.cache.pangea.pub'

# These are built by our geminabox tech
# https://github.com/blue-systems/pangea-geminabox
# and pushed into our gem cache for consumption. See Gemfile.git for info.
# These are actual gems in our cache, they mustn't have a git: argument.
source 'https://gem.cache.pangea.pub' do
  gem 'releaseme' # Not released as gem at all

  # Temporarily from git waiting for a release newer than 4.1.0. Once a newer
  # version is available this can move away from git again.
  # Also undo workaround in deploy_in_container.rake!
  # We want a version from our git builds, so restrict us to 4.1.0.x
  gem 'net-ssh', '~> 4.1.0.0'
end

gem 'aptly-api', '>= 0.5.0'
gem 'concurrent-ruby'
gem 'deep_merge', '~> 1.0'
gem 'docker-api', '~> 1.24' # Container.refresh! only introduced in 1.23
gem 'gir_ffi'
gem 'git'
gem 'gitlab'
gem 'htmlentities'
gem 'insensitive_hash'
gem 'jenkins_api_client'
gem 'jenkins_junit_builder'
gem 'logger-colors'
gem 'mercurial-ruby'
gem 'net-sftp'
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
gem 'test-unit', '~> 3.0'

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
