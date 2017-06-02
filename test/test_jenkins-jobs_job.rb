require_relative '../ci-tooling/test/lib/testcase'
require_relative '../jenkins-jobs/job'

require 'mocha/test_unit'

class JenkinsJobTest < TestCase
  def setup
    JenkinsJob.reset
    JenkinsJob.flavor_dir = Dir.pwd
  end

  def teardown
    JenkinsJob.reset
  end

  def test_class_var
    # FIXME: wtf class var wtf wtf wtf
    JenkinsJob.flavor_dir = '/kittens'
    assert_equal('/kittens', JenkinsJob.flavor_dir)
  end

  def test_init
    Dir.mkdir('templates')
    File.write('templates/kitten.xml.erb', '')
    j = JenkinsJob.new('kitten', 'kitten.xml.erb')
    assert_equal('kitten', j.job_name)
    assert_equal("#{Dir.pwd}/config/", j.config_directory)
    assert_equal("#{Dir.pwd}/templates/kitten.xml.erb", j.template_path)
  end

  def test_to_s
    Dir.mkdir('templates')
    File.write('templates/kitten.xml.erb', '')
    j = JenkinsJob.new('kitten', 'kitten.xml.erb')
    assert_equal('kitten', j.to_s)
    assert_equal('kitten', j.to_str)
  end

  def test_init_fail
    # FIXME: see test_init
    assert_raise RuntimeError do
      JenkinsJob.new('kitten', 'kitten.xml.erb')
    end
  end

  def test_render_template
    Dir.mkdir('templates')
    File.write('templates/kitten.xml.erb', '<%= job_name %>')
    job = JenkinsJob.new('kitten', 'kitten.xml.erb')
    render = job.render_template
    assert_equal('kitten', render) # job_name
  end

  def test_render_path
    Dir.mkdir('templates')
    File.write('templates/kitten.xml.erb', '')
    File.write('templates/path.xml.erb', '<%= job_name %>')
    job = JenkinsJob.new('fruli', 'kitten.xml.erb')
    render = job.render('path.xml.erb')
    assert_equal('fruli', render) # job_name from path.xml
  end

  def test_update
    mock_job = mock('jenkins-api-job')
    mock_job.expects(:list_all).returns(%w[kitten])
    Jenkins.expects(:job).at_least_once.returns(mock_job)

    job = mock('Jenkins::Job')
    job.expects(:get_config).returns('')
    job.expects(:update).returns('')
    Jenkins::Job.expects(:new).with('kitten').returns(job)

    Dir.mkdir('templates')
    File.write('templates/kitten.xml.erb', '<<%= job_name %>/>')
    job = JenkinsJob.new('kitten', 'kitten.xml.erb')
    job.update
  end

  def test_update_raise
    mock_job = mock('jenkins-api-job')
    mock_job.expects(:list_all).returns(%w[kitten])
    Jenkins.expects(:job).at_least_once.returns(mock_job)

    job = mock('Jenkins::Job')
    job.expects(:get_config).returns('')
    job.expects(:update).raises(RuntimeError)
    job2 = mock('Jenkins::Job')
    job2.expects(:get_config).returns('')
    job2.expects(:update).returns('')
    Jenkins::Job.expects(:new).with('kitten').twice.returns(job).then.returns(job2)

    Dir.mkdir('templates')
    File.write('templates/kitten.xml.erb', '<<%= job_name %>/>')
    job = JenkinsJob.new('kitten', 'kitten.xml.erb')
    job.update
  end

  def trap_stdout
    iotrap = StringIO.new
    $stdout = iotrap
    yield
    return iotrap.string
  ensure
    $stdout = STDOUT
  end

  def test_xml_debug
    Dir.mkdir('templates')
    File.write('templates/kitten.xml.erb', '')
    stdout = trap_stdout do
      JenkinsJob.new('kitten', 'kitten.xml.erb').send(:xml_debug, '<hi/>')
    end
    assert_equal('<hi/>', stdout)
  end

  def test_mass_include
    # Makes sure the requires of all jobs are actually resolving properly.
    # Would be better as multiple meths, but I can't be bothered to build that.
    # Marginal failure cause anyway.
    Dir.glob("#{__dir__}/../jenkins-jobs/**/*.rb").each do |job|
      pid = fork do
        require job
        exit 0
      end
      waitedpid, status = Process.waitpid2(pid)
      assert_equal(pid, waitedpid)
      assert(status.success?, "Failed to require #{job}!")
    end
  end
end
