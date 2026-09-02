require "test_helper"

class SubmissionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @survey = forms(:survey)
    @full_name = fields(:full_name)
  end

  test "new sends a signed out visitor to sign in" do
    get new_form_submission_path(@survey)

    assert_redirected_to new_user_session_path
  end

  test "create sends a signed out visitor to sign in and saves nothing" do
    assert_no_difference -> { Submission.count } do
      post form_submission_path(@survey), params: { submission: { values: { @full_name.id.to_s => "Nobody" } } }
    end

    assert_redirected_to new_user_session_path
  end

  test "show sends a signed out visitor to sign in" do
    get form_submission_path(forms(:locked_form))

    assert_redirected_to new_user_session_path
  end

  test "new renders an input for every field" do
    sign_in_as users(:member)

    get new_form_submission_path(@survey)

    assert_response :success
    assert_select "input[name=?][required]", "submission[values][#{@full_name.id}]"
    assert_select "input[name=?]", "submission[values][#{fields(:years_experience).id}]"
    assert_select "select[name=?]", "submission[values][#{fields(:team).id}]"
    assert_select "input[type=checkbox][name=?]", "submission[values][#{fields(:perks).id}][]", 2
    assert_select "fieldset[role=group][aria-required=false]", 1
  end

  test "create stores answers cast to their value types" do
    sign_in_as users(:member)

    post form_submission_path(@survey), params: { submission: { values: {
      @full_name.id.to_s => "Dana Scully",
      fields(:years_experience).id.to_s => "7",
      fields(:start_date).id.to_s => "2024-03-01",
      fields(:team).id.to_s => "Engineering",
      fields(:perks).id.to_s => [ "", "Gym", "Transit" ]
    } } }

    assert_redirected_to form_submission_path(@survey)
    submission = users(:member).submissions.find_by!(form: @survey)
    assert_equal "Dana Scully", submission.answer_for(@full_name)
    assert_equal BigDecimal(7), submission.answer_for(fields(:years_experience))
    assert_equal Date.new(2024, 3, 1), submission.answer_for(fields(:start_date))
    assert_equal "Engineering", submission.answer_for(fields(:team))
    assert_equal [ "Gym", "Transit" ], submission.answer_for(fields(:perks))
  end

  test "create drops an answer for a field that is not on the form" do
    sign_in_as users(:member)

    post form_submission_path(@survey), params: { submission: { values: {
      @full_name.id.to_s => "Dana Scully",
      fields(:locked_note).id.to_s => "Belongs to another form"
    } } }

    assert_redirected_to form_submission_path(@survey)
    submission = users(:member).submissions.find_by!(form: @survey)
    assert_equal [ @full_name.id.to_s ], submission.values.keys
  end

  test "create refuses a missing required answer and saves nothing" do
    sign_in_as users(:member)

    assert_no_difference -> { Submission.count } do
      post form_submission_path(@survey),
           params: { submission: { values: { fields(:team).id.to_s => "Design" } } }
    end

    assert_response :unprocessable_content
    assert_match "#{@full_name.label} is required", response.body
  end

  test "create refuses an answer that will not cast" do
    sign_in_as users(:member)

    assert_no_difference -> { Submission.count } do
      post form_submission_path(@survey), params: { submission: { values: {
        @full_name.id.to_s => "Dana Scully",
        fields(:years_experience).id.to_s => "not a number"
      } } }
    end

    assert_response :unprocessable_content
    assert_match "#{fields(:years_experience).label} must be a valid number", response.body
  end

  test "create refuses a second submission and points at the first" do
    sign_in_as users(:member)

    assert_no_difference -> { Submission.count } do
      post form_submission_path(forms(:locked_form)),
           params: { submission: { values: { fields(:locked_note).id.to_s => "Answered twice" } } }
    end

    assert_redirected_to form_submission_path(forms(:locked_form))
    assert_equal "Already answered", submissions(:member_locked_form).reload.answer_for(fields(:locked_note))
  end

  test "new sends someone who has already submitted to their answers" do
    sign_in_as users(:member)

    get new_form_submission_path(forms(:locked_form))

    assert_redirected_to form_submission_path(forms(:locked_form))
    assert_equal "You have already filled out this form.", flash[:notice]
  end

  test "new refuses a deleted form even by direct url" do
    sign_in_as users(:member)

    get new_form_submission_path(forms(:deleted_form))

    assert_redirected_to forms_path
    assert_equal "That form has been deleted and can no longer be filled out.", flash[:alert]
  end

  test "create refuses a deleted form even by direct url" do
    sign_in_as users(:member)

    assert_no_difference -> { Submission.count } do
      post form_submission_path(forms(:deleted_form))
    end

    assert_redirected_to forms_path
  end

  test "show renders the current user's own answers" do
    sign_in_as users(:member)

    get form_submission_path(forms(:locked_form))

    assert_response :success
    assert_select "dt", fields(:locked_note).label
    assert_match "Already answered", response.body
  end

  test "show hides another user's answers" do
    sign_in_as users(:another_member)

    get form_submission_path(forms(:locked_form))

    assert_response :not_found
  end

  test "show still works once the form has been deleted" do
    deleted_form = forms(:deleted_form)
    Submission.create!(form: deleted_form, user: users(:member), values: {})
    sign_in_as users(:member)

    get form_submission_path(deleted_form)

    assert_response :success
    assert_match "This form has since been deleted", response.body
  end

  test "an admin can fill out a form too" do
    sign_in_as users(:admin)

    post form_submission_path(@survey),
         params: { submission: { values: { @full_name.id.to_s => "Walter Skinner" } } }

    assert_redirected_to form_submission_path(@survey)
    assert_equal "Walter Skinner", users(:admin).submissions.find_by!(form: @survey).answer_for(@full_name)
  end
end
