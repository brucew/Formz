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
    give_a_question_to forms(:other_admins_form)
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
    give_a_question_to forms(:other_admins_form)
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

  test "show offers an owning admin a link to manage the form" do
    sign_in_as users(:admin)

    get form_path(forms(:survey))

    assert_response :success
    assert_select "a[href=?]", admin_form_path(forms(:survey)), text: "Manage"
  end

  test "show offers no management link for a form another admin owns" do
    give_a_question_to forms(:other_admins_form)
    sign_in_as users(:admin)

    get form_path(forms(:other_admins_form))

    assert_response :success
    assert_select "a", text: "Manage", count: 0
  end

  test "show offers a member no management link" do
    sign_in_as users(:member)

    get form_path(forms(:survey))

    assert_response :success
    assert_select "a", text: "Manage", count: 0
  end

  test "show says the form belongs to the admin reading it" do
    sign_in_as users(:admin)

    get form_path(forms(:survey))

    assert_select "p", text: /Yours/
    assert_no_match(/From #{users(:admin).email}/, response.body)
  end

  test "show names the owner of a form the reader does not own" do
    sign_in_as users(:member)

    get form_path(forms(:survey))

    assert_match "From #{forms(:survey).owner.email}", response.body
  end

  test "each row action link names the form it acts on" do
    sign_in_as users(:member)

    get forms_path

    assert_select "a[href=?][aria-label=?]",
                  new_form_submission_path(forms(:survey)), "Fill out #{forms(:survey).name}"
    assert_select "a[href=?][aria-label=?]",
                  form_submission_path(forms(:locked_form)), "View your answers to #{forms(:locked_form).name}"
  end

  test "the manage link names the form it manages" do
    sign_in_as users(:admin)

    get forms_path

    assert_select "a[href=?][aria-label=?]",
                  admin_form_path(forms(:survey)), "Manage #{forms(:survey).name}"
  end

  test "index hides a form with no questions from everyone but its owner" do
    sign_in_as users(:member)

    get forms_path

    assert_select "a[href=?]", form_path(forms(:other_admins_form)), count: 0
  end

  test "index still shows the owner their own form with no questions" do
    sign_in_as users(:other_admin)

    get forms_path

    assert_select "a[href=?]", form_path(forms(:other_admins_form))
    assert_select "a[href=?]", edit_admin_form_path(forms(:other_admins_form))
    assert_select ".badge", text: "Needs questions"
  end

  test "show refuses a form with no questions to anyone but its owner" do
    sign_in_as users(:member)

    get form_path(forms(:other_admins_form))

    assert_response :not_found
  end

  test "show offers the owner of an unfinished form a way to add questions" do
    sign_in_as users(:other_admin)

    get form_path(forms(:other_admins_form))

    assert_response :success
    assert_select "a[href=?]", edit_admin_form_path(forms(:other_admins_form))
    assert_select "a", text: "Fill out this form", count: 0
  end

  private

    # Fixtures deliberately keep a couple of forms empty, so a test that needs an
    # answerable one asks for a question rather than mutating the shared fixture file.
    def give_a_question_to(form)
      form.update!(fields_attributes: [
        { label: "Your name", input_type: "text_field", value_type: "string" }
      ])
      form
    end
end
