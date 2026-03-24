# frozen_string_literal: true

module Rubot
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
