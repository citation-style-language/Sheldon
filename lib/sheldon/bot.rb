require 'sinatra/base'
require './lib/sheldon/github'

module Sheldon
  class Bot < Sinatra::Base

    configure :production do
      set :logging, Logger::INFO
      enable :protection
    end

    configure :development do
      set :logging, Logger::DEBUG
    end

    configure :development, :test do
      enable :raise_errors
      disable :show_exceptions
    end


    use Sheldon::Github

    get '/status' do
      'OK'
    end

    get '/version' do
      VERSION
    end

    not_found do
      logger.info "Not found: #{request.url}"
      'Not found. Bazinga!'
    end

    error do
      logger.error "Error: #{env['sinatra.error'].message}"
      "Bazinga! #{env['sinatra.error'].message}"
    end

    # Start Sheldon if this file was executed directly
    run! if app_file == $0
  end
end
