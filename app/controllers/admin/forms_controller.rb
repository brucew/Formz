module Admin
  class FormsController < Admin::BaseController
    before_action :set_form, only: %i[show edit update destroy]
    before_action :refuse_deleted_form, only: %i[edit update]

    # Deleted forms stay in this list. They are the admin's own history, and their
    # submissions are still readable and exportable.
    def index
      @forms = current_user.forms.includes(:fields, :submissions).order(created_at: :desc)
    end

    def show
    end

    def new
      @form = current_user.forms.build
    end

    def create
      @form = current_user.forms.build(form_params)

      if @form.save
        redirect_to admin_form_path(@form), notice: "#{@form.name} is ready to fill out."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @form.update(form_params)
        redirect_to admin_form_path(@form), notice: "#{@form.name} has been updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    # Nothing is ever destroyed: the form leaves the member list and keeps its answers.
    def destroy
      @form.soft_delete

      redirect_to admin_forms_path,
                  notice: "#{@form.name} is hidden from members. Its submissions are kept."
    end

    private

      # Scoping through the association means another admin's form is missing from the
      # query itself rather than relying on a permission check further down.
      def set_form
        @form = current_user.forms.find(params[:id])
      end

      def refuse_deleted_form
        return unless @form.deleted?

        redirect_to admin_form_path(@form),
                    alert: "#{@form.name} is deleted, so it can no longer be edited."
      end

      def form_params
        params.require(:form).permit(
          :name, :description,
          fields_attributes: %i[id label description input_type value_type choices_text required _destroy]
        )
      end
  end
end
