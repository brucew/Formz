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

      record.errors.add(:values, "includes answers for fields that are not on this form")
    end

    def validate_answer(record, field)
      raw = record.values[field.id.to_s]

      unless field.answered?(raw)
        record.errors.add(:values, "#{field.label} is required") if field.required?
        return
      end

      answer = field.cast(raw)

      if answer.nil?
        record.errors.add(:values, "#{field.label} must be a valid #{field.value_type}")
      elsif !field.valid_choice?(answer)
        record.errors.add(:values, "#{field.label} has an answer that is not one of its choices")
      end
    end
end
