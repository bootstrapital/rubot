# frozen_string_literal: true

require_relative "test_helper"
require "faraday"

class HttpErrorNormalizationTest < Minitest::Test
  def test_timeout_error_is_normalized
    # We can't easily trigger a real timeout without a server, 
    # so we mock the connection.
    conn = Faraday.new do |f|
      f.adapter :test do |stub|
        stub.get("/timeout") { raise Faraday::TimeoutError, "Timeout" }
      end
    end

    error = assert_raises(Rubot::HTTPError) do
      Rubot::HTTP.get("http://api.example.com/timeout", connection: conn)
    end

    assert_equal :timeout, error.details[:cause]
    assert_equal "Faraday::TimeoutError", error.details[:original_exception]
  end

  def test_connection_failed_error_is_normalized
    conn = Faraday.new do |f|
      f.adapter :test do |stub|
        stub.get("/failed") { raise Faraday::ConnectionFailed, "Failed" }
      end
    end

    error = assert_raises(Rubot::HTTPError) do
      Rubot::HTTP.get("http://api.example.com/failed", connection: conn)
    end

    assert_equal :connection_failed, error.details[:cause]
    assert_equal "Faraday::ConnectionFailed", error.details[:original_exception]
  end

  def test_parse_error_is_normalized
    conn = Faraday.new do |f|
      f.adapter :test do |stub|
        stub.get("/json") { [200, { "Content-Type" => "application/json" }, "invalid-json"] }
      end
    end

    error = assert_raises(Rubot::HTTPError) do
      Rubot::HTTP.get("http://api.example.com/json", connection: conn)
    end

    assert_equal :parse_error, error.details[:cause]
  end

  def test_unsuccessful_response_is_normalized
    conn = Faraday.new do |f|
      f.adapter :test do |stub|
        stub.get("/404") { [404, {}, "Not Found"] }
      end
    end

    error = assert_raises(Rubot::HTTPError) do
      Rubot::HTTP.get("http://api.example.com/404", connection: conn)
    end

    assert_equal :response_error, error.details[:cause]
    assert_equal 404, error.status
  end
end
