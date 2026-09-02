class Submission < ApplicationRecord
  belongs_to :form, inverse_of: :submissions
  belongs_to :user, inverse_of: :submissions

  validates :user_id, uniqueness: { scope: :form_id, message: "has already filled out this form" }
  validates_with SubmissionValuesValidator

  before_save :cast_values

  def answered?(field)
    field.answered?(values[field.id.to_s])
  end

  def answer_for(field)
    field.cast(values[field.id.to_s])
  end

  def display_value_for(field)
    answer = answer_for(field)

    answer.is_a?(Array) ? answer.join(", ") : answer.to_s
  end

  private

    # Runs only once validation has passed, so every answer left here is known to cast
    # cleanly and blank answers can be dropped rather than stored as empty strings.
    def cast_values
      self.values = form.fields.each_with_object({}) do |field, answers|
        raw = values[field.id.to_s]
        answers[field.id.to_s] = field.cast(raw) if field.answered?(raw)
      end
    end
end
