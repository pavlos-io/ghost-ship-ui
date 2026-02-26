require "open3"
require "json"
require "base64"

class SandboxJob < ApplicationJob
  queue_as :default

  SANDBOX_IMAGE = "agent-sandbox:latest"
  TIMEOUT_SECONDS = 600

  def perform(run_id, prompt)
    run = Run.find(run_id)
    run.update!(status: "running")

    container_id = provision_sandbox
    result_text = run_in_sandbox(container_id, run, prompt)
    run.update!(status: "completed", result: result_text)
  rescue => e
    run&.update!(status: "failed", result: e.message)
    raise
  ensure
    destroy_sandbox(container_id) if container_id
  end

  private

  def provision_sandbox
    stdout, stderr, status = Open3.capture3(
      "docker", "run", "-d",
      "--memory=512m",
      "--cpus=1",
      "-l", "role=agent-sandbox",
      SANDBOX_IMAGE,
      "sleep", "infinity"
    )

    raise "Failed to start sandbox: #{stderr}" unless status.success?

    container_id = stdout.strip
    Rails.logger.info("[SandboxJob] Container started: #{container_id[0..11]}")
    container_id
  end

  def run_in_sandbox(container_id, run, prompt)
    agents_md = build_agents_md(prompt)
    write_agents_md(container_id, agents_md)
    cmd = build_cli_command(prompt)

    Rails.logger.info("[SandboxJob] Running opencode in #{container_id[0..11]}")

    stdout, stderr, status = Open3.capture3(
      "docker", "exec", "-w", "/workspace", container_id,
      "sh", "-c", cmd
    )

    Rails.logger.info("[SandboxJob] opencode finished | exit_code=#{status.exitstatus}")
    Rails.logger.info("[SandboxJob] STDOUT (#{stdout.bytesize} bytes): #{stdout[0..2000]}")
    Rails.logger.warn("[SandboxJob] STDERR: #{stderr[0..2000]}") if stderr.present?

    events = parse_json_output(stdout)
    save_run_entries(run, events)

    return "Agent timed out after 10 minutes." if status.exitstatus == 137

    extract_result(events, stdout)
  end

  def build_agents_md(prompt)
    <<~MD
      You are an autonomous software engineering agent running inside a Docker sandbox.
      Your workspace is /workspace. All file paths are relative to that directory.

      ## Guidelines
      - Explore the workspace before making changes (list files, read code).
      - After editing files, verify your changes (read the file back, run tests if applicable).
      - Do NOT attempt to access the internet or external services.
      - When you are done, provide a concise summary of what you did.
    MD
  end

  def write_agents_md(container_id, content)
    encoded = Base64.strict_encode64(content)

    _stdout, stderr, status = Open3.capture3(
      "docker", "exec", container_id,
      "sh", "-c", "echo #{encoded} | base64 -d > /workspace/AGENTS.md"
    )

    raise "Failed to write AGENTS.md: #{stderr}" unless status.success?
  end

  def build_cli_command(prompt)
    quoted = shell_quote(prompt)

    "timeout --signal=KILL #{TIMEOUT_SECONDS} opencode run #{quoted} --model opencode/minimax-m2.5-free --format json"
  end

  def parse_json_output(raw_output)
    events = []
    raw_output.each_line do |line|
      line = line.strip
      next if line.empty?

      begin
        events << JSON.parse(line)
      rescue JSON::ParserError
        Rails.logger.warn("[SandboxJob] Skipping malformed JSON line: #{line[0..200]}")
      end
    end
    events
  end

  def save_run_entries(run, events)
    events.each do |event|
      run.run_entries.create!(data: event)
    end
    Rails.logger.info("[SandboxJob] Saved #{events.size} run entries")
  end

  def extract_result(events, raw_output)
    # Check for error events
    error_event = events.find { |e| e["type"] == "error" }
    if error_event
      error_msg = error_event.dig("error", "data", "message") || error_event.dig("error", "message") || "Unknown error"
      return "Agent error: #{error_msg}"
    end

    # Collect text parts from opencode events (type: "text", part.text holds the content)
    text_parts = events.select { |e| e["type"] == "text" }.filter_map { |e| e.dig("part", "text") }
    return text_parts.join("\n") if text_parts.any?

    # Last resort
    "(Agent finished without a summary)"
  end

  def shell_quote(s)
    "'" + s.gsub("'", "'\\\\''") + "'"
  end

  def destroy_sandbox(container_id)
    Rails.logger.info("[SandboxJob] Destroying container #{container_id[0..11]}...")
    Open3.capture3("docker", "stop", "-t", "5", container_id)
    Open3.capture3("docker", "rm", container_id)
    Rails.logger.info("[SandboxJob] Container destroyed")
  rescue => e
    Rails.logger.error("[SandboxJob] Failed to destroy container: #{e.message}")
  end
end
