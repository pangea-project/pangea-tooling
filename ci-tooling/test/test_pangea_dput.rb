require 'net/ssh/gateway'
require 'vcr'
require 'webmock'
require 'webmock/test_unit'

require_relative 'lib/testcase'
require_relative 'lib/serve'

require 'mocha/test_unit'

class PangeaDPutTest < TestCase
  def setup
    VCR.turn_off!
    WebMock.disable_net_connect!
    @dput = File.join(__dir__, '../bin/pangea_dput')
    ARGV.clear
  end

  def teardown
    WebMock.allow_net_connect!
    VCR.turn_on!
  end

  def stub_common_http
    stub_request(:get, 'http://localhost:111999/api/repos/kitten')
      .to_return(body: '{"Name":"kitten","Comment":"","DefaultDistribution":"","DefaultComponent":""}')
    stub_request(:post, %r{http://localhost:111999/api/files/Aptly__Repository-(.*)})
      .to_return(body: '["Aptly__Repository/kitteh.deb"]')
    stub_request(:post, %r{http://localhost:111999/api/repos/kitten/file/Aptly__Repository-(.*)})
      .to_return(body: "{\"FailedFiles\":[],\"Report\":{\"Warnings\":[],\"Added\":[\"gpgmepp_15.08.2+git20151212.1109+15.04-0_source added\"],\"Removed\":[]}}\n")
    stub_request(:delete, %r{http://localhost:111999/api/files/Aptly__Repository-(.*)})
      .to_return(body: '')
    stub_request(:get, 'http://localhost:111999/api/publish')
      .to_return(body: "[{\"Architectures\":[\"all\"],\"Distribution\":\"distro\",\"Label\":\"\",\"Origin\":\"\",\"Prefix\":\"kewl-repo-name\",\"SourceKind\":\"local\",\"Sources\":[{\"Component\":\"main\",\"Name\":\"kitten\"}],\"Storage\":\"\"}]\n")
    stub_request(:post, 'http://localhost:111999/api/publish/:kewl-repo-name')
      .to_return(body: "{\"Architectures\":[\"source\"],\"Distribution\":\"distro\",\"Label\":\"\",\"Origin\":\"\",\"Prefix\":\"kewl-repo-name\",\"SourceKind\":\"local\",\"Sources\":[{\"Component\":\"main\",\"Name\":\"kitten\"}],\"Storage\":\"\"}\n")
    stub_request(:put, 'http://localhost:111999/api/publish/:kewl-repo-name/distro')
      .to_return(body: "{\"Architectures\":[\"source\"],\"Distribution\":\"distro\",\"Label\":\"\",\"Origin\":\"\",\"Prefix\":\"kewl-repo-name\",\"SourceKind\":\"local\",\"Sources\":[{\"Component\":\"main\",\"Name\":\"kitten\"}],\"Storage\":\"\"}\n")
  end

  def test_run
    stub_common_http

    FileUtils.cp_r("#{data}/.", Dir.pwd)

    ARGV << '--host' << 'localhost'
    ARGV << '--port' << '111999'
    ARGV << '--repo' << 'kitten'
    ARGV << 'yolo.changes'
    # Binary only builds will not have a dsc in their list, stick with .changes.
    # This in particular prevents our .changes -> .dsc fallthru from falling
    # into a whole when processing .changes without an associated .dsc.
    ARGV << 'binary-without-dsc.changes'
    Test.http_serve(Dir.pwd, port: 111_999) do
      load(@dput)
    end
  end

  def test_ssh
    # Tests a gateway life time
    stub_common_http

    seq = sequence('gateway-life')
    stub_gate = stub('ssh-gateway')
    Net::SSH::Gateway
      .expects(:new)
      .with('kitteh.local', 'meow')
      .returns(stub_gate)
      .in_sequence(seq)
    stub_gate
      .expects(:open)
      .with('localhost', '9090')
      .returns(111_999) # actual port to use
      .in_sequence(seq)
    stub_gate
      .expects(:shutdown!)
      .in_sequence(seq)

    FileUtils.cp_r("#{data}/.", Dir.pwd)

    ARGV << '--port' << '9090'
    ARGV << '--gateway' << 'ssh://meow@kitteh.local:9090'
    ARGV << '--repo' << 'kitten'
    ARGV << 'yolo.changes'
    # Binary only builds will not have a dsc in their list, stick with .changes.
    # This in particular prevents our .changes -> .dsc fallthru from falling
    # into a whole when processing .changes without an associated .dsc.
    ARGV << 'binary-without-dsc.changes'
    load(@dput)
  end
end
