module Admin
  class AnalysesController < Admin::BaseController
    # Deleted forms are analysable for the same reason they stay exportable: a form that
    # has stopped collecting answers still has answers worth reading.
    def show
      @form = current_user.forms.includes(:fields).find(params[:form_id])
      @analysis = @form.analysis
    end
  end
end
