# frozen_string_literal: true

module ResumeScreener
  class Workflow < Rubot::Workflow
    tool_step :load_job,
              tool: ResumeScreener::LoadJobDescriptionTool,
              input: ->(input, _state, _context) { { job_id: input[:job_id] } }

    tool_step :prepare_resume,
              tool: ResumeScreener::PrepareResumeTool,
              input: lambda { |input, _state, _context|
                {
                  candidate_name: input[:candidate_name],
                  resume_text: input[:resume_text],
                  file_name: input[:file_name],
                  content_type: input[:content_type]
                }
              }

    agent_step :screen_resume,
               agent: ResumeScreener::ScreeningAgent,
               input: lambda { |_input, state, _context|
                 job = state.fetch(:load_job)
                 resume = state.fetch(:prepare_resume)
                 {
                   job_id: job[:job_id],
                   job_title: job[:title],
                   job_team: job[:team],
                   job_location: job[:location],
                   job_summary: job[:summary],
                   must_haves: job[:must_haves],
                   preferred: job[:preferred],
                   candidate_name: resume[:candidate_name],
                   resume_text: resume[:resume_text],
                   word_count: resume[:word_count],
                   resume_highlights: resume[:highlights]
                 }
               },
               save_as: :screening

    step :finalize

    def finalize
      run.state[:finalize] = {
        job: run.state.fetch(:load_job),
        resume: run.state.fetch(:prepare_resume),
        screening: run.state.fetch(:screening)
      }
    end
  end
end
