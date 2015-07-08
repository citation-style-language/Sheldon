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

include Rack::Test::Methods

def app
  Sheldon::Bot
end

def hookshot(path, type = 'test', data = {})
  post path, data.to_json,
    'X_GITHUB_EVENT' => type,
    'CONTENT_TYPE' => 'application/json',
    'HTTP_USER_AGENT' => 'Github-Hookshot/b4dc0de'
end
