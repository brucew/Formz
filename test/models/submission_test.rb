require "test_helper"

class SubmissionTest < ActiveSupport::TestCase
  test "a user can only fill out a form once" do
    duplicate = Submission.new(form: forms(:locked_form), user: users(:member), values: {})

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already filled out this form"
  end

  test "the database refuses a duplicate even when validation is skipped" do
    assert_raises ActiveRecord::RecordNotUnique do
      Submission.insert!({
        form_id: forms(:locked_form).id,
        user_id: users(:member).id,
        values: {},
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "a required field must be answered" do
    submission = build_survey_submission(values: {})

    assert_not submission.valid?
    assert_includes submission.errors[:base], "Full name is required"
  end

  test "a required multiple choice field is not answered by an empty array" do
    fields(:perks).update!(required: true)
    submission = build_survey_submission(answers(perks: [ "" ]))

    assert_not submission.valid?
    assert_includes submission.errors[:base], "Perks used is required"
  end

  test "an answer that will not cast is rejected" do
    submission = build_survey_submission(answers(years_experience: "seven"))

    assert_not submission.valid?
    assert_includes submission.errors[:base], "Years of experience must be a valid number"
  end

  test "answer errors carry the field they came from" do
    submission = build_survey_submission(answers(years_experience: "seven"))
    submission.validate

    error = submission.errors.where(:base).find { |candidate| candidate.options[:field_id] == fields(:years_experience).id }

    assert_equal "Years of experience must be a valid number", error.message
  end

  test "an answer outside a field's choices is rejected" do
    submission = build_survey_submission(answers(team: "Marketing"))

    assert_not submission.valid?
    assert_includes submission.errors[:base], "Team has an answer that is not one of its choices"
  end

  test "answers for fields that are not on the form are rejected" do
    submission = build_survey_submission(answers.merge("0" => "stray"))

    assert_not submission.valid?
    assert_includes submission.errors[:base], "Some answers are for fields that are not on this form"
  end

  test "stores answers cast to their value type" do
    submission = build_survey_submission(
      answers(years_experience: "7.5", start_date: "2026-03-01", perks: [ "Gym" ])
    )

    assert submission.save
    submission.reload

    assert_equal BigDecimal("7.5"), submission.answer_for(fields(:years_experience))
    assert_equal Date.new(2026, 3, 1), submission.answer_for(fields(:start_date))
    assert_equal [ "Gym" ], submission.answer_for(fields(:perks))
  end

  test "drops blank answers rather than storing empty strings" do
    submission = build_survey_submission(answers(years_experience: ""))

    assert submission.save
    assert_not submission.reload.values.key?(fields(:years_experience).id.to_s)
  end

  test "displays a multiple choice answer as a joined list" do
    submission = build_survey_submission(answers(perks: %w[Gym Transit]))
    submission.save!

    assert_equal "Gym, Transit", submission.display_value_for(fields(:perks))
  end

  private

    def build_survey_submission(values)
      Submission.new(form: forms(:survey), user: users(:another_member), values: values)
    end

    def answers(overrides = {})
      defaults = { full_name: "Ada Lovelace" }

      defaults.merge(overrides).transform_keys { |name| fields(name).id.to_s }
    end
end
