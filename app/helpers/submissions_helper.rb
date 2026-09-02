module SubmissionsHelper
  # A required field is marked three ways: this glyph, the required attribute on the
  # input, and aria-required on choice groups where the attribute cannot carry across
  # a set. The glyph is hidden from screen readers, which get the word instead.
  def required_answer_marker
    safe_join([
      tag.span("*", class: "ml-0.5 font-semibold text-red-600", aria: { hidden: true }),
      tag.span("required", class: "sr-only")
    ])
  end

  def answer_label(field)
    return field.label unless field.required?

    safe_join([ field.label, required_answer_marker ])
  end

  # SubmissionValuesValidator attaches every message to :values, prefixed with the
  # field's label. Matching that prefix is what lets the fill out form put a message
  # under the input that caused it as well as in the summary at the top.
  def answer_errors_for(submission, field)
    submission.errors.where(:values).map(&:message).select do |message|
      message.start_with?("#{field.label} ")
    end
  end
end
