#!/usr/bin/env ruby
require 'tmpdir'
require 'fileutils'

require_relative '../lib/ci/build_binary'
require_relative 'lib/setup_repo'

DCI.setup_env!
DCI.setup_repo!

@workspace = Dir.pwd

Dir.mktmpdir do |tmpdir|
  FileUtils.cp_r("#{@workspace}/.", tmpdir, verbose: true)
  Dir.chdir(tmpdir) do
    builder = CI::PackageBuilder.new
    builder.build
  end

  result_dir = "#{tmpdir}/result"
  if Dir.exist?(result_dir)
    FileUtils.cp_r(result_dir, @workspace, verbose: true)
  end
end
