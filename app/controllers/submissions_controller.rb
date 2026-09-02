class SubmissionsController < ApplicationController
  before_action :set_answerable_form, except: :show
  before_action :redirect_to_existing_submission, except: :show

  def new
    @submission = current_user.submissions.new(form: @form)
  end

  def create
    @submission = current_user.submissions.new(submission_params)
    @submission.form = @form

    if @submission.save
      redirect_to form_submission_path(@form), notice: "Thanks, your answers have been saved."
    else
      render :new, status: :unprocessable_content
    end
  end

  # Scoped through current_user, so one person's answers are never reachable from
  # another person's session. A deleted form is still readable here: the form someone
  # answered should not vanish from under them.
  def show
    @submission = current_user.submissions.includes(form: :fields).find_by!(form_id: params[:form_id])
    @form = @submission.form
  end

  private

    # Answering a form with no questions would store an empty submission, and that alone
    # locks the form's structure — leaving its owner unable to ever add the questions.
    def set_answerable_form
      @form = Form.find(params[:form_id])
      return if @form.answerable?

      redirect_to forms_path, alert: answer_refusal_for(@form)
    end

    def answer_refusal_for(form)
      return "That form has been deleted and can no longer be filled out." unless form.active?

      "That form has no questions yet, so there is nothing to answer."
    end

    def redirect_to_existing_submission
      return unless current_user.submitted?(@form)

      redirect_to form_submission_path(@form), notice: "You have already filled out this form."
    end

    # fetch rather than require because a form with no fields yet renders no inputs at
    # all, so the submission key is legitimately absent from the post.
    def submission_params
      params.fetch(:submission, {}).permit(values: permitted_value_keys)
    end

    # The allowlist is built from the form's own fields, so an answer for anything else
    # is dropped before it reaches the model. A check box field submits an array.
    def permitted_value_keys
      @form.fields.map do |field|
        field.input_check_box? ? { field.id.to_s => [] } : field.id.to_s
      end
    end
end
