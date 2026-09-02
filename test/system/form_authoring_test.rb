require "application_system_test_case"

# Covers the part of the editor that only exists in JavaScript: rows are cloned from a
# template, and the choices box appears only for input types that take choices.
class FormAuthoringTest < ApplicationSystemTestCase
  test "an admin builds a form by adding field rows" do
    sign_in_as users(:admin)
    visit new_admin_form_path

    fill_in "Name", with: "Kit request"

    add_field(question: "Your name", input_type: "Text field", stores: "String")
    add_field(question: "Desk height", input_type: "Number field", stores: "Number")
    add_field(question: "Keyboard", input_type: "Select", stores: "String", choices: "Compact\nFull size")

    click_on "Create form"

    assert_text "Kit request is ready to fill out."
    assert_text "Your name"
    assert_text "Desk height"
    assert_text "Keyboard"

    form = Form.find_by(name: "Kit request")

    assert_equal [ 1, 2, 3 ], form.fields.map(&:position)
    assert_equal %w[Compact Full\ size], form.fields.last.choices
  end

  test "the choices box appears only for input types that take choices" do
    sign_in_as users(:admin)
    visit new_admin_form_path

    click_on "Add field"

    within all("[data-nested-fields-target='row']").last do
      assert_no_selector "label", text: "Choices", visible: true

      select "Radio button", from: "Input type"

      assert_selector "label", text: "Choices", visible: true
    end
  end

  test "removing an unsaved row takes it off the page" do
    sign_in_as users(:admin)
    visit new_admin_form_path

    click_on "Add field"
    click_on "Add field"

    assert_selector "[data-nested-fields-target='row']", count: 2

    within(all("[data-nested-fields-target='row']").last) { click_on "Remove field" }

    assert_selector "[data-nested-fields-target='row']", count: 1
  end

  private

    def add_field(question:, input_type:, stores:, choices: nil)
      click_on "Add field"

      within all("[data-nested-fields-target='row']").last do
        fill_in "Question", with: question
        select input_type, from: "Input type"
        select stores, from: "Stores"
        fill_in "Choices", with: choices if choices
      end
    end
end
