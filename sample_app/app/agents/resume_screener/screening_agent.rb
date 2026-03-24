# frozen_string_literal: true

module ResumeScreener
  class ScreeningAgent < Rubot::Agent
    instructions do
      <<~PROMPT
        You are a recruiting screener. Review the candidate resume against the selected job description.
        Be concrete and fair. Prefer evidence from the resume over generic praise.
        Return structured output only.
      PROMPT
    end

    model "gemini-3-flash-preview"

    input_schema do
      string :job_id
      string :job_title
      string :job_team
      string :job_location
      string :job_summary
      array :must_haves, of: :string
      array :preferred, of: :string
      string :candidate_name, required: false
      string :resume_text
      integer :word_count
      array :resume_highlights, of: :string
    end

    output_schema do
      string :candidate_name
      string :recommendation
      float :match_score
      string :summary
      array :strengths, of: :string
      array :concerns, of: :string
      array :interview_questions, of: :string
      float :confidence
      array :warnings, of: :string
    end

    def perform(input:, run:, context:)
      return super(input:, run:, context:) if Rubot.provider

      heuristic_screen(input)
    end

    private

    def heuristic_screen(input)
      resume_text = input[:resume_text].downcase
      must_hits = input[:must_haves].count { |term| resume_text.include?(term.downcase) }
      preferred_hits = input[:preferred].count { |term| resume_text.include?(term.downcase) }

      must_ratio = ratio(must_hits, input[:must_haves].length)
      preferred_ratio = ratio(preferred_hits, input[:preferred].length)
      match_score = ((must_ratio * 0.75) + (preferred_ratio * 0.25)).round(2)

      recommendation =
        if match_score >= 0.75
          "strong_yes"
        elsif match_score >= 0.5
          "lean_yes"
        elsif match_score >= 0.3
          "mixed"
        else
          "no"
        end

      {
        candidate_name: input[:candidate_name].presence || "Candidate",
        recommendation: recommendation,
        match_score: match_score,
        summary: summary_for(input, match_score, must_hits, preferred_hits),
        strengths: matched_terms(input[:must_haves] + input[:preferred], resume_text).first(4),
        concerns: missing_terms(input[:must_haves], resume_text).first(3),
        interview_questions: build_questions(input),
        confidence: heuristic_confidence(input, resume_text),
        warnings: heuristic_warnings(input, resume_text)
      }
    end

    def ratio(value, total)
      return 0.0 if total.zero?

      value.to_f / total
    end

    def matched_terms(terms, resume_text)
      terms.select { |term| resume_text.include?(term.downcase) }.map { |term| "Evidence of #{term}" }
    end

    def missing_terms(terms, resume_text)
      terms.reject { |term| resume_text.include?(term.downcase) }.map { |term| "Resume does not clearly show #{term}" }
    end

    def build_questions(input)
      questions = []
      questions << "Tell me about your hands-on work with #{input[:must_haves].first}." if input[:must_haves].any?
      questions << "Which recent project best shows fit for #{input[:job_title]}?"
      questions << "What kind of team collaboration have you done in similar roles?"
      questions
    end

    def heuristic_confidence(input, resume_text)
      score = 0.55
      score += 0.1 if input[:word_count].to_i > 250
      score += 0.1 if matched_terms(input[:must_haves], resume_text).any?
      score += 0.1 if matched_terms(input[:preferred], resume_text).any?
      [score, 0.9].min.round(2)
    end

    def heuristic_warnings(input, resume_text)
      warnings = []
      warnings << "Resume is short; confidence is limited." if input[:word_count].to_i < 120
      warnings << "Several must-have requirements were not obvious in the resume." if missing_terms(input[:must_haves], resume_text).length >= 2
      warnings
    end

    def summary_for(input, match_score, must_hits, preferred_hits)
      "Scored #{match_score} for #{input[:job_title]}. Matched #{must_hits} must-have and #{preferred_hits} preferred signals from the submitted resume."
    end
  end
end
