require 'sinatra/base'
require 'sinatra/config_file'
require 'octokit'
require 'logger'

require './lib/sheldon/github_helper'
require './lib/sheldon/travis_ci_helper'
require './lib/sheldon/template'

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


    set :root, File.expand_path('../../..', __FILE__)

    register Sinatra::ConfigFile
    config_file 'config/templates.yml'

    helpers GithubHelper, TravisCiHelper

    set(:github, Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN']))
    set(:travis_token, ENV['TRAVIS_USER_TOKEN'])

    set(:hookshot) { |exp| condition { exp == hookshot? } }
    set(:valid_notification) { |exp| condition { exp == valid_notification? } }



    # --- GitHub Pull Request Hook ---

    before '/pull_request', hookshot: true do
      logger.info "GitHub hookshot #{github_event.inspect} received"
    end

    post '/pull_request', hookshot: true do
      return 202 if ping?
      return 400 unless pull_request?

      options = settings.templates[:pull_request]
      return 202 if options.nil? || !options.key?(pull_request_action)

      template = Template.load options[pull_request_action]

      #comment = github.add_comment(
      github.add_comment(
        repository['full_name'],
        pull_request['number'],
        template.render(pull_request))

      #[201, nil, { location: comment.url }]
      201
    end

    post '/pull_request' do
      logger.warn "Invalid GitHub hookshot received: #{request.inspect}"
      400
    end


    # --- Travis CI build hook ---

    before '/build', valid_notification: true do
      logger.info 'Travis CI notification received'
    end

    post '/build', valid_notification: true do
      return 202 unless build_pull_request?

      options = settings.templates[:build]
      return 202 if options.nil? || !options.key?(build_status)

      template = Template.load options[build_status]

      #comment = github.add_comment(
      github.add_comment(
        repo_slug,
        build_pull_request_number,
        template.render(travis_payload))

      #[201, nil, { location: comment.url }]
      201
    end

    post '/build' do
      logger.warn "Invalid Travis CI notification received: #{request.inspect}"
      400
    end


    # --- Other Requests ---

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
