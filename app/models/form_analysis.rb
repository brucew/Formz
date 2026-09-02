# What a form's submissions add up to: how many came in, over what period, how completely
# they were answered, and a summary of every field's answers.
#
# Two queries -- the form's fields and its submissions -- and everything else is counted
# in Ruby, so the cost of the page does not grow with the number of fields.
class FormAnalysis
  attr_reader :form

  def initialize(form)
    @form = form
  end

  def submissions
    @submissions ||= form.submissions.order(:created_at).to_a
  end

  def fields
    @fields ||= form.fields.to_a
  end

  def field_summaries
    @field_summaries ||= fields.map { |field| field.summary_of(submissions) }
  end

  def submission_count
    submissions.size
  end

  def field_count
    fields.size
  end

  def any_submissions?
    submissions.any?
  end

  def first_submitted_at
    submissions.first&.created_at
  end

  def last_submitted_at
    submissions.last&.created_at
  end

  # Counted inclusively, so a form answered entirely on one day covers one day rather
  # than none.
  def days_covered
    return unless any_submissions?

    (last_submitted_at.to_date - first_submitted_at.to_date).to_i + 1
  end

  def given_answers
    @given_answers ||= field_summaries.sum(&:answered_count)
  end

  def possible_answers
    submission_count * field_count
  end

  def answer_rate
    return if possible_answers.zero?

    given_answers.fdiv(possible_answers)
  end

  # People who left nothing blank. Optional fields count, so this is a stricter number
  # than "everyone answered what they had to".
  def complete_submission_count
    return if fields.empty?

    @complete_submission_count ||= submissions.count do |submission|
      fields.all? { |field| submission.answered?(field) }
    end
  end
end
