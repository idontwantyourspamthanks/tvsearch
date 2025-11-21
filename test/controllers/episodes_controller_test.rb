require "test_helper"

class EpisodesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should get show" do
    get episode_url(episodes(:one))
    assert_response :success
  end
end
