# frozen_string_literal: true

require 'ditty/controllers/application_controller'
require 'ditty/services/settings'
require 'ditty/services/logger'
require 'backports/2.4.0/hash/compact'

require 'omniauth'
OmniAuth.config.logger = ::Ditty::Services::Logger.instance
OmniAuth.config.path_prefix = "#{::Ditty::ApplicationController.map_path}/auth"
OmniAuth.config.on_failure = proc { |env|
  next [400, {}, []] if env['HTTP_X_REQUESTED_WITH'] == 'XMLHttpRequest'

  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
}

module Ditty
  module Services
    module Authentication
      class << self
        def [](key)
          config[key]
        end

        def providers
          config.compact.keys
        end

        def setup
          providers.each do |provider|
            require "omniauth/#{provider}"
          rescue LoadError
            require "omniauth-#{provider}"
          end
        end

        def config
          default.merge ::Ditty::Services::Settings.values(:authentication) || {}
        end

        def provides?(provider)
          providers.include? provider.to_sym
        end

        def default
          require 'ditty/models/identity'
          require 'ditty/controllers/auth_controller'
          {
            identity: {
              arguments: [
                {
                  fields: [:username],
                  model: ::Ditty::Identity,
                  on_login: ::Ditty::AuthController,
                  on_registration: ::Ditty::AuthController,
                  locate_conditions: ->(req) { { username: req['username'] } }
                }
              ]
            }
          }
        end
      end
    end
  end
end

::Ditty::Services::Authentication.setup
