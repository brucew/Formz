require "test_helper"

class FormsControllerTest < ActionDispatch::IntegrationTest
  test "index sends a signed out visitor to sign in" do
    get forms_path

    assert_redirected_to new_user_session_path
  end

  test "show sends a signed out visitor to sign in" do
    get form_path(forms(:survey))

    assert_redirected_to new_user_session_path
  end

  test "index lists active forms from every admin" do
    sign_in_as users(:member)

    get forms_path

    assert_response :success
    assert_select "a[href=?]", form_path(forms(:survey))
    assert_select "a[href=?]", form_path(forms(:other_admins_form))
    assert_select "a[href=?]", form_path(forms(:locked_form))
  end

  test "index leaves out a deleted form" do
    sign_in_as users(:member)

    get forms_path

    assert_select "a[href=?]", form_path(forms(:deleted_form)), count: 0
    assert_no_match forms(:deleted_form).name, response.body
  end

  test "index says which forms have already been filled out" do
    sign_in_as users(:member)

    get forms_path

    assert_select "a[href=?]", form_submission_path(forms(:locked_form))
    assert_select "a[href=?]", new_form_submission_path(forms(:survey))
    assert_select "a[href=?]", new_form_submission_path(forms(:locked_form)), count: 0
  end

  test "show lists the questions and marks the required ones" do
    sign_in_as users(:member)

    get form_path(forms(:survey))

    assert_response :success
    assert_select "h1", forms(:survey).name
    assert_select ".badge-required", 1
    assert_select "a[href=?]", new_form_submission_path(forms(:survey))
    forms(:survey).fields.each { |field| assert_match field.label, response.body }
  end

  test "show links to the answers a user has already given" do
    sign_in_as users(:member)

    get form_path(forms(:locked_form))

    assert_response :success
    assert_select "a[href=?]", form_submission_path(forms(:locked_form))
    assert_select "a[href=?]", new_form_submission_path(forms(:locked_form)), count: 0
  end

  test "show refuses a deleted form even by direct url" do
    sign_in_as users(:member)

    get form_path(forms(:deleted_form))

    assert_response :not_found
  end

  test "show is reachable for a form owned by another admin" do
    sign_in_as users(:member)

    get form_path(forms(:other_admins_form))

    assert_response :success
  end

  test "an admin can reach the management page for a form they own" do
    sign_in_as users(:admin)
    get forms_path

    assert_select "a[href=?]", admin_form_path(forms(:survey)), text: "Manage"
    assert_select "a[href=?]", admin_form_path(forms(:other_admins_form)), count: 0
  end

  test "a member is offered no management link" do
    sign_in_as users(:member)
    get forms_path

    assert_select "a", text: "Manage", count: 0
  end

  test "the list says which forms belong to the admin reading it" do
    sign_in_as users(:admin)
    get forms_path

    assert_select "li", text: /Yours/
  end
end
