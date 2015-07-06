require 'sinatra/base'

class Sheldon < Sinatra::Base

  configure do
    enable :logging
    enable :protection
  end

  get '/status' do
    'OK'
  end

  get '/version' do
    VERSION
  end

  # Start Sheldon if this file was executed directly
  run! if app_file == $0
end
