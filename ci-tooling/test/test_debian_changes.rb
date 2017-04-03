require_relative '../lib/debian/changes'
require_relative 'lib/testcase'

# Test debian .changes
class DebianChangesTest < TestCase
  def setup
    # Change into our fixture dir as this stuff is read-only anyway.
    Dir.chdir(@datadir)
  end

  def test_source
    c = Debian::Changes.new(data)
    c.parse!

    assert_equal(3, c.fields['checksums-sha1'].size)
    sum = c.fields['checksums-sha1'][2]
    assert_equal('d433a01bf5fa96beb2953567de96e3d49c898cce', sum.sum)
    # FIXME: should be a number maybe?
    assert_equal('2856', sum.size)
    assert_equal('gpgmepp_15.08.2+git20151212.1109+15.04-0.debian.tar.xz',
                 sum.file_name)

    assert_equal(3, c.fields['checksums-sha256'].size)
    sum = c.fields['checksums-sha256'][2]
    assert_equal('7094169ebe86f0f50ca145348f04d6ca7d897ee143f1a7c377142c7f842a2062',
                 sum.sum)
    # FIXME: should be a number maybe?
    assert_equal('2856', sum.size)
    assert_equal('gpgmepp_15.08.2+git20151212.1109+15.04-0.debian.tar.xz',
                 sum.file_name)

    assert_equal(3, c.fields['files'].size)
    file = c.fields['files'][2]
    assert_equal('fa1759e139eebb50a49aa34a8c35e383', file.md5)
    # FIXME: should be a number maybe?
    assert_equal('2856', file.size)
    assert_equal('libs', file.section)
    assert_equal('optional', file.priority)
    assert_equal('gpgmepp_15.08.2+git20151212.1109+15.04-0.debian.tar.xz',
                 file.name)
  end

  def test_binary_split
    c = Debian::Changes.new(data)
    c.parse!
    binary = c.fields.fetch('Binary')
    assert(binary)
    assert_equal(3, binary.size) # Properly split?
    assert_equal(%w(libkf5gpgmepp5 libkf5gpgmepp-pthread5 libkf5gpgmepp-dev).sort,
                 binary.sort)
  end
end
