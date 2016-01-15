require_relative '../lib/lsb'

# Test lsb
class LSBTest < Test::Unit::TestCase
  def setup
    script_base_path = File.expand_path(File.dirname(__FILE__))
    script_name = File.basename(__FILE__, '.rb')
    @datadir = File.join(script_base_path, 'data', script_name)

    @orig_file = LSB.instance_variable_get(:@file)
    LSB.instance_variable_set(:@file, File.join(@datadir, method_name))
    LSB.reset
  end

  def teardown
    LSB.instance_variable_set(:@file, @orig_file)
    LSB.reset
  end

  def test_parse
    ref = { DISTRIB_ID: 'Mebuntu',
            DISTRIB_RELEASE: '15.01',
            DISTRIB_CODENAME: 'codename',
            DISTRIB_DESCRIPTION: 'Mebuntu CodeName (development branch)'
    }
    assert_equal(ref, LSB.to_h)
  end

  def test_consts
    assert_equal('Mebuntu', LSB::DISTRIB_ID)
    assert_equal('codename', LSB::DISTRIB_CODENAME)
    assert_raise NameError do
      LSB::FOOOOOOOOOOOOOOO
    end
  end
end
