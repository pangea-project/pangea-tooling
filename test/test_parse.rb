# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2015-2021 Harald Sitter <sitter@kde.org>

require_relative 'lib/testcase'

require 'yaml'

require 'tty/command'
require_relative '../lib/shebang'

class ParseTest < TestCase
  SOURCE_DIRS = %w[
    bin
    dci
    jenkins-jobs
    lib
    nci
    overlay-bin
    test
    xci
  ].freeze

  attr_reader :cmd

  class << self
    def all_files(filter: '')
      files = SOURCE_DIRS.collect do |source_dir|
        Dir.glob("#{source_dir}/**/*#{filter}").collect do |file|
          file
        end
      end

      # Do not recurse the main dir.
      files += Dir.glob("*#{filter}")
      files.flatten.uniq.compact
    end

    def all_sh
      all_files(filter: '.sh')
    end

    def all_ruby
      all_files(filter: '.rb')
    end
  end

  def setup
    @cmd = TTY::Command.new(uuid: false, printer: :null)

    basedir = File.dirname(__dir__)
    Dir.chdir(basedir)
  end

  all_sh.each do |file|
    define_method("test_parse_shell: #{file}".to_sym) do
      parse_shell(file)
    end
  end

  def test_ruby
    # Rubocop implies valid parsing and then we also want to enforce that
    # no tab indentation was used.
    # NB: rubocop has a default config one can force, but it gets the intended
    #   version from .ruby-version (which is managed by rbenv for example), so
    #   it isn't strictly speaking desirable to follow that as it would make the
    #   test pass even though it should not. As such we make a temporary config
    #   forcing the value we want.
    config = YAML.dump('AllCops' => { 'TargetRubyVersion' => '2.5' })
    File.write('config.yaml', config)
    res = cmd.run!('rubocop', '--only', 'Layout/IndentationStyle',
                   '--cache', 'false',
                   '--config', "#{Dir.pwd}/config.yaml",
                   *self.class.all_ruby)
    assert(res.success?, <<~ERR)
      ==stdout==
      #{res.out}

      ==stderr==
      #{res.err}
    ERR
  end

  private

  def parse_bash(file)
    assert(system("bash -n #{file}"), "#{file} not parsing as bash.")
  end

  def parse_sh(file)
    assert(system("sh -n #{file}"), "#{file} not parsing as sh.")
  end

  def parse_shell(file)
    shebang = Shebang.new(File.open(file).readline)
    case shebang.parser
    when 'sh'
      parse_sh(file)
    else # assume bash
      # DEBUG
      # if shebang.valid
      #   warn '  shell type unknown, falling back to bash'
      # else
      #   warn '  shebang invalid, falling back to bash'
      # end
      parse_bash(file)
    end
  end
end
