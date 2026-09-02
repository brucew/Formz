require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Warden::Test::Helpers

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # The default two seconds is not enough for the first request in a worker, which pays
  # for eager loading on top of the round trip.
  Capybara.default_max_wait_time = 5

  setup { Warden.test_mode! }
  teardown { Warden.test_reset! }

  private

    # Signing in through the form is covered by AuthenticationTest. Here it is only setup,
    # so it goes through Warden instead: typing into the sign in form intermittently lost
    # the password field's value, and the field's required attribute then blocked the
    # submit, leaving the test on the sign in page with no error to explain it.
    def sign_in_as(user)
      login_as(user, scope: :user)
    end

    def answer_field_name(field)
      "submission[values][#{field.id}]"
    end
end
