require_relative 'lib/testcase'
require_relative '../lib/xci'

module BogusNameWithoutFile
  extend XCI
end

# Test xci
class XCITest < TestCase
  def test_fail_on_missing_config
    assert_raise RuntimeError do
      BogusNameWithoutFile.series
    end
  end
end
