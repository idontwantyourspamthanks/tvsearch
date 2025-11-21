require "test_helper"

class Admin::PasswordsControllerTest < ActionDispatch::IntegrationTest
  def login_as_fixture_admin
    post admin_login_url, params: { email: admin_users(:one).email, password: "password" }
    follow_redirect!
  end

  test "redirects to login when unauthenticated" do
    get edit_admin_password_url
    assert_redirected_to admin_login_url
  end

  test "updates password with valid current password" do
    login_as_fixture_admin

    patch admin_password_url, params: {
      current_password: "password",
      password: "newpass123",
      password_confirmation: "newpass123"
    }

    assert_redirected_to admin_root_url
  end

  test "rejects update with wrong current password" do
    login_as_fixture_admin

    patch admin_password_url, params: {
      current_password: "wrong",
      password: "newpass123",
      password_confirmation: "newpass123"
    }

    assert_response :unprocessable_entity
  end
end
