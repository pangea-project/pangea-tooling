# frozen_string_literal: true
#
# Copyright (C) 2015-2017 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'test/unit'

require 'tty/command'
require_relative '../lib/shebang'

class ParseTest < Test::Unit::TestCase
  SOURCE_DIRS = %w[
    bin
    dci
    jenkins-jobs
    lib
    nci
    mci
    test
    ci-tooling/dci
    ci-tooling/lib
    ci-tooling/mci
    ci-tooling/nci
    ci-tooling/test
    overlay-bin
  ]

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
    res = cmd.run!('rubocop', '--only', 'Layout/Tab', '--force-default-config',
                   *self.class.all_ruby)
    assert(res.success?, res.out)
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
    when 'bash'
      parse_bash(file)
    when 'sh'
      parse_sh(file)
    else
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
