# frozen_string_literal: true

class ResumeScreenersController < ApplicationController
  def show
    @job_options = ResumeScreenerOperation.job_options
    @selected_job_id = params[:job_id].presence || @job_options.first&.last
    @job_description = ResumeScreenerOperation.job_description(@selected_job_id)
    @resume_text = params[:resume_text].to_s
    @candidate_name = params[:candidate_name].to_s
  end

  def create
    @job_options = ResumeScreenerOperation.job_options
    @selected_job_id = screener_params[:job_id]
    @job_description = ResumeScreenerOperation.job_description(@selected_job_id)
    @candidate_name = screener_params[:candidate_name].to_s
    @resume_text = resolve_resume_text

    if @resume_text.blank?
      @error_message = "Provide resume text or upload a text-based resume file."
      return render :show, status: :unprocessable_entity
    end

    @run = ResumeScreenerOperation.launch(
      payload: {
        job_id: @selected_job_id,
        candidate_name: @candidate_name,
        resume_text: @resume_text,
        file_name: uploaded_file&.original_filename,
        content_type: uploaded_file&.content_type
      },
      context: {
        submitted_from: "sample_app"
      }
    )
  rescue Rubot::ValidationError, Rubot::ExecutionError => e
    @error_message = e.message
    render :show, status: :unprocessable_entity
  end

  private

  def screener_params
    params.permit(:job_id, :candidate_name, :resume_text, :resume_file)
  end

  def uploaded_file
    @uploaded_file ||= screener_params[:resume_file]
  end

  def resolve_resume_text
    direct_text = screener_params[:resume_text].to_s
    return direct_text if direct_text.strip != ""
    return "" unless uploaded_file

    content_type = uploaded_file.content_type.to_s
    filename = uploaded_file.original_filename.to_s.downcase

    unless text_upload?(content_type, filename)
      raise Rubot::ExecutionError, "This demo supports .txt and .md uploads. Paste PDF content into the text area for now."
    end

    uploaded_file.read
  end

  def text_upload?(content_type, filename)
    content_type.start_with?("text/") || filename.end_with?(".txt", ".md", ".text")
  end
end
