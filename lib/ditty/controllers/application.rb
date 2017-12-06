# frozen_string_literal: true

require 'wisper'
require 'sinatra/base'
require 'sinatra/flash'
require 'sinatra/respond_with'
require 'ditty/helpers/views'
require 'ditty/helpers/pundit'
require 'ditty/helpers/wisper'
require 'ditty/helpers/authentication'
require 'ditty/services/logger'
require 'active_support'
require 'active_support/inflector'
require 'rack/contrib'

module Ditty
  class Application < Sinatra::Base
    include ActiveSupport::Inflector

    set :root, ENV['APP_ROOT'] || ::File.expand_path(::File.dirname(__FILE__) + '/../../../')
    set :map_path, nil
    set :view_location, nil
    set :model_class, nil
    # The order here is important, since Wisper has a deprecated method respond_with method
    helpers Wisper::Publisher, Helpers::Wisper
    helpers Helpers::Pundit, Helpers::Views, Helpers::Authentication

    register Sinatra::Flash, Sinatra::RespondWith

    use Rack::PostBodyContentTypeParser
    use Rack::MethodOverride

    def view_location
      return settings.view_location if settings.view_location
      return underscore(pluralize(demodulize(settings.model_class))) if settings.model_class
      underscore(demodulize(self.class))
    end

    configure :production do
      disable :show_exceptions
      set :dump_errors, false
    end

    configure :development do
      set :show_exceptions, :after_handler
    end

    configure :production, :development do
      enable :logging
      use Rack::CommonLogger, Ditty::Services::Logger.instance
    end

    not_found do
      respond_to do |format|
        format.html do
          haml :'404', locals: { title: '4 oh 4' }
        end
        format.json do
          [404, { 'Content-Type' => 'application/json' }, [{ code: 404, errors: ['Not Found'] }.to_json]]
        end
      end
    end

    error do
      error = env['sinatra.error']
      broadcast(:application_error, error)
      respond_to do |format|
        format.html do
          haml :error, locals: { title: 'Something went wrong', error: error }
        end
        format.json do
          [500, { 'Content-Type' => 'application/json' }, [{ code: 500, errors: ['Something went wrong'] }.to_json]]
        end
      end
    end

    error Helpers::NotAuthenticated, ::Pundit::NotAuthorizedError do
      respond_to do |format|
        format.html do
          flash[:warning] = 'Please log in first.'
          redirect "#{settings.map_path}/auth/identity"
        end
        format.json do
          [401, { 'Content-Type' => 'application/json' }, [{ code: 401, errors: ['Not Authenticated'] }.to_json]]
        end
      end
    end

    error ::Sequel::ForeignKeyConstraintViolation do
      respond_to do |format|
        format.html do
          haml :error, locals: { title: 'Something went wrong', error: error }
        end
        format.json do
          [400, { 'Content-Type' => 'application/json' }, [{ code: 400, errors: ['Invalid Relation Specified'] }.to_json]]
        end
      end
    end

    before(/.*/) do
      ::Ditty::Services::Logger.instance.debug "Running with #{self.class}"
      if request.url =~ /.json/
        request.accept.unshift('application/json')
        request.path_info = request.path_info.gsub(/.json/, '')
      end
    end
  end
end
