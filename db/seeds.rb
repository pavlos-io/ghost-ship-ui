run = Run.first

if run.run_entries.none?
  entries_json = []

  entries_json << <<~'JSON'
    {"type": "_metadata", "source": "cli", "trigger_user_name": "cli-user", "repo": null, "exit_code": 0, "elapsed_seconds": 22.38615608215332}
  JSON

  entries_json << <<~'JSON'
    {"type": "system", "subtype": "init", "cwd": "/workspace", "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "tools": ["Task", "TaskOutput", "Bash", "Glob", "Grep", "ExitPlanMode", "Read", "Edit", "Write", "NotebookEdit", "WebFetch", "TodoWrite", "WebSearch", "TaskStop", "AskUserQuestion", "Skill", "EnterPlanMode", "ToolSearch"], "mcp_servers": [], "model": "claude-sonnet-4-5-20250929", "permissionMode": "bypassPermissions", "slash_commands": ["debug", "compact", "context", "cost", "init", "pr-comments", "release-notes", "review", "security-review", "insights"], "apiKeySource": "none", "claude_code_version": "2.1.37", "output_style": "default", "agents": ["Bash", "general-purpose", "statusline-setup", "Explore", "Plan"], "skills": ["debug"], "plugins": [], "uuid": "9c11954a-0bfa-4604-9f16-b9859436f467"}
  JSON

  entries_json << <<~'JSON'
    {"type": "assistant", "message": {"model": "claude-sonnet-4-5-20250929", "id": "msg_01GE35NpH5icw99HsmWM3y6f", "type": "message", "role": "assistant", "content": [{"type": "text", "text": "I'll start by exploring the workspace to understand what's there and what needs to be tested."}], "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 2, "cache_creation_input_tokens": 3530, "cache_read_input_tokens": 15366, "cache_creation": {"ephemeral_5m_input_tokens": 0, "ephemeral_1h_input_tokens": 3530}, "output_tokens": 3, "service_tier": "standard", "inference_geo": "not_available"}, "context_management": null}, "parent_tool_use_id": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "uuid": "354acea6-d824-42d0-bee1-6aa5346f7a0a"}
  JSON

  entries_json << <<~'JSON'
    {"type": "assistant", "message": {"model": "claude-sonnet-4-5-20250929", "id": "msg_01GE35NpH5icw99HsmWM3y6f", "type": "message", "role": "assistant", "content": [{"type": "tool_use", "id": "toolu_01JygsDRYZqnVru48uXyZTWj", "name": "Bash", "input": {"command": "ls -la /workspace", "description": "List files in workspace"}}], "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 2, "cache_creation_input_tokens": 3530, "cache_read_input_tokens": 15366, "cache_creation": {"ephemeral_5m_input_tokens": 0, "ephemeral_1h_input_tokens": 3530}, "output_tokens": 3, "service_tier": "standard", "inference_geo": "not_available"}, "context_management": null}, "parent_tool_use_id": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "uuid": "75dac015-ef0b-4f41-8eb7-5aeb34470bba"}
  JSON

  entries_json << <<~'JSON'
    {"type": "user", "message": {"role": "user", "content": [{"tool_use_id": "toolu_01JygsDRYZqnVru48uXyZTWj", "type": "tool_result", "content": "total 8\ndrwxr-xr-x 2 sandbox sandbox 4096 Feb  8 23:24 .\ndrwxr-xr-x 1 root    root    4096 Feb 10 18:04 ..", "is_error": false}]}, "parent_tool_use_id": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "uuid": "2c62cc1f-9c3c-45d8-a65b-1c49076c239d", "tool_use_result": {"stdout": "total 8\ndrwxr-xr-x 2 sandbox sandbox 4096 Feb  8 23:24 .\ndrwxr-xr-x 1 root    root    4096 Feb 10 18:04 ..", "stderr": "", "interrupted": false, "isImage": false}}
  JSON

  entries_json << <<~'JSON'
    {"type": "assistant", "message": {"model": "claude-sonnet-4-5-20250929", "id": "msg_01VV3AenMrjGk81vYxjcmX8U", "type": "message", "role": "assistant", "content": [{"type": "text", "text": "The workspace is empty. Since the CLI prompt simply says \"test\" without specific context, I should check if there are any hidden files or if this is a fresh workspace where I need to create something to test."}], "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 5, "cache_creation_input_tokens": 165, "cache_read_input_tokens": 18896, "cache_creation": {"ephemeral_5m_input_tokens": 0, "ephemeral_1h_input_tokens": 165}, "output_tokens": 1, "service_tier": "standard", "inference_geo": "not_available"}, "context_management": null}, "parent_tool_use_id": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "uuid": "0f659c1b-1018-4938-bac0-2c91fcf56215"}
  JSON

  entries_json << <<~'JSON'
    {"type": "assistant", "message": {"model": "claude-sonnet-4-5-20250929", "id": "msg_01VV3AenMrjGk81vYxjcmX8U", "type": "message", "role": "assistant", "content": [{"type": "tool_use", "id": "toolu_019TuvS8ZzR4qEcRM3mC3hhX", "name": "Bash", "input": {"command": "pwd", "description": "Check current directory"}}], "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 5, "cache_creation_input_tokens": 165, "cache_read_input_tokens": 18896, "cache_creation": {"ephemeral_5m_input_tokens": 0, "ephemeral_1h_input_tokens": 165}, "output_tokens": 1, "service_tier": "standard", "inference_geo": "not_available"}, "context_management": null}, "parent_tool_use_id": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "uuid": "e35af528-a055-41e5-8ab3-f217d2a6f70b"}
  JSON

  entries_json << <<~'JSON'
    {"type": "user", "message": {"role": "user", "content": [{"tool_use_id": "toolu_019TuvS8ZzR4qEcRM3mC3hhX", "type": "tool_result", "content": "/workspace", "is_error": false}]}, "parent_tool_use_id": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "uuid": "246e0c70-35d8-4cd8-874e-071a495bec98", "tool_use_result": {"stdout": "/workspace", "stderr": "", "interrupted": false, "isImage": false}}
  JSON

  entries_json << <<~'JSON'
    {"type": "assistant", "message": {"model": "claude-sonnet-4-5-20250929", "id": "msg_01D9NBycVAviZKd73rtoMbbr", "type": "message", "role": "assistant", "content": [{"type": "text", "text": "The workspace is completely empty. Since the prompt is just \"test\" without further context, I'll interpret this as a request to verify that the testing environment is working correctly. Let me create a simple test to demonstrate functionality."}], "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 5, "cache_creation_input_tokens": 128, "cache_read_input_tokens": 19061, "cache_creation": {"ephemeral_5m_input_tokens": 0, "ephemeral_1h_input_tokens": 128}, "output_tokens": 1, "service_tier": "standard", "inference_geo": "not_available"}, "context_management": null}, "parent_tool_use_id": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "uuid": "995c351b-31f9-4fad-ab7a-36a8afbfc1ed"}
  JSON

  entries_json << <<~'JSON'
    {"type": "assistant", "message": {"model": "claude-sonnet-4-5-20250929", "id": "msg_01D9NBycVAviZKd73rtoMbbr", "type": "message", "role": "assistant", "content": [{"type": "tool_use", "id": "toolu_01S8vdUx8Bc28Pu9f1WKXvdT", "name": "Write", "input": {"file_path": "/workspace/test.py", "content": "#!/usr/bin/env python3\n\"\"\"Simple test script to verify the environment is working.\"\"\"\n\ndef add(a, b):\n    \"\"\"Add two numbers.\"\"\"\n    return a + b\n\ndef test_add():\n    \"\"\"Test the add function.\"\"\"\n    assert add(2, 3) == 5, \"2 + 3 should equal 5\"\n    assert add(-1, 1) == 0, \"(-1) + 1 should equal 0\"\n    assert add(0, 0) == 0, \"0 + 0 should equal 0\"\n    print(\"All tests passed!\")\n\nif __name__ == \"__main__\":\n    test_add()\n"}}], "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 5, "cache_creation_input_tokens": 128, "cache_read_input_tokens": 19061, "cache_creation": {"ephemeral_5m_input_tokens": 0, "ephemeral_1h_input_tokens": 128}, "output_tokens": 1, "service_tier": "standard", "inference_geo": "not_available"}, "context_management": null}, "parent_tool_use_id": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "uuid": "b96548d6-459b-4d1a-8034-f5670497f496"}
  JSON

  entries_json << <<~'JSON'
    {"type": "user", "message": {"role": "user", "content": [{"tool_use_id": "toolu_01S8vdUx8Bc28Pu9f1WKXvdT", "type": "tool_result", "content": "File created successfully at: /workspace/test.py"}]}, "parent_tool_use_id": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "uuid": "6dcf004e-9f65-49fb-b5ba-639bd5f2bd60", "tool_use_result": {"type": "create", "filePath": "/workspace/test.py", "content": "#!/usr/bin/env python3\n\"\"\"Simple test script to verify the environment is working.\"\"\"\n\ndef add(a, b):\n    \"\"\"Add two numbers.\"\"\"\n    return a + b\n\ndef test_add():\n    \"\"\"Test the add function.\"\"\"\n    assert add(2, 3) == 5, \"2 + 3 should equal 5\"\n    assert add(-1, 1) == 0, \"(-1) + 1 should equal 0\"\n    assert add(0, 0) == 0, \"0 + 0 should equal 0\"\n    print(\"All tests passed!\")\n\nif __name__ == \"__main__\":\n    test_add()\n", "structuredPatch": [], "originalFile": null}}
  JSON

  entries_json << <<~'JSON'
    {"type": "assistant", "message": {"model": "claude-sonnet-4-5-20250929", "id": "msg_01MzppnhRTvv8ZC98BUNMc9t", "type": "message", "role": "assistant", "content": [{"type": "tool_use", "id": "toolu_01UycjSCKMMRQnMNPpqv54PJ", "name": "Bash", "input": {"command": "python3 test.py", "description": "Run the test script"}}], "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 5, "cache_creation_input_tokens": 302, "cache_read_input_tokens": 19189, "cache_creation": {"ephemeral_5m_input_tokens": 0, "ephemeral_1h_input_tokens": 302}, "output_tokens": 25, "service_tier": "standard", "inference_geo": "not_available"}, "context_management": null}, "parent_tool_use_id": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "uuid": "5a6bc3ea-4250-4064-b567-ddefff5777ad"}
  JSON

  entries_json << <<~'JSON'
    {"type": "user", "message": {"role": "user", "content": [{"tool_use_id": "toolu_01UycjSCKMMRQnMNPpqv54PJ", "type": "tool_result", "content": "All tests passed!", "is_error": false}]}, "parent_tool_use_id": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "uuid": "ff159d6b-dbdb-40a4-aa22-9c13ff8a7389", "tool_use_result": {"stdout": "All tests passed!", "stderr": "", "interrupted": false, "isImage": false}}
  JSON

  entries_json << <<~'JSON'
    {"type": "assistant", "message": {"model": "claude-sonnet-4-5-20250929", "id": "msg_01PKWAy2wCh4bZTBB73a4stj", "type": "message", "role": "assistant", "content": [{"type": "text", "text": "Perfect! I've completed the task. Here's what I did:\n\n**Summary:**\n- Explored the workspace and found it was empty\n- Created a simple Python test script (`test.py`) with a basic function and test cases\n- Ran the test successfully, confirming the environment is working correctly\n\nThe test script includes:\n- An `add()` function that adds two numbers\n- A `test_add()` function with three test assertions\n- All tests passed successfully\n\nThe testing environment is functioning properly."}], "stop_reason": null, "stop_sequence": null, "usage": {"input_tokens": 4, "cache_creation_input_tokens": 93, "cache_read_input_tokens": 19491, "cache_creation": {"ephemeral_5m_input_tokens": 0, "ephemeral_1h_input_tokens": 93}, "output_tokens": 1, "service_tier": "standard", "inference_geo": "not_available"}, "context_management": null}, "parent_tool_use_id": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "uuid": "63503ff9-d574-403a-ab52-7447532541f1"}
  JSON

  entries_json << <<~'JSON'
    {"type": "result", "subtype": "success", "is_error": false, "duration_ms": 21147, "duration_api_ms": 21741, "num_turns": 5, "result": "Perfect! I've completed the task. Here's what I did:\n\n**Summary:**\n- Explored the workspace and found it was empty\n- Created a simple Python test script (`test.py`) with a basic function and test cases\n- Ran the test successfully, confirming the environment is working correctly\n\nThe test script includes:\n- An `add()` function that adds two numbers\n- A `test_add()` function with three test assertions\n- All tests passed successfully\n\nThe testing environment is functioning properly.", "stop_reason": null, "session_id": "2ed7f1dc-915f-4744-9e79-9b56bbb5a073", "total_cost_usd": 0.09185, "usage": {"input_tokens": 21, "cache_creation_input_tokens": 4218, "cache_read_input_tokens": 92003, "output_tokens": 680, "server_tool_use": {"web_search_requests": 0, "web_fetch_requests": 0}, "service_tier": "standard", "cache_creation": {"ephemeral_1h_input_tokens": 4218, "ephemeral_5m_input_tokens": 0}}, "modelUsage": {"claude-sonnet-4-5-20250929": {"inputTokens": 21, "outputTokens": 680, "cacheReadInputTokens": 92003, "cacheCreationInputTokens": 4218, "webSearchRequests": 0, "costUSD": 0.08946899999999999, "contextWindow": 200000, "maxOutputTokens": 64000}, "claude-haiku-4-5-20251001": {"inputTokens": 1876, "outputTokens": 101, "cacheReadInputTokens": 0, "cacheCreationInputTokens": 0, "webSearchRequests": 0, "costUSD": 0.002381, "contextWindow": 200000, "maxOutputTokens": 64000}}, "permission_denials": [], "uuid": "030e79b9-0193-4497-8f42-cfc5170f2e3d"}
  JSON

  entries_json.each do |json_str|
    run.run_entries.create!(data: JSON.parse(json_str))
  end
end
