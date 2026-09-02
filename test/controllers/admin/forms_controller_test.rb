require "test_helper"

class Admin::FormsControllerTest < ActionDispatch::IntegrationTest
  test "a signed out visitor is sent to sign in" do
    get admin_forms_path

    assert_redirected_to new_user_session_path
  end

  test "a member is refused" do
    sign_in_as(users(:member))

    get admin_forms_path

    assert_redirected_to root_path
    assert_equal "That area is for administrators.", flash[:alert]
  end

  test "the index lists this admin's forms, deleted ones included, and nobody else's" do
    sign_in_as(users(:admin))

    get admin_forms_path

    assert_response :success
    assert_select "a[href=?]", admin_form_path(forms(:survey))
    assert_select "a[href=?]", admin_form_path(forms(:locked_form))
    assert_select "a[href=?]", admin_form_path(forms(:deleted_form))
    assert_select "a[href=?]", admin_form_path(forms(:other_admins_form)), count: 0
  end

  test "a deleted form is marked as deleted on the index and offers no edit link" do
    sign_in_as(users(:admin))

    get admin_forms_path

    assert_select ".badge-deleted", text: "Deleted"
    assert_select "a[href=?]", edit_admin_form_path(forms(:deleted_form)), count: 0
    assert_select "a[href=?]", edit_admin_form_path(forms(:survey))
  end

  test "the show page lists the fields of an owned form" do
    sign_in_as(users(:admin))

    get admin_form_path(forms(:survey))

    assert_response :success
    assert_select "h3", text: /Full name/
    assert_select "h3", text: /Team/
  end

  # The lookup runs through current_user.forms, so another admin's form is missing from
  # the query itself. Rails turns that RecordNotFound into a 404 in this environment
  # rather than re-raising it.
  test "an admin cannot show a form owned by another admin" do
    sign_in_as(users(:admin))

    get admin_form_path(forms(:other_admins_form))

    assert_response :not_found
  end

  test "an admin cannot edit a form owned by another admin" do
    sign_in_as(users(:admin))

    get edit_admin_form_path(forms(:other_admins_form))

    assert_response :not_found
  end

  test "the new page renders an empty field editor with a template row" do
    sign_in_as(users(:admin))

    get new_admin_form_path

    assert_response :success
    assert_select "template[data-nested-fields-target=?]", "template"
    assert_select "[data-nested-fields-target='rows'] > [data-nested-fields-target=?]", "row",
                  count: 0
  end

  test "the edit page renders one editable row per field" do
    sign_in_as(users(:admin))

    get edit_admin_form_path(forms(:survey))

    assert_response :success
    assert_select "[data-nested-fields-target='rows'] > [data-nested-fields-target=?]", "row",
                  count: forms(:survey).fields.count
    assert_select "textarea[name=?]", "form[fields_attributes][3][choices_text]",
                  text: "Design\nEngineering\nSupport"
  end

  test "the editor of a form with submissions is read only and says why" do
    sign_in_as(users(:admin))

    get edit_admin_form_path(forms(:locked_form))

    assert_response :success
    assert_select "input[name=?]", "form[name]"
    assert_select "[data-nested-fields-target=?]", "row", count: 0
    assert_select "p", text: /already\s+answered this form, so its fields are fixed/
  end

  test "creating a form with fields of several types" do
    sign_in_as(users(:admin))

    assert_difference "Form.count", 1 do
      assert_difference "Field.count", 3 do
        post admin_forms_path, params: { form: {
          name: "Onboarding",
          description: "How your first week went",
          fields_attributes: {
            "0" => { label: "Full name", input_type: "text_field", value_type: "string",
                     required: "1", choices_text: "" },
            "1" => { label: "Days on site", input_type: "number_field", value_type: "number",
                     required: "0", choices_text: "" },
            "2" => { label: "Team", input_type: "select", value_type: "string",
                     required: "0", choices_text: "Design\nEngineering" }
          }
        } }
      end
    end

    form = Form.find_by(name: "Onboarding")

    assert_redirected_to admin_form_path(form)
    assert_equal users(:admin), form.owner
    assert_equal [ "Full name", "Days on site", "Team" ], form.fields.map(&:label)
    assert_equal [ 1, 2, 3 ], form.fields.map(&:position)
    assert form.fields.first.required?
    assert form.fields.second.input_number_field?
    assert_equal %w[Design Engineering], form.fields.third.choices
  end

  test "creating a form with a choice field that has no choices saves nothing" do
    sign_in_as(users(:admin))

    assert_no_difference [ "Form.count", "Field.count" ] do
      post admin_forms_path, params: { form: {
        name: "Broken",
        fields_attributes: {
          "0" => { label: "Team", input_type: "select", value_type: "string",
                   required: "0", choices_text: "" }
        }
      } }
    end

    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /choices must list at least one option/
  end

  test "a field can be removed from a form nobody has answered" do
    sign_in_as(users(:admin))
    survey = forms(:survey)

    assert_difference "Field.count", -1 do
      patch admin_form_path(survey), params: { form: {
        name: survey.name,
        fields_attributes: { "0" => { id: fields(:perks).id, _destroy: "1" } }
      } }
    end

    assert_redirected_to admin_form_path(survey)
    assert_not_includes survey.reload.fields, fields(:perks)
  end

  test "renaming a form that has submissions is allowed" do
    sign_in_as(users(:admin))
    locked = forms(:locked_form)

    patch admin_form_path(locked), params: { form: { name: "Renamed", description: "Still open" } }

    assert_redirected_to admin_form_path(locked)
    assert_equal "Renamed", locked.reload.name
    assert_equal "Still open", locked.description
  end

  test "adding a field to a form that has submissions is refused" do
    sign_in_as(users(:admin))
    locked = forms(:locked_form)

    assert_no_difference "Field.count" do
      patch admin_form_path(locked), params: { form: {
        name: locked.name,
        fields_attributes: {
          "0" => { label: "Late question", input_type: "text_field", value_type: "string",
                   required: "0", choices_text: "" }
        }
      } }
    end

    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /Fields cannot be changed/
  end

  test "editing a deleted form is refused with an explanation" do
    sign_in_as(users(:admin))
    deleted = forms(:deleted_form)

    get edit_admin_form_path(deleted)

    assert_redirected_to admin_form_path(deleted)
    assert_equal "#{deleted.name} is deleted, so it can no longer be edited.", flash[:alert]

    patch admin_form_path(deleted), params: { form: { name: "Back from the dead" } }

    assert_redirected_to admin_form_path(deleted)
    assert_equal "Deleted form", deleted.reload.name
  end

  test "a form with submissions can still be deleted" do
    sign_in_as(users(:admin))
    locked = forms(:locked_form)

    assert_no_difference "Submission.count" do
      delete admin_form_path(locked)
    end

    assert_redirected_to admin_forms_path
    assert locked.reload.deleted?
  end

  test "destroying a form hides it rather than deleting it" do
    sign_in_as(users(:admin))
    survey = forms(:survey)

    assert_no_difference [ "Form.count", "Field.count" ] do
      delete admin_form_path(survey)
    end

    assert_redirected_to admin_forms_path
    assert_not survey.reload.active?
    assert survey.deleted?
  end
end
