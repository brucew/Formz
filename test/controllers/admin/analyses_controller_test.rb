require "test_helper"

class Admin::AnalysesControllerTest < ActionDispatch::IntegrationTest
  test "a signed out visitor is sent to sign in" do
    get admin_form_analysis_path(forms(:survey))

    assert_redirected_to new_user_session_path
  end

  test "a member is refused" do
    sign_in_as(users(:member))

    get admin_form_analysis_path(forms(:survey))

    assert_redirected_to root_path
    assert_equal "That area is for administrators.", flash[:alert]
  end

  test "an admin cannot analyse a form they do not own" do
    sign_in_as(users(:admin))

    # The lookup runs through current_user.forms, so another admin's form is missing
    # from the query itself rather than from a permission check further down.
    get admin_form_analysis_path(forms(:other_admins_form))

    assert_response :not_found
  end

  test "the page reports how much came in, over what period, and how completely" do
    travel_to Time.zone.local(2026, 3, 1, 9, 0) do
      submit(users(:member), full_name: "Ada", years_experience: "4",
                             start_date: "2026-03-01", team: "Design", perks: %w[Gym])
    end
    travel_to Time.zone.local(2026, 3, 3, 9, 0) do
      submit(users(:another_member), full_name: "Grace")
    end
    sign_in_as(users(:admin))

    get admin_form_analysis_path(forms(:survey))

    assert_response :success
    assert_select "h1", text: "Team survey analysis"
    assert_select "dt", text: "Submissions"
    assert_select "dd", text: "2"
    assert_select "dt", text: "Collected over"
    assert_select "dd", text: "3 days"
    # Six of the ten possible answers were given, and one person answered everything.
    assert_select "dt", text: "Questions answered"
    assert_select "dd", text: "60%"
    assert_select "dd", text: "6 of 10 possible answers given"
    assert_select "dt", text: "Answered in full"
  end

  test "a choice question shows a count and a share for every option it offers" do
    submit(users(:member), full_name: "Ada", team: "Design")
    submit(users(:another_member), full_name: "Grace", team: "Design")
    submit(users(:other_admin), full_name: "Alan", team: "Support")
    sign_in_as(users(:admin))

    get admin_form_analysis_path(forms(:survey))

    assert_response :success
    assert_select "section[aria-labelledby=?]", "question-#{fields(:team).id}" do
      assert_select "h2", text: /Team/
      assert_select "li", text: /Design\s+2\s+people.*66\.7%/m
      assert_select "li", text: /Engineering\s+0\s+people.*0%/m
      assert_select "li", text: /Support\s+1\s+person.*33\.3%/m
    end
  end

  test "a check box question says its shares do not add up to the whole" do
    perks = fields(:perks)
    submit(users(:member), full_name: "Ada", perks: %w[Gym Transit])
    submit(users(:another_member), full_name: "Grace", perks: %w[Gym])
    sign_in_as(users(:admin))

    get admin_form_analysis_path(forms(:survey))

    assert_response :success
    assert_select "section[aria-labelledby=?]", "question-#{perks.id}" do
      assert_select "p", text: /3 options picked in total/
      assert_select "p", text: /can add up to more than 100%/
      # Both people used the gym; one of the two took transit.
      assert_select "li", text: /Gym\s+2\s+people.*100%/m
      assert_select "li", text: /Transit\s+1\s+person.*50%/m
    end
  end

  test "a number question shows the statistics its answers support" do
    submit(users(:member), full_name: "Ada", years_experience: "2")
    submit(users(:another_member), full_name: "Grace", years_experience: "8")
    sign_in_as(users(:admin))

    get admin_form_analysis_path(forms(:survey))

    assert_select "section[aria-labelledby=?]", "question-#{fields(:years_experience).id}" do
      assert_select "dt", text: "Smallest"
      assert_select "dd", text: "2"
      assert_select "dt", text: "Largest"
      assert_select "dd", text: "8"
      assert_select "dt", text: "Mean"
      assert_select "dd", text: "5"
    end
  end

  test "a handful of answers is presented as a listing rather than as a summary" do
    submit(users(:member), full_name: "Ada", years_experience: "2")
    submit(users(:another_member), full_name: "Grace", years_experience: "8")
    sign_in_as(users(:admin))

    get admin_form_analysis_path(forms(:survey))

    assert_select "section[aria-labelledby=?]", "question-#{fields(:years_experience).id}" do
      assert_select "p", text: /Only 2 answers so far/
      assert_select "p", text: /Every answer, in order:\s+2 and 8/m
    end
  end

  test "a date question shows its range and its shape over time" do
    submit(users(:member), full_name: "Ada", start_date: "2026-03-01")
    submit(users(:another_member), full_name: "Grace", start_date: "2026-03-03")
    sign_in_as(users(:admin))

    get admin_form_analysis_path(forms(:survey))

    assert_select "section[aria-labelledby=?]", "question-#{fields(:start_date).id}" do
      assert_select "dt", text: "Earliest"
      assert_select "dt", text: "Range"
      assert_select "dd", text: "2 days"
      assert_select "h3", text: "Answers by day"
      # The empty day between the two answers is kept, so a gap reads as a gap.
      assert_select "li", text: /March 0?2, 2026\s+0\s+answers/m
    end
  end

  test "a free text question offers a sample of the answers rather than a summary" do
    submit(users(:member), full_name: "Ada Lovelace")
    submit(users(:another_member), full_name: "Grace Hopper")
    sign_in_as(users(:admin))

    get admin_form_analysis_path(forms(:survey))

    assert_select "section[aria-labelledby=?]", "question-#{fields(:full_name).id}" do
      assert_select "p", text: /cannot be summarised into a number/
      assert_select "li", text: "Ada Lovelace"
      assert_select "li", text: "Grace Hopper"
    end
  end

  test "a question nobody answered says so instead of showing an empty chart" do
    submit(users(:member), full_name: "Ada")
    sign_in_as(users(:admin))

    get admin_form_analysis_path(forms(:survey))

    assert_select "section[aria-labelledby=?]", "question-#{fields(:team).id}" do
      assert_select "p", text: /Answered by\s+0\s+of 1 person\s+\(0%\), 1 left it blank\./m
      assert_select "p", text: /Nobody has answered this question/
      assert_select "li", count: 0
    end
  end

  test "a form with no submissions offers an empty state rather than zeroes" do
    sign_in_as(users(:admin))

    get admin_form_analysis_path(forms(:survey))

    assert_response :success
    assert_select "h2", text: "Nothing to analyse yet"
    assert_select "dl", count: 0
    assert_select "section", count: 0
  end

  test "a form with no fields says there is nothing to break down" do
    form = forms(:deleted_form)
    Submission.create!(form: form, user: users(:member), values: {})
    sign_in_as(users(:admin))

    get admin_form_analysis_path(form)

    assert_response :success
    assert_select "p", text: /no questions, so there is nothing to break down/
    assert_select "section", count: 0
  end

  test "a deleted form is still analysable and says that it is deleted" do
    form = forms(:deleted_form)
    Submission.create!(form: form, user: users(:member), values: {})
    sign_in_as(users(:admin))

    get admin_form_analysis_path(form)

    assert_response :success
    assert_select "span.badge-deleted", text: "Deleted"
  end

  test "the page links back to the form and on to the submissions behind the numbers" do
    submit(users(:member), full_name: "Ada")
    sign_in_as(users(:admin))

    get admin_form_analysis_path(forms(:survey))

    assert_select "a[href=?]", admin_form_path(forms(:survey)), text: "Back to form"
    assert_select "a[href=?]", admin_form_submissions_path(forms(:survey)), text: "Submissions"
  end

  test "every bar has its numbers in the text and is hidden from screen readers" do
    submit(users(:member), full_name: "Ada", team: "Design")
    sign_in_as(users(:admin))

    get admin_form_analysis_path(forms(:survey))

    assert_select "svg[aria-hidden=true] rect[width=?]", "100.0"
    assert_select "span.sr-only", text: "person"
  end

  private

    def submit(user, answers)
      values = answers.transform_keys { |name| fields(name).id.to_s }

      Submission.create!(form: forms(:survey), user: user, values: values)
    end
end
