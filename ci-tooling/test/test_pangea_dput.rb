require 'webmock'
require 'webmock/test_unit'

require_relative 'lib/testcase'
require_relative 'lib/serve'

class PangeaDPutTest < TestCase
  def setup
    WebMock.disable_net_connect!
    @dput = File.join(__dir__, '../bin/pangea_dput')
    ARGV.clear
  end

  def teardown
    WebMock.allow_net_connect!
  end

  def test_run
    stub_request(:get, 'http://localhost:111999/api/repos/kitten')
      .to_return(body: '{"Name":"kitten","Comment":"","DefaultDistribution":"","DefaultComponent":""}')
    stub_request(:post, %r{http://localhost:111999/api/files/Aptly__Repository-(.*)})
      .to_return(body: '["Aptly__Repository/kitteh.deb"]')
    stub_request(:post, %r{http://localhost:111999/api/repos/kitten/file/Aptly__Repository-(.*)})
      .to_return(body: "{\"FailedFiles\":[],\"Report\":{\"Warnings\":[],\"Added\":[\"gpgmepp_15.08.2+git20151212.1109+15.04-0_source added\"],\"Removed\":[]}}\n")
    stub_request(:get, 'http://localhost:111999/api/publish')
      .to_return(body: "[{\"Architectures\":[\"all\"],\"Distribution\":\"distro\",\"Label\":\"\",\"Origin\":\"\",\"Prefix\":\"kewl-repo-name\",\"SourceKind\":\"local\",\"Sources\":[{\"Component\":\"main\",\"Name\":\"kitten\"}],\"Storage\":\"\"}]\n")
    stub_request(:post, 'http://localhost:111999/api/publish/kewl-repo-name')
      .to_return(body: "{\"Architectures\":[\"source\"],\"Distribution\":\"distro\",\"Label\":\"\",\"Origin\":\"\",\"Prefix\":\"kewl-repo-name\",\"SourceKind\":\"local\",\"Sources\":[{\"Component\":\"main\",\"Name\":\"kitten\"}],\"Storage\":\"\"}\n")
    stub_request(:put, 'http://localhost:111999/api/publish/kewl-repo-name/distro')
      .to_return(body: "{\"Architectures\":[\"source\"],\"Distribution\":\"distro\",\"Label\":\"\",\"Origin\":\"\",\"Prefix\":\"kewl-repo-name\",\"SourceKind\":\"local\",\"Sources\":[{\"Component\":\"main\",\"Name\":\"kitten\"}],\"Storage\":\"\"}\n")

    FileUtils.cp_r("#{data}/.", Dir.pwd)

    ARGV << '--host' << 'localhost'
    ARGV << '--port' << '111999'
    ARGV << '--repo' << 'kitten'
    ARGV << 'yolo.changes'
    Test.http_serve(Dir.pwd, port: 111_999) do
      load(@dput)
    end
  end
end
