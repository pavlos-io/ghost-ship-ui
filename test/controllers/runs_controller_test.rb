require "test_helper"

class RunsControllerTest < ActionDispatch::IntegrationTest
  test "GET index returns 200" do
    get runs_url
    assert_response :success
  end

  test "GET root returns 200" do
    get root_url
    assert_response :success
  end

  test "GET show returns 200" do
    run = runs(:one)
    get run_url(run)
    assert_response :success
  end

  test "POST create with valid params returns 201" do
    assert_difference("Run.count", 1) do
      post runs_url, params: { run: { creator: "test_user", source: "api" } }, as: :json
    end
    assert_response :created
  end

  test "POST create with blank params returns 422" do
    assert_no_difference("Run.count") do
      post runs_url, params: { run: { creator: "", source: "" } }, as: :json
    end
    assert_response :unprocessable_entity
  end
end
