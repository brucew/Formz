module Admin
  class BaseController < ApplicationController
    before_action :require_admin

    private

      def require_admin
        return if current_user.admin?

        redirect_to root_path, alert: "That area is for administrators."
      end
  end
end
