require 'bundler/setup'

begin
  require 'byebug'
rescue LoadError
  # no debugger available
end

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/pride'
require 'rack/test'
require 'json'
require 'webmock/minitest'

require File.expand_path('../../lib/sheldon', __FILE__)

WebMock.disable_net_connect! allow_localhost: true

include Rack::Test::Methods

FIXTURES = File.expand_path('../fixtures', __FILE__)

def fixtures(name)
  File.read File.join(FIXTURES, name)
end

def payloads(name)
  JSON.parse fixtures("#{name}.json")
end

def app
  Sheldon::Bot
end

def hookshot(path, type = 'test', data = {})
  data = payloads(data) unless data.is_a? Hash

  post path, data.to_json,
    'HTTP_X_GITHUB_EVENT' => type.to_s,
    'CONTENT_TYPE' => 'application/json',
    'HTTP_USER_AGENT' => 'GitHub-Hookshot/b4dc0de'
end
