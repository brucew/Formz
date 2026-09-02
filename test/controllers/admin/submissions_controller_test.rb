require "test_helper"
require "csv"

class Admin::SubmissionsControllerTest < ActionDispatch::IntegrationTest
  test "a signed out visitor is sent to sign in" do
    get admin_form_submissions_path(forms(:survey))

    assert_redirected_to new_user_session_path
  end

  test "a member is refused" do
    sign_in_as(users(:member))

    get admin_form_submissions_path(forms(:survey))

    assert_redirected_to root_path
    assert_equal "That area is for administrators.", flash[:alert]
  end

  test "an admin cannot reach the submissions of a form they do not own" do
    sign_in_as(users(:admin))

    # The lookup runs through current_user.forms, so another admin's form is missing
    # from the query itself. Rails turns that RecordNotFound into a 404 in this
    # environment rather than re-raising it.
    get admin_form_submissions_path(forms(:other_admins_form))

    assert_response :not_found
  end

  test "the index lists every submission with its submitter and answers" do
    sign_in_as(users(:admin))

    get admin_form_submissions_path(forms(:locked_form))

    assert_response :success
    assert_select "th", text: "Note"
    assert_select "td", text: users(:member).email
    assert_select "td", text: "Already answered"
  end

  test "the index offers the csv download and a way back to the form" do
    sign_in_as(users(:admin))
    locked = forms(:locked_form)

    get admin_form_submissions_path(locked)

    assert_select "a[href=?]", admin_form_submissions_path(locked, format: :csv),
                  text: "Download CSV"
    assert_select "a[href=?]", admin_form_path(locked), text: "Back to form"
  end

  # The table is one column per field, so it is wide on purpose and scrolls inside its
  # own card. That scrolling has to be reachable without a mouse.
  test "the wide submissions table is a named region a keyboard can reach" do
    sign_in_as(users(:admin))

    get admin_form_submissions_path(forms(:locked_form))

    assert_select "[role=region][tabindex=?]", "0" do
      assert_select "table"
    end
    assert_select "[role=region][aria-label=?]", "Locked form submissions"
  end

  test "an unanswered field is spelled out rather than left as a dash alone" do
    sign_in_as(users(:admin))
    Submission.create!(form: forms(:survey), user: users(:another_member),
                       values: { fields(:full_name).id.to_s => "Nobody" })

    get admin_form_submissions_path(forms(:survey))

    assert_select "td span.sr-only", text: "No answer"
  end

  test "the csv export carries the header row and every answer" do
    sign_in_as(users(:admin))

    get admin_form_submissions_path(forms(:locked_form), format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match "locked-form-submissions.csv", response.headers["Content-Disposition"]

    rows = CSV.parse(response.body)

    assert_equal [ "Submitted by", "Submitted at", "Note" ], rows.first
    assert_equal 2, rows.size
    assert_equal users(:member).email, rows.second.first
    assert_equal "Already answered", rows.second.last
  end

  test "a deleted form still shows its submissions and says that it is deleted" do
    submission = create_submission_on_deleted_form
    sign_in_as(users(:admin))

    get admin_form_submissions_path(forms(:deleted_form))

    assert_response :success
    assert_select "span.badge-deleted", text: "Deleted"
    assert_select "td", text: submission.user.email
  end

  test "a deleted form is still exportable" do
    submission = create_submission_on_deleted_form
    sign_in_as(users(:admin))

    get admin_form_submissions_path(forms(:deleted_form), format: :csv)

    assert_response :success

    rows = CSV.parse(response.body)

    assert_equal [ "Submitted by", "Submitted at" ], rows.first
    assert_equal [ submission.user.email, submission.created_at.iso8601 ], rows.second
  end

  test "a form nobody has answered renders the empty state" do
    sign_in_as(users(:admin))

    get admin_form_submissions_path(forms(:survey))

    assert_response :success
    assert_select "h2", text: "No submissions yet"
    assert_select "table", count: 0
    assert_select "a[href=?]", admin_form_submissions_path(forms(:survey), format: :csv),
                  count: 0
    assert_select "a[href=?]", admin_form_path(forms(:survey)), text: "Back to form"
  end

  private

    # No fixture pairs a deleted form with a submission, and the deleted form has no
    # fields, so an empty set of answers is a valid one.
    def create_submission_on_deleted_form
      Submission.create!(form: forms(:deleted_form), user: users(:member), values: {})
    end
end
