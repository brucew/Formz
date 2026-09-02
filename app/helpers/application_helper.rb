module ApplicationHelper
  # Marks the section being viewed, so an admin can tell at a glance whether they are
  # looking at the forms they own or the list everyone fills out.
  def nav_link_to(name, path)
    link_to name, path,
            class: nav_link_class(current_section?(path)),
            aria: { current: ("page" if current_section?(path)) }
  end

  private

    def current_section?(path)
      request.path == path || request.path.start_with?("#{path}/")
    end

    def nav_link_class(current)
      base = "rounded-md px-2.5 py-1.5"

      if current
        "#{base} bg-slate-100 font-semibold text-slate-900"
      else
        "#{base} font-medium text-slate-600 hover:bg-slate-50 hover:text-slate-900"
      end
    end
end
