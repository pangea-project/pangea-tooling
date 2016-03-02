require 'pathname'
require 'rack'
require 'webmock/test_unit'

require_relative 'lib/testcase'
require_relative '../lib/lp'

module FakeLaunchpad
  class << self
    attr_accessor :datadir
  end

  module_function

  def call(env)
    case env['REQUEST_METHOD']
    when 'GET'
      return get(env)
    end
    faile "unhandled http method '#{env['REQUEST_METHOD']}' in #{self}"
  end

  def get(env)
    path = Pathname.new(env['PATH_INFO']).cleanpath.to_s
    query = env['QUERY_STRING']
    case path
    when '/devel/ubuntu'
      case query
      when ''
        return ['200',
                { 'Content-Type' => 'application/json' },
                [json_response('ubuntu.json')]]
      when 'ws.op=yolokittenstein'
        return ['400', {}, []]
      when 'archive=https://api.launchpad.net/devel/ubuntu/%2Barchive/primary&ws.op=GetYoloKitten'
        return ['200', {}, ['{"yolo_kitten":"kitten"}']]
      end
    when '/devel/ubuntu/archives'
      # NOTE: this implements a linked list. Queries can returned limited
      #   collections which point to the next part of the collection which must
      #   be queried independently.
      case query
      when '', 'memo=1&ws.size=1&ws.start=1'
        set = '1'
        set = '2' if query == 'memo=1&ws.size=1&ws.start=1'
        return ['200',
                { 'Content-Type' => 'application/json' },
                [json_response("ubuntu-archives#{set}.json")]]
      end
    when '/devel/ubuntu/+archive/primary'
      return ['200',
              { 'Content-Type' => 'application/json' },
              [json_response('ubuntu-archive-primary.json')]]
    when '/devel/~kubuntu-ci/+archive/ubuntu/unstable'
      # FIXME: code dup and query is order sensitive
      case env['QUERY_STRING']
      when ''
        return ['200',
                { 'Content-Type' => 'application/json' },
                [json_response('ppa.json')]]
      when 'source_name=kate&ws.op=getPublishedSources'
        return ['200',
                { 'Content-Type' => 'application/json' },
                [json_response('ppa-sources-kate-1.json')]]
      when 'memo=2&source_name=kate&ws.op=getPublishedSources&ws.size=2&ws.start=2'
        return ['200',
                { 'Content-Type' => 'application/json' },
                [json_response('ppa-sources-kate-2.json')]]
      end
    when '/devel/~kubuntu-ci/+archive/ubuntu/unstable/+sourcepub/4571865'
      case env['QUERY_STRING']
      when 'ws.op=changelogUrl'
        return ['200',
                { 'Content-Type' => 'application/json' },
                ["\"http://foobar\""]]
      end
    end
    fail "unhandled get '#{path}?#{env['QUERY_STRING']}' in #{self}"
  end

  def json_response(file_name)
    File.read("#{@datadir}/#{file_name}")
  end
end

