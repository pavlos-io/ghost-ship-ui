require "test_helper"

class EventNormalizerTest < ActiveSupport::TestCase
  test "detect_source identifies Claude Code events" do
    assert_equal :claude, EventNormalizer.detect_source({ "type" => "system", "subtype" => "init" })
    assert_equal :claude, EventNormalizer.detect_source({ "type" => "message_start" })
    assert_equal :claude, EventNormalizer.detect_source({ "type" => "content_block_start" })
    assert_equal :claude, EventNormalizer.detect_source({ "type" => "message_delta" })
    assert_equal :claude, EventNormalizer.detect_source({ "type" => "message_stop" })
  end

  test "detect_source identifies Codex events" do
    assert_equal :codex, EventNormalizer.detect_source({ "type" => "thread.started" })
    assert_equal :codex, EventNormalizer.detect_source({ "type" => "turn.started" })
    assert_equal :codex, EventNormalizer.detect_source({ "type" => "item.started" })
    assert_equal :codex, EventNormalizer.detect_source({ "type" => "error" })
  end

  test "detect_source identifies Claude Code conversational events" do
    assert_equal :claude, EventNormalizer.detect_source({ "type" => "assistant" })
    assert_equal :claude, EventNormalizer.detect_source({ "type" => "user" })
    assert_equal :claude, EventNormalizer.detect_source({ "type" => "result" })
    assert_equal :claude, EventNormalizer.detect_source({ "type" => "system", "model" => "claude-sonnet-4-5-20250929" })
  end

  test "detect_source returns nil for unknown events" do
    assert_nil EventNormalizer.detect_source({ "type" => "unknown_event" })
  end

  test "normalize returns empty events and nil normalizer for nil input" do
    result = EventNormalizer.normalize(nil)
    assert_equal [], result[:events]
    assert_nil result[:normalizer]
  end

  test "normalize returns empty events and nil normalizer for empty input" do
    result = EventNormalizer.normalize([])
    assert_equal [], result[:events]
    assert_nil result[:normalizer]
  end

  test "normalize processes Claude Code streaming events" do
    raw_data = [
      { "type" => "system", "subtype" => "init", "session_id" => "sess_123" },
      { "type" => "message_start", "message" => { "id" => "msg_1", "model" => "claude-sonnet-4-5-20250929" } },
      { "type" => "content_block_start", "index" => 0, "content_block" => { "type" => "text" } },
      { "type" => "content_block_delta", "index" => 0, "delta" => { "type" => "text_delta", "text" => "Hello" } },
      { "type" => "content_block_delta", "index" => 0, "delta" => { "type" => "text_delta", "text" => " world!" } },
      { "type" => "content_block_stop", "index" => 0 },
      { "type" => "message_delta", "delta" => { "stop_reason" => "end_turn" }, "usage" => { "input_tokens" => 10, "output_tokens" => 20 } },
      { "type" => "message_stop" }
    ]

    result = EventNormalizer.normalize(raw_data)
    events = result[:events]
    assert_equal "ClaudeCodeNormalizer", result[:normalizer]

    types = events.map { |e| e["type"] }
    assert_includes types, "session.start"
    assert_includes types, "turn.start"
    assert_includes types, "message.delta"
    assert_includes types, "message"
    assert_includes types, "turn.end"
    assert_includes types, "session.end"

    session_start = events.find { |e| e["type"] == "session.start" }
    assert_equal "claude", session_start["source"]
    assert_equal "sess_123", session_start["session_id"]

    message = events.find { |e| e["type"] == "message" }
    assert_equal "Hello world!", message["text"]

    turn_end = events.find { |e| e["type"] == "turn.end" }
    assert_equal "completed", turn_end["status"]
    assert_equal "end_turn", turn_end["stop_reason"]
    assert_equal 10, turn_end["usage"]["input_tokens"]
  end

  test "normalize processes Claude Code tool use events" do
    raw_data = [
      { "type" => "message_start", "message" => { "id" => "msg_1", "model" => "claude-sonnet-4-5-20250929" } },
      { "type" => "content_block_start", "index" => 0, "content_block" => { "type" => "tool_use", "id" => "tu_1", "name" => "Bash" } },
      { "type" => "content_block_delta", "index" => 0, "delta" => { "type" => "input_json_delta", "partial_json" => '{"command":' } },
      { "type" => "content_block_delta", "index" => 0, "delta" => { "type" => "input_json_delta", "partial_json" => '"ls"}' } },
      { "type" => "content_block_stop", "index" => 0 },
      { "type" => "message_delta", "delta" => { "stop_reason" => "tool_use" } },
      { "type" => "message_stop" }
    ]

    events = EventNormalizer.normalize(raw_data)[:events]

    tool_start = events.find { |e| e["type"] == "tool.start" }
    assert_equal "bash", tool_start["tool"]
    assert_equal "tu_1", tool_start["tool_use_id"]

    tool_end = events.find { |e| e["type"] == "tool.end" }
    assert_equal "bash", tool_end["tool"]
    assert_equal({ "command" => "ls" }, tool_end["input"])
  end

  test "normalize processes Claude Code thinking events" do
    raw_data = [
      { "type" => "system", "subtype" => "init", "session_id" => "sess_123" },
      { "type" => "message_start", "message" => { "id" => "msg_1", "model" => "claude-sonnet-4-5-20250929" } },
      { "type" => "content_block_start", "index" => 0, "content_block" => { "type" => "thinking" } },
      { "type" => "content_block_delta", "index" => 0, "delta" => { "type" => "thinking_delta", "thinking" => "Let me think..." } },
      { "type" => "content_block_stop", "index" => 0 },
      { "type" => "content_block_start", "index" => 1, "content_block" => { "type" => "text" } },
      { "type" => "content_block_delta", "index" => 1, "delta" => { "type" => "text_delta", "text" => "Hi!" } },
      { "type" => "content_block_stop", "index" => 1 },
      { "type" => "message_delta", "delta" => { "stop_reason" => "end_turn" }, "usage" => { "input_tokens" => 10, "output_tokens" => 20 } },
      { "type" => "message_stop" }
    ]

    events = EventNormalizer.normalize(raw_data)[:events]

    thinking = events.find { |e| e["type"] == "thinking" }
    assert_equal "Let me think...", thinking["text"]

    message = events.find { |e| e["type"] == "message" }
    assert_equal "Hi!", message["text"]
  end

  test "normalize processes Codex events" do
    raw_data = [
      { "type" => "_metadata", "source" => "cli", "trigger_user_name" => "cli-user", "model_provider" => "codex" },
      { "type" => "thread.started", "thread_id" => "019c528a-ba6b-7b80-9c75-48a639bd899c" },
      { "type" => "turn.started" },
      { "type" => "item.started", "item" => { "id" => "item_0", "type" => "command_execution", "command" => "/bin/bash -lc ls", "aggregated_output" => "", "exit_code" => nil, "status" => "in_progress" } },
      { "type" => "item.completed", "item" => { "id" => "item_0", "type" => "command_execution", "command" => "/bin/bash -lc ls", "aggregated_output" => "AGENTS.md\n", "exit_code" => 0, "status" => "completed" } },
      { "type" => "item.completed", "item" => { "id" => "item_3", "type" => "agent_message", "text" => "Summary: listed workspace contents." } },
      { "type" => "turn.completed", "usage" => { "input_tokens" => 35210, "cached_input_tokens" => 25984, "output_tokens" => 295 } }
    ]

    result = EventNormalizer.normalize(raw_data)
    events = result[:events]
    assert_equal "CodexNormalizer", result[:normalizer]

    session_start = events.find { |e| e["type"] == "session.start" }
    assert_equal "codex", session_start["source"]
    assert_equal "019c528a-ba6b-7b80-9c75-48a639bd899c", session_start["session_id"]

    message = events.find { |e| e["type"] == "message" }
    assert_equal "Summary: listed workspace contents.", message["text"]

    tool_start = events.find { |e| e["type"] == "tool.start" }
    assert_equal "bash", tool_start["tool"]

    tool_end = events.find { |e| e["type"] == "tool.end" }
    assert_equal({ "command" => "/bin/bash -lc ls" }, tool_end["input"])

    turn_end = events.find { |e| e["type"] == "turn.end" }
    assert_equal 35210, turn_end["usage"]["input_tokens"]
    assert_equal 295, turn_end["usage"]["output_tokens"]
  end

  test "normalize handles Codex error events" do
    raw_data = [
      { "type" => "thread.started", "thread_id" => "th_002" },
      { "type" => "turn.started" },
      { "type" => "turn.failed", "error" => "context window exceeded" },
      { "type" => "error", "message" => "fatal: something went wrong" }
    ]

    events = EventNormalizer.normalize(raw_data)[:events]
    types = events.map { |e| e["type"] }

    assert_includes types, "turn.end"
    turn_end = events.find { |e| e["type"] == "turn.end" }
    assert_equal "failed", turn_end["status"]

    errors = events.select { |e| e["type"] == "error" }
    assert_equal 2, errors.size
    assert_equal "context window exceeded", errors[0]["message"]
    assert_equal "fatal: something went wrong", errors[1]["message"]
  end

  test "normalize skips nil and empty entries in raw data" do
    raw_data = [
      nil,
      {},
      { "type" => "system", "subtype" => "init", "session_id" => "sess_123" },
      { "type" => "message_start", "message" => { "id" => "msg_1", "model" => "claude-sonnet-4-5-20250929" } },
      { "type" => "message_delta", "delta" => { "stop_reason" => "end_turn" } },
      { "type" => "message_stop" }
    ]

    events = EventNormalizer.normalize(raw_data)[:events]
    assert events.any? { |e| e["type"] == "session.start" }
  end

  test "normalize processes Claude Code conversational format" do
    raw_data = [
      { "type" => "system", "subtype" => "init", "model" => "claude-sonnet-4-5-20250929", "session_id" => "sess_legacy" },
      { "type" => "assistant", "message" => { "id" => "msg_1", "model" => "claude-sonnet-4-5-20250929", "content" => [{ "type" => "text", "text" => "Hello!" }] } },
      { "type" => "result", "usage" => { "input_tokens" => 100, "output_tokens" => 50 } }
    ]

    result = EventNormalizer.normalize(raw_data)
    events = result[:events]
    assert_equal "ClaudeCodeNormalizer", result[:normalizer]

    types = events.map { |e| e["type"] }
    assert_includes types, "session.start"
    assert_includes types, "turn.start"
    assert_includes types, "message"
    assert_includes types, "turn.end"
    assert_includes types, "session.end"

    message = events.find { |e| e["type"] == "message" }
    assert_equal "Hello!", message["text"]
  end
end
