class FieldTypeCompatibilityValidator < ActiveModel::Validator
  def validate(record)
    return if record.input_type.blank? || record.value_type.blank?

    expected = expected_value_type(record.input_type)
    return if record.value_type == expected

    record.errors.add(:value_type, "must be #{expected} for a #{record.input_type.humanize.downcase}")
  end

  private

    def expected_value_type(input_type)
      case input_type
      when "number_field" then "number"
      when "date_field"   then "date"
      else "string"
      end
    end
end
