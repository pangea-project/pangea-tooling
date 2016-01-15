require_relative '../lib/os'

# Test os
class OSTest < Test::Unit::TestCase
  def setup
    script_base_path = File.expand_path(File.dirname(__FILE__))
    script_name = File.basename(__FILE__, '.rb')
    @datadir = File.join(script_base_path, 'data', script_name)

    @orig_file = OS.instance_variable_get(:@file)
    OS.instance_variable_set(:@file, File.join(@datadir, method_name))
    OS.reset
  end

  def teardown
    OS.instance_variable_set(:@file, @orig_file)
    OS.reset
  end

  def test_parse
    ref = { :BUG_REPORT_URL => 'http://bugs.launchpad.net/ubuntu/',
           :HOME_URL => 'http://www.medubuntu.com/',
           :ID=>'ubuntu',
      :ID_LIKE=>"debian",
      :NAME=>"Medbuntu",
      :PRETTY_NAME=>"Medbuntu 15.01",
      :SUPPORT_URL=>"http://help.ubuntu.com/",
      :VERSION=>"15.01 (Magical Ponies)",
      :VERSION_ID=>"15.01"}
    assert_equal(ref, OS.to_h)
  end

  def test_consts
    assert_equal('Medbuntu', OS::NAME)
    assert_raise NameError do
      OS::FOOOOOOOOOOOOOOO
    end
  end
end
