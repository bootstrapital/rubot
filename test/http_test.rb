# frozen_string_literal: true

require_relative "test_helper"

class HttpTest < Minitest::Test
  def test_get_parses_json_response
    connection = test_connection do |stub|
      stub.get("/tickets/123") do
        [200, { "Content-Type" => "application/json" }, JSON.generate(id: "123", subject: "Hello")]
      end
    end

    response = Rubot::HTTP.get("https://api.example.test/tickets/123", connection:)

    assert_equal 200, response.status
    assert_equal({ "id" => "123", "subject" => "Hello" }, response.body)
    assert_equal "https://api.example.test/tickets/123", response.url
    assert response.success?
  end

  def test_post_json_sets_content_type_and_serializes_body
    seen_body = nil
    seen_content_type = nil

    connection = test_connection do |stub|
      stub.post("/tickets") do |env|
        seen_body = env.body
        seen_content_type = env.request_headers["Content-Type"]
        [201, { "Content-Type" => "application/json" }, JSON.generate(ok: true)]
      end
    end

    response = Rubot::HTTP.post("https://api.example.test/tickets", json: { subject: "Hi" }, connection:)

    assert_equal 201, response.status
    assert_equal JSON.generate(subject: "Hi"), seen_body
    assert_equal "application/json", seen_content_type
    assert_equal({ "ok" => true }, response.body)
  end

  def test_error_response_raises_http_error_with_details
    connection = test_connection do |stub|
      stub.get("/fail") do
        [422, { "Content-Type" => "application/json" }, JSON.generate(error: "bad request")]
      end
    end

    error = assert_raises(Rubot::HTTPError) do
      Rubot::HTTP.get("https://api.example.test/fail", connection:)
    end

    assert_equal 422, error.status
    assert_equal({ "error" => "bad request" }, error.body)
    assert_equal "https://api.example.test/fail", error.details[:url]
  end

  def test_non_json_response_can_be_left_unparsed
    connection = test_connection do |stub|
      stub.get("/plain") do
        [200, { "Content-Type" => "text/plain" }, "hello"]
      end
    end

    response = Rubot::HTTP.get("https://api.example.test/plain", connection:, parse: false)

    assert_equal "hello", response.body
    assert_equal "hello", response.raw_body
  end

  private

  def test_connection(&block)
    stubs = Faraday::Adapter::Test::Stubs.new(&block)

    Faraday.new(url: "https://api.example.test") do |faraday|
      faraday.adapter :test, stubs
    end
  end
end
