require 'bundler/setup'

begin
  require 'byebug'
rescue LoadError
  # no debugger available
end

require 'minitest/autorun'
require 'minitest/pride'
require 'rack/test'

require File.expand_path('../../lib/sheldon', __FILE__)

include Rack::Test::Methods

def app
  Sheldon
end
