# frozen_string_literal: true
# SPDX-License-Identifier: CC0-1.0
# SPDX-FileCopyrightText: none

source 'https://gem.cache.pangea.pub'

# These are built by our geminabox tech
# https://github.com/pangea-project/pangea-geminabox
# and pushed into our gem cache for consumption. See Gemfile.git for info.
# These are actual gems in our cache, they mustn't have a git: argument.
gem 'releaseme' # Not released as gem at all
gem 'jenkins_junit_builder' # Forked because upstream depends on an ancient nokogiri that doesn't work with ruby3

gem 'activesupport', '>= 6.0.3.1'
gem 'aptly-api', '~> 0.10'
gem 'bencode' # for torrent generation
gem 'concurrent-ruby'
gem 'deep_merge', '~> 1.0'
gem 'docker-api', '~> 2.0' # Container.refresh! only introduced in 1.23
gem 'faraday' # implicit dep but also explicitly used in e.g. torrent tech
gem 'gir_ffi', '0.14.1'
gem 'git'
gem 'gitlab'
gem 'htmlentities'
gem 'insensitive_hash'
gem 'jenkins_api_client'
gem 'logger-colors'
gem 'net-ftp-list'
gem 'net-sftp'
gem 'net-ssh', '>= 7.0.0.beta1'
gem 'net-ssh-gateway'
gem 'nokogiri'
gem 'octokit'
gem 'rake', '~> 13.0'
gem 'rugged'
gem 'sigdump'
gem 'tty-command'
gem 'tty-pager'
gem 'tty-prompt'
gem 'tty-spinner'
gem 'webrick'

# Git URI management
gem 'git_clone_url', '~> 2.0'
gem 'uri-ssh_git', '~> 2.0'

# Test logging as junit (also used at runtime for linting)
gem 'ci_reporter_minitest'
gem 'ci_reporter_test_unit'
gem 'minitest'
gem 'test-unit', '~> 3.0'

# Hack. jenkins_api_client depends on mixlib-shellout which depends on
# chef-utils and that has excessive version requirements for ruby because chef
# has an entire binary distro bundle that allows them to pick whichever ruby.
# Instead lock chef-utils at a low enough version that it will work for all our
# systems (currently that is at least bionic with ruby 2.5).
# jenkins_api_client literally just uses it as a glorified system() so the
# entire dep is incredibly questionable.
# Anyway, this lock should be fine to keep so long as the jenkins api client
# doesn't go belly up.
gem 'chef-utils', '<= 13'
# We are also locking this for now becuase this is a working version and
# the dep that pulls in chef-utils. This way we can ensure the version
# combination will work.
# NOTE: when either of the constraints conflict with another constraint
#   of one of the gems this needs revisiting. Either we can move to a newer
#   version because bionic is no longer used on any server or we need a more
#   creative solution.
gem 'mixlib-shellout', '~> 3.1.0'

group :development, :test do
  gem 'droplet_kit'
  gem 'equivalent-xml'
  gem 'mocha', '~> 1.9'
  gem 'parallel_tests'
  gem 'rake-notes'
  gem 'rubocop', '~> 1.10.0'
  gem 'rubocop-checkstyle_formatter'
  gem 'ruby-progressbar'
  gem 'simplecov'
  gem 'simplecov-rcov'
  gem 'terminal-table'
  gem 'tty-logger'
  gem 'vcr', '>= 3.0.1'
  gem 'webmock'
end
