require_relative '../lib/qml/static_map'
require_relative 'lib/testcase'

# test qml_static_map
# This is mostly covered indirectly through dependency_verifier
class QmlStaticMapTest < TestCase
  def new_mod(id, version = nil)
    QML::Module.new(id, version)
  end

  def test_parse
    previous_file = QML::StaticMap.instance_variable_get(:@data_file)
    QML::StaticMap.instance_variable_set(:@data_file, data)
    assert_equal(data, QML::StaticMap.instance_variable_get(:@data_file))
    map = QML::StaticMap.new
    assert_nil(map.package(new_mod('groll')))
    assert_equal('plasma-framework',
                 map.package(new_mod('org.kde.plasma.plasmoid')))
    assert_nil(map.package(new_mod('org.kde.kwin')))
    assert_equal('kwin', map.package(new_mod('org.kde.kwin', '2.0')))
  ensure
    QML::StaticMap.instance_variable_set(:@data_file, previous_file)
  end
end
