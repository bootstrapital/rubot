# frozen_string_literal: true

require_relative "test_helper"

begin
  require "action_controller"
  require_relative "../app/controllers/rubot/application_controller"
rescue LoadError, NameError
  nil
end

if defined?(Rubot::ApplicationController)
  class AdminPackagingController < Rubot::ApplicationController
    def authorize_for_test!
      authorize_rubot_admin!
    end

    public :authorize_for_test!
  end
end

class AdminPackagingTest < Minitest::Test
  def teardown
    Rubot.configure do |config|
      config.admin_authorizer = nil
    end
  end

  def test_admin_authorizer_supports_zero_arity_blocks
    skip "Action Controller not available" unless defined?(AdminPackagingController)

    called = false

    Rubot.configure do |config|
      config.admin_authorizer = -> { called = true }
    end

    assert AdminPackagingController.new.authorize_for_test!
    assert called
  end

  def test_admin_authorizer_supports_controller_arity
    skip "Action Controller not available" unless defined?(AdminPackagingController)

    received = nil

    Rubot.configure do |config|
      config.admin_authorizer = ->(controller) do
        received = controller
        true
      end
    end

    controller = AdminPackagingController.new

    assert controller.authorize_for_test!
    assert_same controller, received
  end
end
