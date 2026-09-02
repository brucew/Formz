class FormsController < ApplicationController
  def index
    @forms = Form.answerable_or_owned_by(current_user).includes(:owner, :fields).order(created_at: :desc)
    # Gathered once rather than asking current_user.submitted?(form) per row.
    @submitted_form_ids = current_user.submissions.pluck(:form_id).to_set
  end

  def show
    @form = Form.answerable_or_owned_by(current_user).includes(:fields).find(params[:id])
    @already_submitted = current_user.submitted?(@form)
  end
end
