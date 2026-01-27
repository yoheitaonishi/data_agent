require "test_helper"

class AgenticJobsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    agentic_job = AgenticJob.create!(
      source_system: "Test System",
      destination_system: "Test Destination",
      status: "success",
      executed_at: Time.current
    )
    get agentic_job_url(agentic_job)
    assert_response :success
  end
end
