require 'fileutils'
require 'tmpdir'

require_relative '../lib/debian/source'
require_relative 'lib/testcase'

# Test debian/source/format
class DebianSourceFormatTest < TestCase
  self.test_order = :defined

  def test_init_str
    assert_nothing_raised do
      Debian::Source::Format.new('1.0')
    end
  end

  def test_init_file
    Dir.mktmpdir(self.class.to_s) do |t|
      Dir.chdir(t) do
        file = 'debian/source/format'
        FileUtils.mkpath('debian/source')
        File.write(file, "1.0\n")

        # Read from a file path
        format = nil
        assert_nothing_raised do
          format = Debian::Source::Format.new(file)
        end
        assert_equal('1.0', format.version)

        # Read from a file object.
        format = nil
        assert_nothing_raised do
          format = Debian::Source::Format.new(File.open(file))
        end
        assert_equal('1.0', format.version)
      end
    end
  end

  def test_1
    format = Debian::Source::Format.new('1.0')
    assert_equal('1.0', format.version)
    assert_equal(nil, format.type)
  end

  def test_1_to_s
    str = '1.0'
    format = Debian::Source::Format.new(str)
    assert_equal(str, format.to_s)
  end

  def test_3_native
    format = Debian::Source::Format.new('3.0 (native)')
    assert_equal('3.0', format.version)
    assert_equal(:native, format.type)
  end

  def test_3_quilt
    format = Debian::Source::Format.new('3.0 (quilt)')
    assert_equal('3.0', format.version)
    assert_equal(:quilt, format.type)
  end

  def test_3_to_s
    str = '3.0 (quilt)'
    format = Debian::Source::Format.new(str)
    assert_equal(str, format.to_s)
  end

  def test_nil_init
    format = Debian::Source::Format.new(nil)
    assert_equal('1', format.version)
    assert_equal(nil, format.type)
  end
end

# Test debian/source
class DebianSourceTest < TestCase
  def test_init
    file = 'debian/source/format'
    FileUtils.mkpath('debian/source')
    File.write(file, "1.0\n")

    source = nil
    assert_nothing_raised do
      source = Debian::Source.new(Dir.pwd)
    end
    assert_not_nil(source.format)
  end
end
