require "test_helper"

class Admin::EpisodesControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login for index when unauthenticated" do
    get admin_episodes_url
    assert_redirected_to admin_login_url
  end

  test "redirects to login for new when unauthenticated" do
    get new_admin_episode_url
    assert_redirected_to admin_login_url
  end

  test "redirects to login for edit when unauthenticated" do
    episode = episodes(:one)
    get edit_admin_episode_url(episode)
    assert_redirected_to admin_login_url
  end
end
