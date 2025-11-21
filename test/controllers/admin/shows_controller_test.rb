require "test_helper"

class Admin::ShowsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login for index when unauthenticated" do
    get admin_shows_url
    assert_redirected_to admin_login_url
  end

  test "redirects to login for new when unauthenticated" do
    get new_admin_show_url
    assert_redirected_to admin_login_url
  end
end
