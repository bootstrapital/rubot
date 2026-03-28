# frozen_string_literal: true

module Examples
  module YamlPromptEval
    class SupportTriageAgent < Rubot::Agent
      # Rubot will automatically look for support_triage_agent.yml in the same directory.
      # Use config_file to specify an explicit path if needed.

      input_schema do
        string :message
        string :customer_tier, optional: true
      end

      output_schema do
        string :category, values: %w[billing technical general]
        string :priority, values: %w[low normal high urgent]
      end

      # No instructions or model defined here; they are in support_triage_agent.yml
    end
  end
end
