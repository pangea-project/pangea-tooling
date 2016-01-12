require 'test/unit'
require_relative '../lib/shebang'

class ParseTest < Test::Unit::TestCase
  def test_syntax
    basedir = File.dirname(File.expand_path(File.dirname(__FILE__)))
    Dir.chdir(basedir)

    source_dirs = %w(
      bin
      dci
      kci
      git-monitor
      jenkins-jobs
      lib
      nci
      mci
      mobster
      test
      ci-tooling/dci
      ci-tooling/kci
      ci-tooling/lib
      ci-tooling/mci
      ci-tooling/nci
      ci-tooling/test
    )
    source_dirs.each do |source_dir|
      Dir.glob("#{source_dir}/**/*.rb").each do |file|
        parse_ruby(file)
      end
      Dir.glob("#{source_dir}/**/*.sh").each do |file|
        parse_shell(file)
      end
    end

    # Do not recurse the main dir.
    Dir.glob('*.rb').each do |file|
      parse_ruby(file)
    end
    Dir.glob('*.sh').each do |file|
      parse_shell(file)
    end
  end

  private

  def parse_bash(file)
    assert(system("bash -n #{file}"), "#{file} not parsing as bash.")
  end

  def parse_ruby(file)
    assert(system("ruby -c #{file} 1> /dev/null"),
           "#{file} not parsing as ruby.")
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
