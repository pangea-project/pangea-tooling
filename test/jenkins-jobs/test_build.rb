require_relative 'xml_test'
require_relative '../../jenkins-jobs/build'

class BuildTest < XmlTestCase
  def test_init
    pr = FakeProject.new(dependencies: %w(dep1 dep2), dependees: %w(dep1 dep2))

    b = BuildJob.new(pr, type: 'stable', distribution: 'yolo')
    assert_xml_equal fixture('test_init_render_upstream_scm'), b.render_upstream_scm
    assert_xml_equal fixture('test_init_render'), b.render_template
  end
end
