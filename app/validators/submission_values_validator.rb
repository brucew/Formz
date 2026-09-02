class SubmissionValuesValidator < ActiveModel::Validator
  def validate(record)
    return if record.form.blank?

    reject_unknown_answers(record)
    record.form.fields.each { |field| validate_answer(record, field) }
  end

  private

    def reject_unknown_answers(record)
      unknown = record.values.keys.map(&:to_s) - record.form.fields.ids.map(&:to_s)
      return if unknown.empty?

      record.errors.add(:base, "Some answers are for fields that are not on this form")
    end

    def validate_answer(record, field)
      raw = record.values[field.id.to_s]

      unless field.answered?(raw)
        add_answer_error(record, field, "is required") if field.required?
        return
      end

      answer = field.cast(raw)

      if answer.nil?
        add_answer_error(record, field, "must be a valid #{field.value_type}")
      elsif !field.valid_choice?(answer)
        add_answer_error(record, field, "has an answer that is not one of its choices")
      end
    end

    # Errors go on :base so the summary reads as a sentence rather than being prefixed
    # with the values attribute, and carry the field they came from so the fill out form
    # can put each message under the input that caused it without matching on label text.
    def add_answer_error(record, field, message)
      record.errors.add(:base, "#{field.label} #{message}", field_id: field.id)
    end
end
