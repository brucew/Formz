class FieldChoicesValidator < ActiveModel::Validator
  def validate(record)
    if record.choice_based?
      record.errors.add(:choices, "must list at least one option for this input type") if record.choices.blank?
    elsif record.choices.present?
      record.errors.add(:choices, "are only used by select, radio button and check box fields")
    end
  end
end
