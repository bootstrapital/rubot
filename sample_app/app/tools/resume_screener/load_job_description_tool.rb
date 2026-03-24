# frozen_string_literal: true

module ResumeScreener
  class LoadJobDescriptionTool < Rubot::Tool
    input_schema do
      string :job_id
    end

    output_schema do
      string :job_id
      string :title
      string :team
      string :location
      string :summary
      array :must_haves, of: :string
      array :preferred, of: :string
    end

    def call(job_id:)
      details = ResumeScreener::Operation.job_description(job_id)
      details.merge(job_id: job_id)
    rescue KeyError
      raise Rubot::ValidationError, "Unknown job description #{job_id}"
    end
  end
end
