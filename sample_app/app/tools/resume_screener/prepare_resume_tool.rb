# frozen_string_literal: true

module ResumeScreener
  class PrepareResumeTool < Rubot::Tool
    input_schema do
      string :resume_text
      string :candidate_name, required: false
      string :file_name, required: false
      string :content_type, required: false
    end

    output_schema do
      string :candidate_name, required: false
      string :resume_text
      string :file_name, required: false
      string :content_type, required: false
      integer :word_count
      array :highlights, of: :string
    end

    def call(resume_text:, candidate_name: nil, file_name: nil, content_type: nil)
      normalized_text = resume_text.to_s.strip
      raise Rubot::ValidationError, "Resume text cannot be blank" if normalized_text.empty?

      {
        candidate_name: candidate_name.presence || infer_candidate_name(normalized_text),
        resume_text: normalized_text,
        file_name: file_name,
        content_type: content_type,
        word_count: normalized_text.split(/\s+/).length,
        highlights: extract_highlights(normalized_text)
      }
    end

    private

    def infer_candidate_name(text)
      first_line = text.lines.first.to_s.strip
      return if first_line.empty? || first_line.length > 80

      first_line
    end

    def extract_highlights(text)
      text.lines.map(&:strip).reject(&:empty?).first(5)
    end
  end
end
