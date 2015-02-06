require 'test/unit'
require 'tmpdir'

require_relative '../kci/lxc'

class LxcTest < Test::Unit::TestCase
  self.test_order = :defined

  def setup
    @tmpdir = Dir.mktmpdir(self.class.to_s)
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir('/')
    FileUtils.rm_rf(@tmpdir)
  end

  def test_config_path
    assert_equal(`lxc-config lxc.lxcpath`.strip, LXC.path)
    LXC.path = '/yolo'
    assert_equal('/yolo', LXC.path)
  end
end
