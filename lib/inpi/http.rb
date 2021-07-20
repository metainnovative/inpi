# frozen_string_literal: true

require 'cgi'
require 'json'
require 'net/http'
require 'uri'

require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/object/to_query'
require 'active_support/core_ext/string/inflections'

require 'inpi/authentication_error'
require 'inpi/rncs_server_error'

class Inpi
  class HTTP
    include Singleton

    def self.get(path, opts = {})
      instance.get(path, opts)
    end

    def get(path, opts = {})
      session_id = @session_id || refresh_session
      headers = opts[:headers] || {}
      headers.merge!(cookie: "JSESSIONID=#{session_id}")

      response = request(path, :get, json_response: opts[:json_response], query: opts[:query], headers: headers)

      if response.is_a?(Net::HTTPUnauthorized)
        if opts[:retried]
          raise Inpi::AuthenticationError, response
        else
          get(path, opts.merge(retried: true))
        end
      end

      response
    end

    def refresh_session
      response = request('/services/diffusion/login', :post, headers: { login: Inpi.config.login, password: Inpi.config.password })

      raise Inpi::AuthenticationError, response unless response.is_a?(Net::HTTPSuccess)

      cookies = response.get_fields('set-cookie')&.map do |cookie|
        key, value = cookie.split(';').first&.split('=')

        [CGI.unescape(key), CGI.unescape(value)]
      end&.to_h

      session_id = cookies['JSESSIONID'].presence

      raise Inpi::AuthenticationError, response unless session_id

      @session_id = session_id
    end

    def self.json_body_transform(body)
      case body
      when Array
        body.map { |v| json_body_transform(v) }
      when Hash
        body.deep_transform_keys { |k| k.to_s.parameterize(separator: '_', preserve_case: true).underscore.to_sym }
      else
        body
      end
    end

    private

    def request(path, method, opts = {})
      http = Net::HTTP.new('opendata-rncs.inpi.fr', 443)
      http.use_ssl = true

      uri = URI(path)
      uri.query = CGI.parse(uri.query || '').merge(opts[:query]).to_query if opts[:query].present?

      response = case method
                 when :get
                   http.get(uri.to_s, opts[:headers])
                 when :post
                   payload = case opts[:payload]
                             when Hash
                               if opts[:headers].find { |k, _| k.to_s.downcase == 'content-type' }
                                 JSON(opts[:payload])
                               else
                                 URI.encode_www_form(opts[:payload])
                               end
                             else
                               opts[:payload]
                             end

                   http.post(uri.to_s, payload, opts[:headers])
                 else
                   raise NotImplementedError, "method: #{method}"
                 end

      if opts[:json_response] || response.header['content-type'].to_s.split(';').first == 'application/json'
        response.define_singleton_method(:body_parsed) { Inpi::HTTP.json_body_transform(JSON(body)) }
      else
        response.define_singleton_method(:body_parsed) { body }
      end

      response
    end
  end
end
