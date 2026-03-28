# frozen_string_literal: true

require "faraday"

module Rubot
  module HTTP
    DEFAULT_RETRY_STATUSES = [429, 500, 502, 503, 504].freeze
    DEFAULT_RETRY_EXCEPTIONS = [Faraday::TimeoutError, Faraday::ConnectionFailed].freeze

    Response = Struct.new(:status, :headers, :body, :raw_body, :url, keyword_init: true) do
      def success?
        status.to_i >= 200 && status.to_i < 300
      end

      def json?
        body.is_a?(Hash) || body.is_a?(Array)
      end
    end

    class << self
      def get(url, params: nil, headers: {}, timeout: nil, open_timeout: nil, retries: nil, parse: :auto, connection: nil)
        request(:get, url, params:, headers:, timeout:, open_timeout:, retries:, parse:, connection:)
      end

      def delete(url, params: nil, headers: {}, timeout: nil, open_timeout: nil, retries: nil, parse: :auto, connection: nil)
        request(:delete, url, params:, headers:, timeout:, open_timeout:, retries:, parse:, connection:)
      end

      def post(url, body: nil, json: nil, params: nil, headers: {}, timeout: nil, open_timeout: nil, retries: nil, parse: :auto, connection: nil)
        request(:post, url, body:, json:, params:, headers:, timeout:, open_timeout:, retries:, parse:, connection:)
      end

      def put(url, body: nil, json: nil, params: nil, headers: {}, timeout: nil, open_timeout: nil, retries: nil, parse: :auto, connection: nil)
        request(:put, url, body:, json:, params:, headers:, timeout:, open_timeout:, retries:, parse:, connection:)
      end

      def patch(url, body: nil, json: nil, params: nil, headers: {}, timeout: nil, open_timeout: nil, retries: nil, parse: :auto, connection: nil)
        request(:patch, url, body:, json:, params:, headers:, timeout:, open_timeout:, retries:, parse:, connection:)
      end

      def request(method, url, body: nil, json: nil, params: nil, headers: {}, timeout: nil, open_timeout: nil, retries: nil, parse: :auto, connection: nil)
        conn = connection || build_connection(url, headers:, timeout:, open_timeout:, retries:)
        request_headers = normalize_headers(headers)
        request_body = prepare_body(body:, json:, headers: request_headers)

        faraday_response = conn.public_send(method) do |request|
          request.url(url)
          request.params.update(params) if params
          request.headers.update(request_headers) if request_headers.any?
          request.body = request_body unless request_body.nil?
        end

        build_response(faraday_response, parse:)
      rescue Faraday::Error => e
        raise HTTPError.new(
          e.message,
          details: {
            cause: normalize_error_cause(e),
            url: url,
            original_exception: e.class.name
          }
        )
      end

      def build_connection(url = nil, headers: {}, timeout: nil, open_timeout: nil, retries: nil)
        config = Rubot.configuration
        base_url = extract_base_url(url)

        Faraday.new(url: base_url, headers: normalize_headers(headers)) do |faraday|
          faraday.request :retry,
                          max: retries.nil? ? config.http_retry_attempts : retries,
                          retry_statuses: DEFAULT_RETRY_STATUSES,
                          exceptions: DEFAULT_RETRY_EXCEPTIONS
          faraday.options.timeout = timeout || config.http_timeout
          faraday.options.open_timeout = open_timeout || config.http_open_timeout
          faraday.adapter Faraday.default_adapter
        end
      end

      private

      def build_response(faraday_response, parse:)
        raw_body = faraday_response.body
        parsed_body = parse_body(raw_body, faraday_response.headers, parse:)

        response = Response.new(
          status: faraday_response.status,
          headers: faraday_response.headers.to_h,
          body: parsed_body,
          raw_body: raw_body,
          url: faraday_response.env.url.to_s
        )

        return response if response.success?

        raise HTTPError.new(
          "HTTP #{response.status}",
          status: response.status,
          headers: response.headers,
          body: response.body,
          details: { url: response.url, cause: :response_error }
        )
      end

      def prepare_body(body:, json:, headers:)
        return body if json.nil?

        headers["Content-Type"] ||= "application/json"
        JSON.generate(json)
      end

      def parse_body(raw_body, headers, parse:)
        return raw_body if parse == false
        return nil if raw_body.nil? || raw_body == ""

        if parse == :json || (parse == :auto && json_response?(headers))
          JSON.parse(raw_body)
        else
          raw_body
        end
      rescue JSON::ParserError => e
        raise HTTPError.new(
          "Failed to parse JSON response",
          headers: headers.to_h,
          body: raw_body,
          details: { cause: :parse_error, original_exception: e.class.name }
        )
      end

      def json_response?(headers)
        content_type = headers["content-type"] || headers["Content-Type"]
        content_type.to_s.include?("json")
      end

      def normalize_error_cause(error)
        case error
        when Faraday::TimeoutError then :timeout
        when Faraday::ConnectionFailed then :connection_failed
        when Faraday::SSLError then :ssl_error
        else :unknown_error
        end
      end

      def normalize_headers(headers)
        headers.transform_keys(&:to_s)
      end

      def extract_base_url(url)
        return nil if url.nil?

        uri = URI.parse(url)
        return nil unless uri.scheme && uri.host

        "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port && ![80, 443].include?(uri.port)}"
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
