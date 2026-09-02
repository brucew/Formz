require "test_helper"

class LayoutTest < ActionDispatch::IntegrationTest
  test "the sign in page renders without a signed in user" do
    get new_user_session_path

    assert_response :success
    assert_select "header", count: 0
    assert_select "nav[aria-label=?]", "Main", count: 0
  end

  test "a signed in member sees the navigation and their email" do
    sign_in_as users(:member)
    get forms_path

    assert_select "nav[aria-label=?]", "Main"
    assert_select "header", text: /member@example\.com/
    assert_select ".badge-admin", count: 0
  end

  test "a signed in admin sees the admin badge and a link to their own forms" do
    sign_in_as users(:admin)
    get forms_path

    assert_select ".badge-admin", text: "Admin"
    assert_select "nav a[href=?]", admin_forms_path
  end

  test "the navigation marks the section being viewed" do
    sign_in_as users(:admin)

    get forms_path

    assert_select "nav a[href=?][aria-current=page]", forms_path
    assert_select "nav a[href=?][aria-current=page]", admin_forms_path, count: 0

    get admin_forms_path

    assert_select "nav a[href=?][aria-current=page]", admin_forms_path
  end

  test "the page header renders its title without leaking template text" do
    sign_in_as users(:member)
    get forms_path

    assert_select "h1.page-title"
    assert_no_match(/end %>/, response.body)
  end
end
