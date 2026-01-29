require "test_helper"

class DubbingItemsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get dubbing_items_create_url
    assert_response :success
  end

  test "should get update" do
    get dubbing_items_update_url
    assert_response :success
  end

  test "should get destroy" do
    get dubbing_items_destroy_url
    assert_response :success
  end

  test "should get upload_image" do
    get dubbing_items_upload_image_url
    assert_response :success
  end
end
