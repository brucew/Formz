require "test_helper"

class FormAnalysisTest < ActiveSupport::TestCase
  include ActiveRecord::Assertions::QueryAssertions

  test "a form with no submissions has nothing to report" do
    analysis = forms(:survey).analysis

    assert_not analysis.any_submissions?
    assert_equal 0, analysis.submission_count
    assert_nil analysis.first_submitted_at
    assert_nil analysis.days_covered
    assert_nil analysis.answer_rate
    assert_equal 0, analysis.complete_submission_count
  end

  test "a form with no fields still counts its submissions" do
    form = forms(:deleted_form)
    Submission.create!(form: form, user: users(:member), values: {})

    analysis = form.analysis

    assert analysis.any_submissions?
    assert_equal 0, analysis.field_count
    assert_equal [], analysis.field_summaries
    assert_equal 0, analysis.possible_answers
    assert_nil analysis.answer_rate
    assert_nil analysis.complete_submission_count
  end

  test "the period covered is counted inclusively from the first submission to the last" do
    travel_to Time.zone.local(2026, 3, 1, 9, 0) do
      submit(users(:member), full_name: "Ada")
    end
    travel_to Time.zone.local(2026, 3, 4, 9, 0) do
      submit(users(:another_member), full_name: "Grace")
    end

    analysis = forms(:survey).analysis

    assert_equal 2, analysis.submission_count
    assert_equal Time.zone.local(2026, 3, 1, 9, 0), analysis.first_submitted_at
    assert_equal Time.zone.local(2026, 3, 4, 9, 0), analysis.last_submitted_at
    assert_equal 4, analysis.days_covered
  end

  test "one submission covers a single day rather than none" do
    submit(users(:member), full_name: "Ada")

    assert_equal 1, forms(:survey).analysis.days_covered
  end

  test "the answer rate is the share of every question that was answered" do
    submit(users(:member), full_name: "Ada", years_experience: "4")
    submit(users(:another_member), full_name: "Grace")

    analysis = forms(:survey).analysis

    assert_equal 5, analysis.field_count
    assert_equal 10, analysis.possible_answers
    assert_equal 3, analysis.given_answers
    assert_in_delta 0.3, analysis.answer_rate
  end

  test "a submission counts as complete only when no question was left blank" do
    submit(users(:member), full_name: "Ada", years_experience: "4",
                           start_date: "2026-03-01", team: "Design", perks: %w[Gym])
    submit(users(:another_member), full_name: "Grace")

    analysis = forms(:survey).analysis

    assert_equal 1, analysis.complete_submission_count
  end

  test "the field summaries follow the order the questions are asked in" do
    submit(users(:member), full_name: "Ada")

    analysis = forms(:survey).analysis

    assert_equal [ "Full name", "Years of experience", "Start date", "Team", "Perks used" ],
                 analysis.field_summaries.map { |summary| summary.field.label }
    assert_equal %i[texts numbers dates choices choices],
                 analysis.field_summaries.map(&:kind)
  end

  test "summarising every field costs one query for the fields and one for the submissions" do
    submit(users(:member), full_name: "Ada")
    submit(users(:another_member), full_name: "Grace")

    analysis = Form.find(forms(:survey).id).analysis

    assert_queries_count(2) do
      analysis.field_summaries.each(&:answered_count)
      analysis.complete_submission_count
      analysis.answer_rate
    end
  end

  private

    def submit(user, answers)
      values = answers.transform_keys { |name| fields(name).id.to_s }

      Submission.create!(form: forms(:survey), user: user, values: values)
    end
end
