require "test_helper"

class FieldTest < ActiveSupport::TestCase
  test "is not required by default" do
    assert_not Field.new.required?
  end

  test "requires a label" do
    field = fields(:full_name)
    field.label = ""

    assert_not field.valid?
    assert_includes field.errors[:label], "can't be blank"
  end

  test "enum prefixes leave Active Record query methods alone" do
    assert_respond_to Field, :select
    assert fields(:team).input_select?
    assert fields(:team).value_string?
  end

  test "choice based inputs must list choices" do
    field = fields(:team)
    field.choices = []

    assert_not field.valid?
    assert_includes field.errors[:choices], "must list at least one option for this input type"
  end

  test "non choice inputs may not list choices" do
    field = fields(:full_name)
    field.choices = %w[Yes No]

    assert_not field.valid?
    assert_includes field.errors[:choices], "are only used by select, radio button and check box fields"
  end

  test "a number field must hold a number value type" do
    field = fields(:years_experience)
    field.value_type = :string

    assert_not field.valid?
    assert_includes field.errors[:value_type], "must be number for a number field"
  end

  test "a date field must hold a date value type" do
    field = fields(:start_date)
    field.value_type = :string

    assert_not field.valid?
    assert_includes field.errors[:value_type], "must be date for a date field"
  end

  test "casts a string answer" do
    assert_equal "Ada", fields(:full_name).cast("  Ada  ")
  end

  test "casts a number answer" do
    assert_equal BigDecimal("7.5"), fields(:years_experience).cast("7.5")
  end

  test "returns nil for a number answer that is not a number" do
    assert_nil fields(:years_experience).cast("seven")
  end

  test "casts a date answer" do
    assert_equal Date.new(2026, 3, 1), fields(:start_date).cast("2026-03-01")
  end

  test "returns nil for a date answer that is not a date" do
    assert_nil fields(:start_date).cast("March the first")
  end

  test "casts a multiple choice answer to an array without blanks" do
    assert_equal %w[Gym Transit], fields(:perks).cast([ "", "Gym", "Transit" ])
  end

  test "recognises answers that are present" do
    assert fields(:full_name).answered?("Ada")
    assert_not fields(:full_name).answered?("")
    assert fields(:perks).answered?([ "Gym" ])
    assert_not fields(:perks).answered?([ "" ])
  end

  test "accepts only its own choices" do
    assert fields(:team).valid_choice?("Design")
    assert_not fields(:team).valid_choice?("Marketing")
    assert fields(:perks).valid_choice?(%w[Gym Transit])
    assert_not fields(:perks).valid_choice?(%w[Gym Sauna])
  end

  test "reads and writes choices as one per line" do
    field = fields(:team)
    field.choices_text = "Design\n  Engineering  \n\nSupport\n"

    assert_equal %w[Design Engineering Support], field.choices
    assert_equal "Design\nEngineering\nSupport", field.choices_text
  end
end
