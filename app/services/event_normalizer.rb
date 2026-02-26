# frozen_string_literal: true

require "json"
require "time"

module EventNormalizer
  TOOL_NAME_MAP = {
    # Claude Code tool names
    "Bash"      => "bash",
    "Read"      => "read",
    "Write"     => "write",
    "Edit"      => "edit",
    "Glob"      => "glob",
    "Grep"      => "grep",
    "WebSearch" => "web_search",
    "WebFetch"  => "web_fetch",
    # Codex item types
    "command_execution" => "bash",
    "file_change"       => "file_change",
    "mcp_tool_call"     => "mcp",
    "web_search"        => "web_search",
    "todo_list"         => "todo_list",
  }.freeze

  CODEX_TOOL_ITEM_TYPES = %w[command_execution file_change mcp_tool_call web_search todo_list].freeze

  def normalize_tool_name(name)
    TOOL_NAME_MAP[name] || name.to_s.downcase
  end

  def emit(event)
    event["ts"] ||= Time.now.utc.iso8601(3)
    @events << event
  end

  def self.detect_source(line_data)
    type = line_data["type"].to_s
    # Claude Code
    return :claude if type.include?("message_start") || type.include?("content_block") || type == "ping" || type == "system" || type == "message_delta" || type == "message_stop"
    return :claude if %w[assistant user result].include?(type)
    return :claude if line_data.key?("stream_event")
    # Codex streaming format
    return :codex if type.start_with?("thread.") || type.start_with?("turn.") || type.start_with?("item.") || type.include?("delta") || type == "error"
    nil
  end

  def self.normalize(raw_data_array)
    return { events: [], normalizer: nil } if raw_data_array.nil? || raw_data_array.empty?

    normalizer = nil

    raw_data_array.each do |entry|
      data = entry.is_a?(String) ? (JSON.parse(entry) rescue nil) : entry
      next if data.nil? || !data.is_a?(Hash) || data.empty?

      if normalizer.nil?
        source = detect_source(data)
        normalizer = case source
                     when :claude then ClaudeCodeNormalizer.new
                     when :codex  then CodexNormalizer.new
                     end
        next unless normalizer
      end

      normalizer.process(data)
    end

    normalizer&.finalize
    { events: normalizer&.events || [], normalizer: normalizer&.normalizer_name }
  end

  # --- Claude Code Normalizer ---

  class ClaudeCodeNormalizer
    include EventNormalizer

    attr_reader :events

    def normalizer_name = "ClaudeCodeNormalizer"

    def initialize
      @events = []
      @turn_index = -1
      @session_started = false
      @session_id = nil
      @model = nil
      @blocks = {}
      @stop_reason = nil
      @usage = nil
      @message_id = nil
    end

    def process(raw)
      type = raw["type"]
      return if type == "ping"

      case type
      when "system"
        handle_system(raw)
      when "assistant"
        handle_assistant(raw)
      when "message_start"
        handle_message_start(raw)
      when "content_block_start"
        handle_content_block_start(raw)
      when "content_block_delta"
        handle_content_block_delta(raw)
      when "content_block_stop"
        handle_content_block_stop(raw)
      when "message_delta"
        handle_message_delta(raw)
      when "message_stop"
        handle_message_stop(raw)
      when "result", "user"
        # tool results already captured from assistant; result is aggregated stats
      end
    end

    def finalize
      emit({ "type" => "session.end", "source" => "claude", "status" => "completed" })
    end

    private

    def handle_system(raw)
      return if @session_started
      subtype = raw.dig("subtype")
      return unless subtype == "init"
      @session_started = true
      @session_id = raw.dig("session_id")
      @model = raw["model"]
      emit({ "type" => "session.start", "source" => "claude", "session_id" => @session_id, "model" => @model })
    end

    def handle_message_start(raw)
      msg = raw.dig("message") || {}
      @turn_index += 1
      @message_id = msg["id"]
      @model ||= msg["model"]
      @blocks = {}
      @stop_reason = nil
      @usage = nil

      unless @session_started
        @session_started = true
        emit({ "type" => "session.start", "source" => "claude", "session_id" => @session_id, "model" => @model })
      end

      emit({ "type" => "turn.start", "source" => "claude", "turn_index" => @turn_index, "message_id" => @message_id })
    end

    def handle_content_block_start(raw)
      idx = raw["index"]
      cb = raw["content_block"] || {}
      block_type = cb["type"]

      block = { "type" => block_type, "text" => String.new, "input_json" => String.new }

      if block_type == "tool_use"
        block["tool_use_id"] = cb["id"]
        block["tool"] = cb["name"]
        emit({
          "type" => "tool.start", "source" => "claude",
          "turn_index" => @turn_index,
          "tool_use_id" => cb["id"],
          "tool" => normalize_tool_name(cb["name"]),
          "input" => {}
        })
      end

      @blocks[idx] = block
    end

    def handle_content_block_delta(raw)
      idx = raw["index"]
      delta = raw["delta"] || {}
      block = @blocks[idx]
      return unless block

      case delta["type"]
      when "text_delta"
        block["text"] << (delta["text"] || "")
        emit({
          "type" => "message.delta", "source" => "claude",
          "turn_index" => @turn_index,
          "text" => delta["text"] || ""
        })
      when "thinking_delta"
        block["text"] << (delta["thinking"] || "")
        emit({
          "type" => "thinking.delta", "source" => "claude",
          "turn_index" => @turn_index,
          "text" => delta["thinking"] || ""
        })
      when "input_json_delta"
        block["input_json"] << (delta["partial_json"] || "")
        emit({
          "type" => "tool.delta", "source" => "claude",
          "turn_index" => @turn_index,
          "tool_use_id" => block["tool_use_id"],
          "partial_json" => delta["partial_json"] || ""
        })
      end
    end

    def handle_content_block_stop(raw)
      idx = raw["index"]
      block = @blocks.delete(idx)
      return unless block

      case block["type"]
      when "text"
        emit({
          "type" => "message", "source" => "claude",
          "turn_index" => @turn_index,
          "text" => block["text"]
        })
      when "thinking"
        emit({
          "type" => "thinking", "source" => "claude",
          "turn_index" => @turn_index,
          "text" => block["text"]
        })
      when "tool_use"
        input = begin
          JSON.parse(block["input_json"])
        rescue
          {}
        end
        emit({
          "type" => "tool.end", "source" => "claude",
          "turn_index" => @turn_index,
          "tool_use_id" => block["tool_use_id"],
          "tool" => normalize_tool_name(block["tool"]),
          "input" => input
        })
      end
    end

    def handle_message_delta(raw)
      delta = raw["delta"] || {}
      @stop_reason = delta["stop_reason"]
      @usage = raw["usage"]
    end

    def handle_message_stop(_raw)
      emit({
        "type" => "turn.end", "source" => "claude",
        "turn_index" => @turn_index,
        "status" => "completed",
        "stop_reason" => @stop_reason,
        "usage" => @usage
      })
    end

    def ensure_session_started(raw)
      return if @session_started
      @session_started = true
      @session_id = raw["session_id"]
      @model = raw["model"] || raw.dig("message", "model")
      emit({ "type" => "session.start", "source" => "claude", "session_id" => @session_id, "model" => @model })
    end

    def handle_assistant(raw)
      ensure_session_started(raw)

      msg = raw["message"] || {}
      @model ||= msg["model"]
      @turn_index += 1
      emit({ "type" => "turn.start", "source" => "claude", "turn_index" => @turn_index, "message_id" => msg["id"] })

      blocks = msg["content"] || []
      usage = msg["usage"]

      blocks.each do |block|
        case block["type"]
        when "text"
          emit({ "type" => "message", "source" => "claude", "turn_index" => @turn_index, "text" => block["text"] || "" })
        when "thinking"
          emit({ "type" => "thinking", "source" => "claude", "turn_index" => @turn_index, "text" => block["text"] || "" })
        when "tool_use"
          tool_name = block["name"] || "unknown"
          tool_id = block["id"] || ""
          input = block["input"] || {}
          emit({ "type" => "tool.start", "source" => "claude", "turn_index" => @turn_index, "tool_use_id" => tool_id, "tool" => normalize_tool_name(tool_name), "input" => input })
          emit({ "type" => "tool.end", "source" => "claude", "turn_index" => @turn_index, "tool_use_id" => tool_id, "tool" => normalize_tool_name(tool_name), "input" => input })
        end
      end

      has_tool_use = blocks.any? { |b| b["type"] == "tool_use" }
      stop_reason = has_tool_use ? "tool_use" : "end_turn"

      emit({ "type" => "turn.end", "source" => "claude", "turn_index" => @turn_index, "status" => "completed", "stop_reason" => stop_reason, "usage" => usage })
    end
  end

  # --- Codex Normalizer ---

  class CodexNormalizer
    include EventNormalizer

    attr_reader :events

    def normalizer_name = "CodexNormalizer"

    def initialize
      @events = []
      @turn_index = -1
      @session_id = nil
    end

    def process(raw)
      type = raw["type"]

      case type
      when "thread.started"
        @session_id = raw["thread_id"]
        emit({ "type" => "session.start", "source" => "codex", "session_id" => @session_id, "model" => raw["model"] })
      when "turn.started"
        @turn_index += 1
        emit({ "type" => "turn.start", "source" => "codex", "turn_index" => @turn_index, "message_id" => raw["message_id"] })
      when "turn.completed"
        emit({
          "type" => "turn.end", "source" => "codex",
          "turn_index" => @turn_index,
          "status" => "completed",
          "stop_reason" => raw["stop_reason"],
          "usage" => raw["usage"]
        })
      when "turn.failed"
        emit({
          "type" => "turn.end", "source" => "codex",
          "turn_index" => @turn_index,
          "status" => "failed",
          "stop_reason" => nil,
          "usage" => nil
        })
        emit({ "type" => "error", "source" => "codex", "message" => raw["error"] || "turn failed" })
      when "item.started"
        handle_item_started(raw)
      when "item.completed"
        handle_item_completed(raw)
      when "agent_message.content.delta"
        emit({ "type" => "message.delta", "source" => "codex", "turn_index" => @turn_index, "text" => raw["delta"] || "" })
      when "reasoning.content.delta"
        emit({ "type" => "thinking.delta", "source" => "codex", "turn_index" => @turn_index, "text" => raw["delta"] || "" })
      when "error"
        emit({ "type" => "error", "source" => "codex", "message" => raw["message"] || raw["error"] || "unknown error" })
      end
    end

    def finalize
      emit({ "type" => "session.end", "source" => "codex", "status" => "completed" })
    end

    private

    def handle_item_started(raw)
      item_type = raw["item_type"] || raw.dig("item", "type")
      return unless CODEX_TOOL_ITEM_TYPES.include?(item_type)

      emit({
        "type" => "tool.start", "source" => "codex",
        "turn_index" => @turn_index,
        "tool_use_id" => raw["item_id"] || raw.dig("item", "id") || "",
        "tool" => normalize_tool_name(item_type),
        "input" => extract_tool_input(raw["item"] || raw)
      })
    end

    def handle_item_completed(raw)
      item = raw["item"] || raw
      item_type = item["type"]

      case item_type
      when "agent_message"
        text = extract_text(item)
        emit({ "type" => "message", "source" => "codex", "turn_index" => @turn_index, "text" => text })
      when "reasoning"
        text = extract_text(item)
        emit({ "type" => "thinking", "source" => "codex", "turn_index" => @turn_index, "text" => text })
      else
        if CODEX_TOOL_ITEM_TYPES.include?(item_type)
          emit({
            "type" => "tool.end", "source" => "codex",
            "turn_index" => @turn_index,
            "tool_use_id" => item["id"] || "",
            "tool" => normalize_tool_name(item_type),
            "input" => extract_tool_input(item)
          })
        end
      end
    end

    def extract_text(item)
      return item["text"] if item["text"].is_a?(String)
      content = item["content"]
      return content if content.is_a?(String)
      return content.map { |c| c["text"] || "" }.join if content.is_a?(Array)
      ""
    end

    def extract_tool_input(item)
      return item["input"] if item["input"].is_a?(Hash)
      return { "command" => item["command"] } if item["command"]
      {}
    end
  end

end

# --- CLI entrypoint ---
if __FILE__ == $0
  normalizer = nil

  $stdin.each_line do |line|
    line = line.strip
    next if line.empty?

    begin
      data = JSON.parse(line)
    rescue JSON::ParserError
      next
    end

    if normalizer.nil?
      source = EventNormalizer.detect_source(data)
      normalizer = case source
                   when :claude then EventNormalizer::ClaudeCodeNormalizer.new
                   when :codex  then EventNormalizer::CodexNormalizer.new
                   else
                     $stderr.puts "Unable to detect source from first event: #{data["type"]}"
                     exit 1
                   end
      # Override emit for CLI stdout mode
      def normalizer.emit(event)
        event["ts"] ||= Time.now.utc.iso8601(3)
        @events << event
        $stdout.puts(JSON.generate(event))
        $stdout.flush
      end
    end

    normalizer.process(data)
  end

  normalizer&.finalize
end
