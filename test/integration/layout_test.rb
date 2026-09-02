require "test_helper"

class LayoutTest < ActionDispatch::IntegrationTest
  test "the sign in page renders without a signed in user" do
    get new_user_session_path

    assert_response :success
    assert_select "nav", count: 0
  end
end
