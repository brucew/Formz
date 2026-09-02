class Field < ApplicationRecord
  # The keys are Rails form builder method names so a field can render itself with
  # form.public_send(field.input_type, ...). The prefixes keep the generated predicates
  # from colliding with Active Record's own select, string and date methods.
  enum :input_type, {
    text_field: 0,
    text_area: 1,
    number_field: 2,
    date_field: 3,
    email_field: 4,
    telephone_field: 5,
    url_field: 6,
    select: 7,
    radio_button: 8,
    check_box: 9
  }, prefix: :input, scopes: false, validate: true

  enum :value_type, {
    string: 0,
    number: 1,
    date: 2
  }, prefix: :value, scopes: false, validate: true

  belongs_to :form, inverse_of: :fields

  validates :label, presence: true
  validates_with FieldChoicesValidator
  validates_with FieldTypeCompatibilityValidator

  def choice_based?
    input_select? || input_radio_button? || input_check_box?
  end

  def multiple_choice?
    input_check_box?
  end

  def choices_text
    choices.join("\n")
  end

  def choices_text=(text)
    self.choices = text.to_s.split("\n").map(&:strip).reject(&:blank?)
  end

  def answered?(raw)
    raw.is_a?(Array) ? raw.any?(&:present?) : raw.present?
  end

  # Returns nil when the answer cannot be represented as this field's value type.
  # SubmissionValuesValidator turns that nil into a message for the person filling
  # the form in, so it is never swallowed silently.
  def cast(raw)
    return Array(raw).map(&:to_s).reject(&:blank?) if multiple_choice?

    case value_type
    when "number" then cast_number(raw)
    when "date"   then cast_date(raw)
    else raw.to_s.strip.presence
    end
  end

  # The summary of these submissions' answers to this field. The submissions are handed
  # in already loaded, so summarising a whole form costs one query rather than one per
  # field.
  def summary_of(submissions)
    summary_class.new(self, submissions)
  end

  def valid_choice?(answer)
    return true unless choice_based?

    Array(answer).all? { |value| choices.include?(value.to_s) }
  end

  private

    def summary_class
      return FieldSummary::Choices if choice_based?

      case value_type
      when "number" then FieldSummary::Numbers
      when "date"   then FieldSummary::Dates
      else FieldSummary::Texts
      end
    end

    def cast_number(raw)
      BigDecimal(raw.to_s.strip)
    rescue ArgumentError, TypeError
      nil
    end

    def cast_date(raw)
      Date.iso8601(raw.to_s.strip)
    rescue Date::Error, TypeError
      nil
    end
end
