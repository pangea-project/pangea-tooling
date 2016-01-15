#!/usr/bin/env ruby

require_relative 'lib/setup_repo'

NCI.setup_repo!

require_relative '../ci/sourcer.rb'