# Test launchpad
class LaunchpadTest < TestCase
  def setup
    WebMock.disable_net_connect!(allow_localhost: true)

    @oauth_token = 'accesskey'
    @oauth_token_secret = 'accesssecret'
    @oauth_params = {
      'oauth_consumer_key' => 'kubuntu-ci',
      'oauth_signature' => "&#{@oauth_token_secret}",
      'oauth_signature_method' => 'PLAINTEXT',
      'oauth_token' => @oauth_token
    }
    @token_json ||= File.read(@datadir + '/token.json')

    Launchpad.instance_variable_set(:@io_retry_sleeps, 0)
    Launchpad.instance_variable_set(:@conf_path, Dir.pwd)

    conf = "#{Dir.pwd}/.config"
    FileUtils.mkpath(conf)
    File.write("#{conf}/lp-tokens.json", @token_json)
  end

  def teardown
    Launchpad.instance_variable_set(:@conf_path, Dir.home)
    WebMock.allow_net_connect!
  end

  # Helper to redirect stdin so we can simulate user input as authentication
  # prompts for 'done' once authorization was granted on launchpad.
  def stdinit
    stdin = $stdin
    $stdin, input = IO.pipe
    yield input
  ensure
    input.close
    $stdin = stdin
  end

  def valid_auth?(request)
    headers = request.headers
    return false unless headers.include?('Authorization')
    params = OAuth::Helper.parse_header(headers['Authorization'])
    params.dup.merge(@oauth_params) == params
  end

  def test_token
    token = Launchpad.token
    assert_not_nil(token, 'token was nil')
    assert_is_a(token, OAuth::AccessToken)
  end

  def test_authenticate
    FileUtils.rm_r('.config')
    token = nil
    # Request token stub
    request_response = 'oauth_token=requestkey&oauth_token_secret=requestsecret'
    stub_request(:post, 'https://launchpad.net/+request-token')
      .to_return(body: request_response)
    # Access token stub
    token_request = {
      'oauth_consumer_key' => 'kubuntu-ci',
      'oauth_signature' => '&requestsecret',
      'oauth_signature_method' => 'PLAINTEXT',
      'oauth_token' => 'requestkey'
    }
    access_response = "oauth_token=#{@oauth_token}" \
                      "&oauth_token_secret=#{@oauth_token_secret}"
    stub_request(:post, 'https://launchpad.net/+access-token')
      .with(body: hash_including(token_request))
      .to_return(body: access_response)

    stdinit do |input|
      # Make sure we don't simply #gets without IO object as that would read
      # ARGV which would then attempt to read the file 'drumpf'
      ARGV << 'drumpf'
      input.puts 'done'
      token = Launchpad.authenticate
    end

    assert_not_nil(token, 'token was nil')
    assert_is_a(token, OAuth::AccessToken)
    assert_equal(@oauth_token, token.token)
    assert_equal(@oauth_token_secret, token.secret)
    assert_equal(JSON.parse(@token_json),
                 JSON.parse(File.read('.config/lp-tokens.json')))
  ensure
    ARGV.pop if ARGV[-1] == 'drumpf'
  end

  def test_get_through_token
    stub_request(:get, "https://api.launchpad.net/#{__method__}")
      .with { |r| valid_auth?(r) }
      .to_return(status: 200, body: '', headers: {})
    assert_not_nil(Launchpad.token)

    Launchpad.get(URI("https://api.launchpad.net/#{__method__}"))

    assert_requested(:get, "https://api.launchpad.net/#{__method__}", times: 1)
  end

  def test_get
    # Need not have a valid token here as we want to have a get without Auth
    FileUtils.rm_r('.config')
    assert_nil(Launchpad.token)
    stub_request(:get, "https://api.launchpad.net/#{__method__}")
      .with { |request| next !request.headers.include?('Authorization') }
      .to_return(status: 200, body: '', headers: {})

    Launchpad.get(URI("https://api.launchpad.net/#{__method__}"))

    assert_requested(:get, "https://api.launchpad.net/#{__method__}", times: 1)
  end

  def test_get_network_error
    stub_request(:get, "https://api.launchpad.net/#{__method__}")
      .to_return(status: 401, body: '', headers: {})

    assert_raise Net::HTTPRetriableError do
      Launchpad.get(URI("https://api.launchpad.net/#{__method__}"))
    end

    assert_requested(:get, "https://api.launchpad.net/#{__method__}",
                     times: Launchpad::IO_RETRIES)
  end

  def test_post_through_token_has_auth
    assert_not_nil(Launchpad.token)
    stub_request(:post, "https://api.launchpad.net/#{__method__}")
      .with { |r| valid_auth?(r) }
      .to_return(status: 200, body: '', headers: {})

    Launchpad.post(URI("https://api.launchpad.net/#{__method__}"))

    assert_requested(:post, "https://api.launchpad.net/#{__method__}", times: 1)
  end

  def test_post_through_token_carries_query
    stub_request(:post, "https://api.launchpad.net/#{__method__}")
      .with(body: 'a=a1&b=b1')
      .to_return(status: 200, body: '', headers: {})

    Launchpad.post(URI("https://api.launchpad.net/#{__method__}?a=a1&b=b1"))

    assert_requested(:post, "https://api.launchpad.net/#{__method__}", times: 1)
  end

  def test_post
    # Posting without token causes runtime errors.
    FileUtils.rm_r('.config')
    stub_request(:post, "https://api.launchpad.net/#{__method__}")
      .to_return(status: 401, body: '', headers: {})

    assert_raise RuntimeError do
      Launchpad.post(URI("https://api.launchpad.net/#{__method__}"))
    end

    assert_not_requested(:post, "https://api.launchpad.net/#{__method__}",
                         times: 1)
  end

  def test_post_network_error
    stub_request(:post, "https://api.launchpad.net/#{__method__}")
      .to_return(status: 401, body: '', headers: {})

    assert_raise Net::HTTPRetriableError do
      Launchpad.post(URI("https://api.launchpad.net/#{__method__}"))
    end

    assert_requested(:post, "https://api.launchpad.net/#{__method__}",
                     times: Launchpad::IO_RETRIES)
  end
