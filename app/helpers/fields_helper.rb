module FieldsHelper
  # Select options for the field editor, so the views never reach into the enums
  # themselves.
  def field_input_type_options
    Field.input_types.keys.map { |input_type| [ field_input_type_label(input_type), input_type ] }
  end

  def field_value_type_options
    Field.value_types.keys.map { |value_type| [ value_type.humanize, value_type ] }
  end

  def field_input_type_label(input_type)
    input_type == "url_field" ? "URL field" : input_type.humanize
  end

  # Asks each input type whether it takes choices rather than repeating the list, so
  # the field editor's JavaScript stays in step with the model.
  def choice_based_input_types
    Field.input_types.keys.select { |input_type| Field.new(input_type: input_type).choice_based? }
  end

  # The blank field the "add field" template is rendered from. It is never saved.
  def template_field
    Field.new(input_type: :text_field, value_type: :string)
  end
end
