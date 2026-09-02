require "application_system_test_case"

class FillingOutAFormTest < ApplicationSystemTestCase
  test "a member answers every kind of question and sees what they submitted" do
    sign_in_as users(:member)
    visit form_path(forms(:survey))
    click_on "Fill out this form"

    fill_in answer_field_name(fields(:full_name)), with: "Ada Lovelace"
    fill_in answer_field_name(fields(:years_experience)), with: "7"
    select "Engineering", from: answer_field_name(fields(:team))
    check "Gym"
    check "Transit"

    click_on "Submit answers"

    assert_text "Ada Lovelace"
    assert_text "Gym, Transit"

    submission = users(:member).submissions.find_by(form: forms(:survey))

    assert_equal "Ada Lovelace", submission.answer_for(fields(:full_name))
    assert_equal BigDecimal("7"), submission.answer_for(fields(:years_experience))
    assert_equal [ "Gym", "Transit" ], submission.answer_for(fields(:perks))
  end

  # The server rejects a missing required answer too — that is covered in
  # SubmissionsControllerTest. What only exists in the browser is this first guard.
  test "the browser stops a submit that is missing a required answer" do
    sign_in_as users(:member)
    visit new_form_submission_path(forms(:survey))

    fill_in answer_field_name(fields(:years_experience)), with: "3"
    click_on "Submit answers"

    assert_selector "button[type=submit], input[type=submit]"
    assert_equal "3", find_field(answer_field_name(fields(:years_experience))).value
    assert_not find_field(answer_field_name(fields(:full_name))).native.property("validity")["valid"]
    assert_nil users(:member).submissions.find_by(form: forms(:survey))
  end
end
