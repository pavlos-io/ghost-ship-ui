require "test_helper"

class RunEntriesHelperTest < ActionView::TestCase
  include RunEntriesHelper

  def sample_session
    {
      source: "claude",
      session_id: "sess_123",
      model: "claude-sonnet-4-5-20250929",
      status: "completed",
      turns: [sample_turn],
      errors: [],
      started_at: "2026-01-01T00:00:00.000Z",
      ended_at: "2026-01-01T00:01:00.000Z"
    }
  end

  def sample_turn
    {
      turn_index: 0,
      message_id: "msg_1",
      status: "completed",
      thinking_text: "",
      message_text: "Hello world!",
      tools: [],
      stop_reason: "end_turn",
      usage: { "input_tokens" => 150, "output_tokens" => 42 },
      errors: [],
      started_at: "2026-01-01T00:00:00.000Z",
      ended_at: "2026-01-01T00:01:00.000Z"
    }
  end

  test "render_session_header shows model and session_id pills" do
    html = render_session_header(sample_session)
    assert_includes html, "claude-sonnet-4-5-20250929"
    assert_includes html, "sess_123"
    assert_includes html, "claude"
    assert_includes html, "rounded-full"
  end

  test "render_session_header with nil model/session_id" do
    session = sample_session.merge(model: nil, session_id: nil, source: nil)
    html = render_session_header(session)
    assert_not_includes html, "rounded-full"
  end

  test "render_turn shows message text in green card" do
    html = render_turn(sample_turn)
    assert_includes html, "Hello world!"
    assert_includes html, "bg-green-50"
    assert_includes html, "Claude"
  end

  test "render_turn shows thinking as collapsible purple section" do
    turn = sample_turn.merge(thinking_text: "Let me think about this...")
    html = render_turn(turn)
    assert_includes html, "Let me think about this..."
    assert_includes html, "bg-purple-50"
    assert_includes html, "<details"
    assert_includes html, "Thinking"
  end

  test "render_turn shows tool as collapsible card" do
    tool = {
      tool_use_id: "tu_1",
      tool: "read",
      input: { "file_path" => "app/models/user.rb" },
      status: "completed",
      started_at: "2026-01-01T00:00:01.000Z",
      ended_at: "2026-01-01T00:00:02.000Z"
    }
    turn = sample_turn.merge(tools: [tool])
    html = render_turn(turn)
    assert_includes html, "<details"
    assert_includes html, "read"
    assert_includes html, "app/models/user.rb"
  end

  test "render_turn shows turn stats" do
    html = render_turn(sample_turn)
    assert_includes html, "150"
    assert_includes html, "42"
    assert_includes html, "end_turn"
  end

  test "render_turn marks failed turn with red border" do
    turn = sample_turn.merge(status: "failed")
    html = render_turn(turn)
    assert_includes html, "border-red-400"
  end

  test "render_turn marks interrupted turn with yellow border" do
    turn = sample_turn.merge(status: "interrupted")
    html = render_turn(turn)
    assert_includes html, "border-yellow-400"
  end

  test "render_turn shows errors" do
    turn = sample_turn.merge(errors: [{ message: "something went wrong", ts: "2026-01-01T00:00:30.000Z" }])
    html = render_turn(turn)
    assert_includes html, "something went wrong"
    assert_includes html, "bg-red-50"
  end

  test "render_session_footer shows aggregated stats" do
    html = render_session_footer(sample_session)
    assert_includes html, "1 turns"
    assert_includes html, "150"
    assert_includes html, "42"
    assert_includes html, "60.0s"
    assert_includes html, "completed"
  end

  test "render_session_footer returns nil for empty session" do
    session = sample_session.merge(turns: [])
    assert_nil render_session_footer(session)
  end

  test "render_error shows red banner" do
    html = render_error("fatal error")
    assert_includes html, "fatal error"
    assert_includes html, "bg-red-50"
    assert_includes html, "border-red-200"
  end

  test "tool_icon returns correct emoji for known tools" do
    assert_equal "\u{1f4c4}", tool_icon("read")
    assert_equal "\u{1f4bb}", tool_icon("bash")
    assert_equal "\u{1f50d}", tool_icon("web_search")
    assert_equal "\u{1f310}", tool_icon("web_fetch")
    assert_equal "\u{1f50c}", tool_icon("mcp")
    assert_equal "\u{1f4dd}", tool_icon("file_change")
    assert_equal "\u{1f527}", tool_icon("unknown_tool")
  end

  test "tool_display_label extracts path from input" do
    assert_equal "app/models/user.rb", tool_display_label("read", { "file_path" => "app/models/user.rb" })
    assert_equal "ls -la", tool_display_label("bash", { "command" => "ls -la" })
    assert_equal "*.rb", tool_display_label("glob", { "pattern" => "*.rb" })
  end

  test "tool_display_label extracts url from input" do
    label = tool_display_label("web_fetch", { "url" => "https://example.com" })
    assert_equal "https://example.com", label
  end

  test "tool_display_label truncates long paths" do
    label = tool_display_label("read", { "file_path" => "a" * 100 })
    assert_operator label.length, :<=, 60
  end

  test "tool_display_label returns nil when no relevant keys" do
    label = tool_display_label("some_tool", { "foo" => "bar" })
    assert_nil label
  end
end
