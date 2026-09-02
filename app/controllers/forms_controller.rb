class FormsController < ApplicationController
  def index
    @forms = Form.active.includes(:owner).order(created_at: :desc)
    # Gathered once rather than asking current_user.submitted?(form) per row.
    @submitted_form_ids = current_user.submissions.pluck(:form_id).to_set
  end

  def show
    @form = Form.active.includes(:fields).find(params[:id])
    @already_submitted = current_user.submitted?(@form)
  end
end
