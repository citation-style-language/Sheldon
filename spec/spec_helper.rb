require 'bundler/setup'

begin
  require 'byebug'
rescue LoadError
  # no debugger available
end

require 'minitest/autorun'
require 'minitest/pride'
require 'rack/test'
require 'json'

require File.expand_path('../../lib/sheldon', __FILE__)

FIXTURES = File.expand_path('../fixtures', __FILE__)

include Rack::Test::Methods

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
    'X_GITHUB_EVENT' => type.to_s,
    'CONTENT_TYPE' => 'application/json',
    'HTTP_USER_AGENT' => 'Github-Hookshot/b4dc0de'
end
