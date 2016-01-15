require_relative 'lib/testcase'

require_relative '../lib/mutable-uri/generic'

# Test git-uri/generic
module MutableURI
  class WriteTemplateTest < Generic
    def read_uri_template
      URI.parse('')
    end
  end

  class ReadTemplateTest < Generic
    def write_uri_template
      URI.parse('')
    end
  end

  class InstanceTest < Generic
    def initialize; end
  end

  class GenericTest < TestCase
    def test_rw_nil
      assert_raise do
        WriteTemplateTest.new(URI.parse(''))
      end
      assert_raise do
        ReadTemplateTest.new(URI.parse(''))
      end
    end

    def test_instance_variables
      uri = InstanceTest.new
      assert_raise Generic::NoURIError do
        uri.readable
      end
      assert_raise Generic::NoURIError do
        uri.writable
      end
    end
  end
end
