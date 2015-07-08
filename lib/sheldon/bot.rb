require 'sinatra/base'
require './lib/sheldon/github'

module Sheldon
  class Bot < Sinatra::Base
    enable :logging
    enable :protection

    use Sheldon::Github

    get '/status' do
      'OK'
    end

    get '/version' do
      VERSION
    end

    not_found do
      'Not found. Bazinga!'
    end

    error do
      "Bazinga! #{env['sinatra.error'].message}"
    end

    # Start Sheldon if this file was executed directly
    run! if app_file == $0
  end
end
