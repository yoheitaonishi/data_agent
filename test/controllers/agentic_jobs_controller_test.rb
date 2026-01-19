require "test_helper"

class AgenticJobsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get agentic_jobs_show_url
    assert_response :success
  end
end
