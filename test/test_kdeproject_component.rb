require 'test/unit'
require_relative '../lib/kdeproject_component'

class KDEProjectComponentTest < Test::Unit::TestCase
  def test_kdeprojectcomponent
    f = KDEProjectsComponent.frameworks
    p = KDEProjectsComponent.plasma
    a = KDEProjectsComponent.applications
    assert f.include? 'attica'
    assert p.include? 'khotkeys'
    assert a.include? 'umbrello'
    assert ! a.include?('khotkeys')
  end
end