end

class LaunchpadRubberTest < TestCase
  def setup
    Launchpad.instance_variable_set(:@conf_path, Dir.pwd)
    FakeLaunchpad.datadir = @datadir

    WebMock.disable_net_connect!(allow_localhost: true)
    stub_request(:any, /api.launchpad.net/).to_rack(FakeLaunchpad)

    @ppa_path = '~kubuntu-ci/+archive/ubuntu/unstable'
    @ppa_url = "https://api.launchpad.net/devel/#{@ppa_path}"
  end

  def teardown
    assert_equal(Launchpad.token, nil)
    WebMock.allow_net_connect!
  end

  def test_from_url
    ppa = Launchpad::Rubber.from_url(@ppa_url)
    assert(ppa)
    # Has a bunch of properties]
    assert_equal('Active', ppa.status)
    assert_equal('unstable', ppa.name)
    assert_equal(@ppa_url, ppa.self_link)
  end

  def test_from_path
    ppa = Launchpad::Rubber.from_path(@ppa_path)
    devel = Launchpad::Rubber.from_path("devel/#{@ppa_path}")
    slashdevel = Launchpad::Rubber.from_path("/devel/#{@ppa_path}")
    assert(ppa)
    # Has a bunch of properties]
    assert_equal('Active', ppa.status)
    assert_equal('unstable', ppa.name)
    assert_equal(@ppa_url, ppa.self_link)
    assert_equal(ppa, devel)
    assert_equal(ppa, slashdevel)
  end

  def test_ppa_source_collection
    ppa = Launchpad::Rubber.from_url(@ppa_url)
    sources = ppa.getPublishedSources(source_name: 'kate')
    assert_not_nil(sources)
    # TODO: when run against live this needs to be >=0
    assert_equal(sources.size, 4)
    source = sources[0]
    # Has a bunch of properties
    assert_not_nil(source)
    assert_nothing_raised do
      source.self_link
      source.pocket
      source.status
    end
    # Can GET a string-only variable. This mustn't make the parser trip.
    assert_respond_to(source.changelogUrl, :downcase)
  end

  def test_collection_link
    ubuntu = Launchpad::Rubber.from_path('ubuntu')
    archives = ubuntu.archives
    assert_not_nil(archives)
    assert_equal(2, archives.size)
    assert_equal('Primary Archive for Ubuntu', archives[0].displayname)
    assert_equal('Partner Archive for Ubuntu', archives[1].displayname)
  end

  def test_missing_link
    ubuntu = Launchpad::Rubber.from_path('ubuntu')
    archive = ubuntu.main_archive
    assert_not_nil(archive)
    assert_equal('Primary Archive for Ubuntu', archive.displayname)
  end

  def test_invalid_attribute
    ubuntu = Launchpad::Rubber.from_path('ubuntu')
    assert_raise Net::HTTPRetriableError do
      ubuntu.yolokittenstein
    end
  end

  def test_build_params_self_link
    ubuntu = Launchpad::Rubber.from_path('ubuntu')
    archive = ubuntu.main_archive
    r = ubuntu.GetYoloKitten(archive: archive)
    assert_not_nil(r)
    assert(r.respond_to?(:yolo_kitten))
    assert_equal('kitten', r.yolo_kitten)
  end
end
