require_relative '../lib/qml/module'
require_relative 'lib/testcase'

# Test qml module parsing
class QMLTest < TestCase
  def test_init
    m = QML::Module.new('org.kde.a', '2.0', nil)
    assert_equal('org.kde.a', m.identifier)
    assert_equal('2.0', m.version)
    assert_nil(m.qualifier)
  end

  def test_empty_line
    assert_empty(QML::Module.parse(''))
  end

  def test_short_line
    assert_empty(QML::Module.parse('import QtQuick'))
  end
  # Too long line is in fact allowed for now

  def test_no_import
    assert_empty(QML::Module.parse('QtQuick import 1'))
  end

  def test_simple_parse
    mods = QML::Module.parse('import QtQuick 1')
    assert_equal(1, mods.size)
    mod = mods.first
    assert_equal('QtQuick', mod.identifier)
    assert_equal('1', mod.version)
    assert_equal("#{mod.identifier}[#{mod.version}]", mod.to_s)
  end

  def test_comment
    assert_empty(QML::Module.parse('#import QtQuick 1'))
    assert_empty(QML::Module.parse('#     import QtQuick 1'))
    assert_empty(QML::Module.parse('    #   import QtQuick 1'))
  end

  def test_compare
    id = 'id'
    version = 'version'
    qualifier = 'qualifier'
    ref = QML::Module.new(id, version, qualifier)
    assert_equal(ref, QML::Module.new(id, version, qualifier))
    assert_equal(ref, QML::Module.new(id, version))
    assert_equal(ref, QML::Module.new(id))
    assert_not_equal(ref, QML::Module.new('yolo'))
  end

  def test_directory
    assert_empty(QML::Module.parse('import "private" as Private'))
  end

  def test_trailing_semi_colon
    mods = QML::Module.parse('import org.kde.kwin 2.0  ; import org.kde.plasma 1.0  ;')
    assert_equal(2, mods.size)
    mod = mods.first
    assert_equal('org.kde.kwin', mod.identifier)
    assert_equal('2.0', mod.version)
    assert_equal("#{mod.identifier}[#{mod.version}]", mod.to_s)
    mod = mods.last
    assert_equal('org.kde.plasma', mod.identifier)
    assert_equal('1.0', mod.version)
    assert_equal("#{mod.identifier}[#{mod.version}]", mod.to_s)
  end
end
