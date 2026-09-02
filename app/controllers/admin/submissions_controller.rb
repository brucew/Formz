module Admin
  class SubmissionsController < Admin::BaseController
    # Deleted forms are deliberately in scope here. A form that has stopped collecting
    # answers still has to be reviewable and exportable.
    def index
      @form = current_user.forms.find(params[:form_id])

      respond_to do |format|
        format.html { @submissions = @form.submissions.includes(:user).order(:created_at).load }
        format.csv do
          send_data @form.submissions_csv, filename: csv_filename, type: "text/csv"
        end
      end
    end

    private

      def csv_filename
        "#{@form.name.parameterize.presence || 'form'}-submissions.csv"
      end
  end
end
