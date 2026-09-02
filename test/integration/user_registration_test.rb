require "test_helper"

class UserRegistrationTest < ActionDispatch::IntegrationTest
  test "signing up does not let a user make themselves an admin" do
    post user_registration_path, params: {
      user: { email: "sneaky@example.com", password: "password123",
              password_confirmation: "password123", admin: true }
    }

    user = User.find_by(email: "sneaky@example.com")

    assert_not_nil user
    assert_not user.admin?
  end
end
