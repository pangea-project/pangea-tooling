require_relative '../lib/qml/ignore_rule'
require_relative 'lib/testcase'

# Test qml ignore rules
class QMLIgnoreRuleTest < TestCase
  def new_rule(identifier, version = nil)
    QML::IgnoreRule.send(:new, identifier, version)
  end

  def new_mod(id, version = nil)
    QML::Module.new(id, version)
  end

  def test_init
    assert_raise RuntimeError do
      new_rule(nil, nil)
    end
    assert_raise RuntimeError do
      new_rule('id', 1.0) # Float version
    end
    r = new_rule('id', 'version')
    assert_equal('id', r.identifier)
    assert_equal('version', r.version)
  end

  # @return [Array] used as send_array for assert_send
  def send_identifier(id, mod)
    [new_rule(id), :match_identifier?, mod]
  end

  def assert_identifier(id, mod, message = nil)
    assert_send(send_identifier(id, mod), message)
  end

  def assert_not_identifier(id, mod, message = nil)
    assert_not_send(send_identifier(id, mod), message)
  end

  def test_match_id
    mod = QML::Module.new('org.kde.plasma.abc')
    truthies = %w(
      org.kde.plasma.*
      org.kde.plasma.abc
      org.kde.plasma.abc*
    )
    truthies.each { |t| assert_identifier(t, mod) }
    falsies = %w(
      org.kde.plasma
      org.kde.plasma.abc.*
    )
    falsies.each { |f| assert_not_identifier(f, mod) }
  end

  def test_match_version
    id = 'org.kde.plasma.abc'
    mod = QML::Module.new(id, '1.0')
    assert_send([new_rule(id, '1.0'), :match_version?, mod])
    assert_send([new_rule(id, nil), :match_version?, mod])
    assert_not_send([new_rule(id, '2.0'), :match_version?, mod])
  end

  def test_ignore
    id = 'org.kde.plasma'
    version = '2.0'
    r = new_rule(id, version)
    assert_false(r.ignore?(new_mod('org.kde', version)))
    assert_false(r.ignore?(new_mod(id, '1.0')))
    assert_true(r.ignore?(new_mod(id, version)))
    r = new_rule(id, nil) # nil version should match anything
    assert_true(r.ignore?(new_mod(id, version)))
    assert_true(r.ignore?(new_mod(id, '1.0')))
    assert_true(r.ignore?(new_mod(id, nil)))
  end

  def test_read
    r = QML::IgnoreRule.read(data)
    expected = {
      'org.kde.kwin' => '1.0',
      'org.kde.plasma' => nil,
      'org.kde.plasma.abc' => '2.0',
      'org.kde.plasma.*' => '1.0'
    }
    r.each do |rule|
      next unless expected.keys.include?(rule.identifier)
      version = expected.delete(rule.identifier)
      assert_equal(version, rule.version, 'Versions do not match')
    end
    assert_empty(expected, "Did not get all expected rules")
  end

  def test_compare
    # comparing defers to ignore, so we only check that compare actually calls
    # ignore as intended.
    id = 'org.kde.plasma'
    version = '2.0'
    m = new_mod(id, version)
    r = new_rule(id, nil)
    assert_equal(r == m, r.ignore?(m))
    # Comparing with a string on the other hand should defer to super and return
    # false.
    assert_not_equal(r == id, r.ignore?(m))
    # This is just an means to an end that we can use Array.include?, so make
    # sure that actually works.
    assert_include([r], m)
    # And with a string again.
    assert_not_include([id], m)
  end
end
