require 'test/unit'
require 'tmpdir'

require_relative '../schroot-scripts/lib/profile'

class SchrootProfileTest < Test::Unit::TestCase
  def setup
    @datadir = "#{File.expand_path(File.dirname(__FILE__))}/data/#{File.basename(__FILE__, '.rb')}"
  end

  def data(path)
    index = 0
    caller = ''
    until caller.start_with?('test_')
      caller = caller_locations(index, 1)[0].label
      index += 1
    end
    "#{@datadir}/#{caller}/#{path}"
  end

  def default_profile
    SchrootProfile.new(name: 'name',
                       series: 'utopic',
                       arch: 'amd64',
                       directory: '/srv',
                       users: %w(me you),
                       workspace: '/var')
  end

  def test_init
    profile = default_profile
    assert_equal('name', profile.name)
    assert_equal('utopic', profile.series)
    assert_equal('amd64', profile.arch)
    assert_equal('name (utopic/amd64)', profile.description)
    assert_equal('/srv', profile.directory)
    assert_equal('me,you', profile.users)
    assert_equal('/var', profile.workspace)
  end

  def test_render
    profile = default_profile
    render = profile.render(data('file'))
    assert_equal(File.read(data('_ref')), render)
  end

  def test_deploy_config
    profile = default_profile
    template = data('file')
    Dir.mktmpdir do |tmpdir|
      profile.deploy_config(template, tmpdir)
      tmpfile = "#{tmpdir}/#{File.basename(template)}"
      assert(File.exist?(tmpfile))
      assert_equal(File.read(data('_ref')), File.read(tmpfile))
    end
  end

  def test_rewire_config
    profile = default_profile
    template = data('file')
    Dir.mktmpdir do |tmpdir|
      tmpfile = "#{tmpdir}#{File.basename(template)}"
      FileUtils.cp(template, tmpfile)
      assert_equal(File.read(template), File.read(tmpfile))
      profile.rewire_config(tmpfile)
      assert_not_equal(File.read(template), File.read(tmpfile))
      assert_equal(File.read(data('_ref')), File.read(tmpfile))
    end
  end

  def test_deploy_profile
    profile = default_profile
    template_dir = data('template')
    Dir.mktmpdir do |tmpdir|
      profile.deploy_profile(template_dir, tmpdir)
      tmpdir_content = Dir.chdir(tmpdir) { Dir['**/**'] }
      tmpdir_content.sort!
      refdir = data('_ref')
      refdir_content = Dir.chdir(refdir) { Dir['**/**'] }
      refdir_content.sort!
      assert_equal(refdir_content, tmpdir_content)
      refdir_content.each do |file|
        reffile = "#{refdir}/#{file}"
        tmpfile = "#{tmpdir}/#{file}"
        next if File.directory?(reffile)
        assert_equal(File.read(reffile), File.read(tmpfile))
      end
    end
  end
end
