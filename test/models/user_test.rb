require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "is not an admin by default" do
    user = User.create!(email: "new@example.com", password: "password123")

    assert_not user.admin?
  end

  test "owns the forms it created" do
    assert_includes users(:admin).forms, forms(:survey)
    assert_not_includes users(:admin).forms, forms(:other_admins_form)
  end

  test "knows which forms it has already filled out" do
    assert users(:member).submitted?(forms(:locked_form))
    assert_not users(:member).submitted?(forms(:survey))
  end
end
