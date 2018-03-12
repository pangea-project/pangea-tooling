require 'test/unit'

require 'webmock'
require 'webmock/test_unit'

require_relative '../lib/kdeproject_component'

require 'mocha/test_unit'

class KDEProjectComponentTest < Test::Unit::TestCase
  def test_kdeprojectcomponent
    stub_request(:get, 'https://projects.kde.org/api/v1/projects/frameworks').
        with(headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
        to_return(status: 200, body: '["frameworks/attica","frameworks/baloo","frameworks/bluez-qt"]', headers: {'Content-Type'=> 'text/json'})

    stub_request(:get, 'https://projects.kde.org/api/v1/projects/kde/workspace').
        with(headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
        to_return(status: 200, body: '["kde/workspace/khotkeys","kde/workspace/plasma-workspace"]', headers: {'Content-Type'=> 'text/json'})

    stub_request(:get, 'https://projects.kde.org/api/v1/projects/kde').
        with(headers: {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
        to_return(status: 200, body: '["kde/workspace/khotkeys","kde/kdesdk/umbrello"]', headers: {'Content-Type'=> 'text/json'})

    f = KDEProjectsComponent.frameworks
    p = KDEProjectsComponent.plasma
    a = KDEProjectsComponent.applications
    assert f.include? 'attica'
    assert p.include? 'khotkeys'
    assert a.include? 'umbrello'
    assert ! a.include?('khotkeys')
  end
end
