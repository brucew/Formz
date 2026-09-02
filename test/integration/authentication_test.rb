require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "sign in page offers an email and a password field" do
    get new_user_session_path

    assert_response :success
    assert_select "form[action=?]", user_session_path do
      assert_select "input[type=email][name=?]", "user[email]"
      assert_select "input[type=password][name=?]", "user[password]"
    end
  end

  test "signing in with the correct password lands the user in the app" do
    member = users(:member)

    post user_session_path, params: { user: { email: member.email, password: "password123" } }

    assert_redirected_to root_path
    assert_equal member.id, signed_in_user_id

    get edit_user_registration_path

    assert_response :success
  end

  test "signing in with the wrong password re-renders the form without signing the user in" do
    member = users(:member)

    post user_session_path, params: { user: { email: member.email, password: "not-the-password" } }

    assert_response :unprocessable_content
    assert_select "form[action=?]", user_session_path
    assert_select "[role=alert]", text: /Invalid email or password/
    assert_nil signed_in_user_id

    get edit_user_registration_path

    assert_redirected_to new_user_session_path
  end

  test "signing out leaves signed-in pages unreachable" do
    sign_in_as users(:member)
    get edit_user_registration_path

    assert_response :success

    delete destroy_user_session_path

    assert_redirected_to root_path
    assert_nil signed_in_user_id

    get edit_user_registration_path

    assert_redirected_to new_user_session_path
  end

  test "sign up page offers email, password and confirmation fields" do
    get new_user_registration_path

    assert_response :success
    assert_select "form[action=?]", user_registration_path do
      assert_select "input[type=email][name=?]", "user[email]"
      assert_select "input[type=password][name=?]", "user[password]"
      assert_select "input[type=password][name=?]", "user[password_confirmation]"
      assert_select "input[name=?]", "user[admin]", count: 0
    end
  end

  test "signing up creates a user who is not an admin" do
    assert_difference -> { User.count }, 1 do
      post user_registration_path, params: {
        user: { email: "newcomer@example.com", password: "password123", password_confirmation: "password123" }
      }
    end

    assert_redirected_to root_path
    assert_equal false, User.find_by(email: "newcomer@example.com").admin?
  end

  test "signing up with an admin flag in the payload still creates a member" do
    post user_registration_path, params: {
      user: {
        email: "sneaky@example.com", password: "password123",
        password_confirmation: "password123", admin: true
      }
    }

    assert_redirected_to root_path
    assert_equal false, User.find_by(email: "sneaky@example.com").admin?
  end

  test "password reset page renders and accepts an email address" do
    get new_user_password_path

    assert_response :success
    assert_select "form[action=?]", user_password_path do
      assert_select "input[type=email][name=?]", "user[email]"
    end

    assert_emails 1 do
      post user_password_path, params: { user: { email: users(:member).email } }
    end

    assert_redirected_to new_user_session_path
  end

  test "the password reset link renders a form carrying the reset token" do
    get edit_user_password_path(reset_password_token: "a-reset-token")

    assert_response :success
    assert_select "input[type=hidden][name=?][value=?]", "user[reset_password_token]", "a-reset-token"
    assert_select "input[type=password][name=?]", "user[password]"
  end

  private
    # Warden stores the signed-in user as [[id], password_salt].
    def signed_in_user_id
      session["warden.user.user.key"]&.dig(0, 0)
    end
end
