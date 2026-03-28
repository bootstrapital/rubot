# frozen_string_literal: true

require_relative "test_helper"

class DeepSchemaTest < Minitest::Test
  def test_nested_hash_validation
    schema = Rubot::Schema.build do
      hash :invoice do
        string :id
        integer :amount
      end
    end

    # Valid
    schema.validate!(invoice: { id: "inv_1", amount: 100 })

    # Missing field in nested hash
    error = assert_raises(Rubot::ValidationError) do
      schema.validate!(invoice: { id: "inv_1" })
    end
    assert_equal "Missing required field invoice.amount", error.message

    # Wrong type in nested hash
    error = assert_raises(Rubot::ValidationError) do
      schema.validate!(invoice: { id: "inv_1", amount: "string" })
    end
    assert_equal "invoice.amount must be a integer", error.message
  end

  def test_nested_array_of_hashes_validation
    schema = Rubot::Schema.build do
      array :items, of: :hash do
        string :name
        integer :price
      end
    end

    # Valid
    schema.validate!(items: [{ name: "item1", price: 10 }, { name: "item2", price: 20 }])

    # Error in second item
    error = assert_raises(Rubot::ValidationError) do
      schema.validate!(items: [{ name: "item1", price: 10 }, { name: "item2" }])
    end
    assert_equal "Missing required field items.1.price", error.message
  end

  def test_optional_nested_structures
    schema = Rubot::Schema.build do
      hash :metadata, required: false do
        string :tag
      end
    end

    # Valid when nil
    schema.validate!({})
    schema.validate!(metadata: nil)

    # Error when provided but invalid
    error = assert_raises(Rubot::ValidationError) do
      schema.validate!(metadata: { tag: 123 })
    end
    assert_equal "metadata.tag must be a string", error.message
  end

  def test_deep_nesting
    schema = Rubot::Schema.build do
      hash :a do
        hash :b do
          hash :c do
            string :d
          end
        end
      end
    end

    error = assert_raises(Rubot::ValidationError) do
      schema.validate!(a: { b: { c: { d: 123 } } })
    end
    assert_equal "a.b.c.d must be a string", error.message
  end
end
