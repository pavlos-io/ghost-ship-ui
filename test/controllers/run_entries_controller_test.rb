require "test_helper"

class RunEntriesControllerTest < ActionDispatch::IntegrationTest
  test "POST create with valid params returns 201" do
    run = runs(:one)

    assert_difference("RunEntry.count", 1) do
      post run_run_entries_url(run), params: { run_entry: { data: { type: "assistant", message: "hello" } } }, as: :json
    end
    assert_response :created
  end

  test "POST create with empty data returns 422" do
    run = runs(:one)

    assert_no_difference("RunEntry.count") do
      post run_run_entries_url(run), params: { run_entry: { data: {} } }, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "POST create with nonexistent run returns 404" do
    post run_run_entries_url(0), params: { run_entry: { data: { type: "system" } } }, as: :json
    assert_response :not_found
  end
end
