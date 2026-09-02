require "test_helper"

class FormTest < ActiveSupport::TestCase
  test "requires a name and an owner" do
    form = Form.new

    assert_not form.valid?
    assert_includes form.errors[:name], "can't be blank"
    assert_includes form.errors[:owner], "must exist"
  end

  test "is active by default" do
    assert Form.new.active?
  end

  test "the active scope leaves out deleted forms" do
    assert_includes Form.active, forms(:survey)
    assert_not_includes Form.active, forms(:deleted_form)
  end

  test "knows which admin owns it" do
    assert forms(:survey).owned_by?(users(:admin))
    assert_not forms(:survey).owned_by?(users(:other_admin))
    assert_not forms(:survey).owned_by?(users(:member))
  end

  test "is locked once it has a submission" do
    assert forms(:locked_form).locked?
    assert_not forms(:survey).locked?
  end

  test "a locked form rejects a changed field" do
    form = forms(:locked_form)
    form.assign_attributes(fields_attributes: [ { id: fields(:locked_note).id, label: "Renamed" } ])

    assert_not form.valid?
    assert_includes form.errors[:base], "Fields cannot be changed once the form has submissions"
  end

  test "a locked form rejects a new field" do
    form = forms(:locked_form)
    form.assign_attributes(
      fields_attributes: [ { label: "Extra", input_type: "text_field", value_type: "string" } ]
    )

    assert_not form.valid?
    assert_includes form.errors[:base], "Fields cannot be changed once the form has submissions"
  end

  test "a locked form still accepts a new name" do
    assert forms(:locked_form).update(name: "Renamed but still locked")
  end

  test "soft delete marks the form inactive without destroying it" do
    form = forms(:survey)

    assert form.soft_delete
    assert form.reload.deleted?
    assert Form.exists?(form.id)
  end

  test "a deleted form rejects every other edit" do
    form = forms(:deleted_form)

    assert_not form.update(name: "Renamed")
    assert_includes form.errors[:base], "A deleted form cannot be edited"
  end

  test "a deleted form can still be restored" do
    form = forms(:deleted_form)

    assert form.restore
    assert form.reload.active?
  end

  test "field positions are renumbered from the order they arrive in" do
    form = Form.create!(
      owner: users(:admin),
      name: "Ordered",
      fields_attributes: [
        { label: "First", input_type: "text_field", value_type: "string" },
        { label: "Second", input_type: "text_field", value_type: "string" }
      ]
    )

    assert_equal [ 1, 2 ], form.fields.map(&:position)
    assert_equal %w[First Second], form.fields.map(&:label)
  end

  test "destroying a form takes its fields and submissions with it" do
    form = forms(:locked_form)

    assert_difference [ "Field.count", "Submission.count" ], -1 do
      form.destroy
    end
  end

  test "exports its submissions as csv" do
    rows = CSV.parse(forms(:locked_form).submissions_csv)

    assert_equal [ "Submitted by", "Submitted at", "Note" ], rows.first
    assert_equal [ "member@example.com", "Already answered" ], rows.second.values_at(0, 2)
  end
end
