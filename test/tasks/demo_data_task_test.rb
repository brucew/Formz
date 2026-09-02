require "test_helper"
require "rake"

# The task's classes live in the rake file, which nothing autoloads.
load Rails.root.join("lib/tasks/demo_data.rake") unless defined?(DemoDataGenerator)

class DemoDataTaskTest < ActiveSupport::TestCase
  test "generates a form of typed fields answered by a hundred disposable users" do
    form = generate

    assert_equal 100, form.submissions.count
    assert_equal 100, form.submissions.map(&:user_id).uniq.size
    assert_equal 100, demo_users.count
    assert form.owner.admin?
    assert_equal %w[text_field select radio_button check_box number_field
                    number_field number_field date_field date_field text_area],
                 form.fields.map(&:input_type)
  end

  test "answers vary rather than repeating one value" do
    form = generate
    satisfaction = form.fields.find_by(label: "Satisfaction with our tooling")

    scores = form.submissions.map { |submission| submission.answer_for(satisfaction) }

    assert_operator scores.uniq.size, :>, 4
  end

  test "an optional question is left unanswered by some people" do
    form = generate
    optional = form.fields.find_by(label: "Anything else we should know?")

    unanswered = form.submissions.count { |submission| submission.answer_for(optional).blank? }

    assert_operator unanswered, :>, 0
    assert_operator unanswered, :<, 100
  end

  test "running twice replaces the previous run instead of duplicating it" do
    generate
    form = generate

    assert_equal 1, Form.where(name: form.name).count
    assert_equal 100, form.submissions.count
    assert_equal 100, demo_users.count
  end

  test "the same seed reproduces the same answers and a different seed does not" do
    repeated = answers_from(generate(seed: 7))
    again = answers_from(generate(seed: 7))
    different = answers_from(generate(seed: 8))

    assert_equal repeated, again
    assert_not_equal repeated, different
  end

  test "leaves forms and users it did not create alone" do
    existing_form = forms(:survey)
    existing_user = users(:member)

    generate

    assert Form.exists?(existing_form.id)
    assert User.exists?(existing_user.id)
  end

  private

    def generate(seed: 1234)
      DemoDataGenerator.new(seed: seed, output: StringIO.new).generate
    end

    def demo_users
      User.where("email LIKE :pattern", pattern: "demo-%@formz.demo")
    end

    # Compared by field order rather than by field id, because a fresh run rebuilds the
    # form and its fields get new ids.
    def answers_from(form)
      field_ids = form.fields.map { |field| field.id.to_s }

      form.submissions.order(:created_at).map do |submission|
        field_ids.map { |field_id| submission.values[field_id] }
      end
    end
end
