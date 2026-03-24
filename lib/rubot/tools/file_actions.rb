# frozen_string_literal: true

module Rubot
  module Tools
    module FileActions
      class IngestFile < Rubot::Tool
        description "Read a local file or inline content into a normalized document payload."

        input_schema do
          string :file_path, required: false
          string :content, required: false
          string :file_name, required: false
          string :content_type, required: false
        end

        output_schema do
          string :document_id
          string :file_name
          string :content
          string :content_type
          integer :line_count
        end

        def call(file_path: nil, content: nil, file_name: nil, content_type: nil)
          raise Rubot::ExecutionError, "Provide file_path or content" if blank?(file_path) && blank?(content)

          body =
            if !blank?(file_path)
              File.read(file_path)
            else
              content.to_s
            end

          resolved_name = file_name || (!blank?(file_path) ? File.basename(file_path) : "inline.txt")
          resolved_content_type = content_type || infer_content_type(resolved_name)

          {
            document_id: "doc_#{SecureRandom.hex(6)}",
            file_name: resolved_name,
            content: body,
            content_type: resolved_content_type,
            line_count: body.lines.count
          }
        end

        private

        def infer_content_type(file_name)
          return "application/pdf" if file_name.to_s.downcase.end_with?(".pdf")
          return "text/csv" if file_name.to_s.downcase.end_with?(".csv")

          "text/plain"
        end

        def blank?(value)
          value.nil? || value.to_s.strip.empty?
        end
      end

      class ExtractFields < Rubot::Tool
        description "Extract common finance and dispute fields from ingested text."

        input_schema do
          string :content
          string :file_name, required: false
        end

        output_schema do
          string :invoice_id, required: false
          string :dispute_id, required: false
          string :customer_name, required: false
          float :amount, required: false
          string :currency, required: false
          string :transaction_date, required: false
          array :warnings, of: :string
        end

        def call(content:, file_name: nil)
          normalized_content = content.to_s

          {
            invoice_id: match(normalized_content, /invoice(?:\s+id)?[\s#:]+([A-Z0-9\-]+)/i),
            dispute_id: match(normalized_content, /dispute(?:\s+id)?[\s#:]+([A-Z0-9\-]+)/i),
            customer_name: match(normalized_content, /customer[\s:]+([A-Za-z0-9 .,'-]+)/i),
            amount: extract_amount(normalized_content),
            currency: extract_currency(normalized_content),
            transaction_date: match(normalized_content, /(?:date|transaction date)[\s:]+([0-9]{4}-[0-9]{2}-[0-9]{2})/i),
            warnings: warnings_for(normalized_content, file_name)
          }
        end

        private

        def match(content, pattern)
          content.match(pattern)&.captures&.first&.strip
        end

        def extract_amount(content)
          match_data = content.match(/(?:amount|total)[^\d]*([$€£])?\s*([0-9]+(?:\.[0-9]{2})?)/i) ||
                       content.match(/([$€£])\s*([0-9]+(?:\.[0-9]{2})?)/i)
          return unless match_data

          match_data.captures.last.to_f
        end

        def extract_currency(content)
          return "USD" if content.match?(/\$/)
          return "EUR" if content.match?(/€/)
          return "GBP" if content.match?(/£/)

          nil
        end

        def warnings_for(content, file_name)
          warnings = []
          warnings << "No invoice or dispute identifier found" unless content.match?(/invoice|dispute/i)
          warnings << "Amount not detected" unless content.match?(/amount|total|\$|€|£/i)
          warnings << "Filename looks generic" if file_name.to_s.downcase.start_with?("scan", "document")
          warnings
        end
      end

      class ClassifyDocument < Rubot::Tool
        description "Classify a file into a finance or dispute workflow category."

        input_schema do
          string :content
          string :file_name, required: false
        end

        output_schema do
          string :category
          float :confidence
          array :reasons, of: :string
          array :warnings, of: :string
        end

        def call(content:, file_name: nil)
          combined = [file_name, content].compact.join("\n")
          category, confidence, reasons = classify(combined)

          {
            category: category,
            confidence: confidence,
            reasons: reasons,
            warnings: confidence < 0.7 ? ["Low-confidence classification"] : []
          }
        end

        private

        def classify(text)
          downcased = text.downcase

          if downcased.match?(/chargeback|dispute|cardholder/)
            ["dispute", 0.92, ["Contains dispute or chargeback language"]]
          elsif downcased.match?(/refund|reimbursement/)
            ["refund_request", 0.84, ["Contains refund language"]]
          elsif downcased.match?(/invoice|bill to|payment terms/)
            ["invoice", 0.88, ["Contains invoice language"]]
          else
            ["unknown", 0.42, ["No strong finance or dispute signals detected"]]
          end
        end
      end

      class GenerateBrief < Rubot::Tool
        description "Generate an operator-ready brief from extracted file data."

        input_schema do
          string :file_name
          string :category
          float :confidence
          string :invoice_id, required: false
          string :dispute_id, required: false
          string :customer_name, required: false
          float :amount, required: false
          string :currency, required: false
          string :transaction_date, required: false
          array :warnings, of: :string, required: false
        end

        output_schema do
          string :headline
          string :summary
          string :recommended_action
          float :confidence
          array :warnings, of: :string
        end

        def call(file_name:, category:, confidence:, invoice_id: nil, dispute_id: nil, customer_name: nil, amount: nil, currency: nil, transaction_date: nil, warnings: [])
          identifier = dispute_id || invoice_id || file_name
          formatted_amount = amount ? "#{currency || 'USD'} #{format('%.2f', amount)}" : "amount not found"

          {
            headline: "#{category.tr('_', ' ').capitalize} review for #{identifier}",
            summary: [
              ("Customer: #{customer_name}" if customer_name),
              "Document: #{file_name}",
              "Category: #{category}",
              "Amount: #{formatted_amount}",
              ("Date: #{transaction_date}" if transaction_date)
            ].compact.join(" | "),
            recommended_action: recommended_action_for(category, confidence),
            confidence: confidence,
            warnings: Array(warnings)
          }
        end

        private

        def recommended_action_for(category, confidence)
          return "manual_review" if confidence < 0.65 || category == "unknown"

          case category
          when "dispute"
            "prepare_dispute_response"
          when "invoice"
            "route_to_finance_review"
          when "refund_request"
            "route_to_refund_queue"
          else
            "manual_review"
          end
        end
      end
    end
  end
end
