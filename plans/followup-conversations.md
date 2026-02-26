# Follow-up Conversations for Runs

## Context

Currently one prompt = one run = one sandbox execution. The container is destroyed after each run. We want users to send follow-up messages to a run, creating a multi-turn conversation where the agent can build on prior workspace changes.

## Approach: Keep Containers Alive + Workspace Conversation Log

Each `opencode run` is stateless (no conversation memory). Two mechanisms give the agent context:

1. **Persistent container** — keeps the workspace alive between turns so the agent sees files it created/modified
2. **CONVERSATION.md** — after each turn, append the user's prompt and a summary of the agent's response to `/workspace/CONVERSATION.md`. The agent reads this file on the next turn to understand prior context. This mirrors how OpenHands, Aider, and SWE-agent all pass history — every system replays conversation to the LLM since APIs are stateless.

**Status lifecycle:** `queued → running → awaiting_followup → running → ... → completed/failed`

---

## Changes

### 1. Migration: Add conversation support
- Add `container_id` (string) to `runs` — tracks the live container
- Add `turn` (integer, default 0) to `run_entries` — groups entries by which prompt they belong to

### 2. Model: `app/models/run.rb`
- Add `awaiting_followup` to status validation

### 3. Store user messages as RunEntries
- Each user prompt saved as a RunEntry with `data: { "type": "user.message", "text": "...", "ts": "..." }`
- Keeps all conversation data in one table, no new models needed

### 4. Modify SandboxJob: `app/jobs/sandbox_job.rb`
- Accept `turn:` keyword arg (default 0)
- Turn 0: provision container, store `container_id` on Run, write AGENTS.md
- Turn > 0: reuse `container_id` from Run record, skip AGENTS.md
- Save user message as RunEntry before execution
- Pass `turn:` to `save_run_entries` so entries get the right turn number
- **After execution**: append to `/workspace/CONVERSATION.md` in the container with:
  - The user's prompt for this turn
  - The agent's result text (extracted from events)
  - This gives the next turn's agent full conversation context
- On success: set status to `awaiting_followup` (not `completed`)
- On failure: destroy container, set `container_id: nil`
- Remove container destruction from `ensure` block

### 5. Extract SandboxManager: `app/services/sandbox_manager.rb`
- Move `provision_sandbox`, `destroy_sandbox` into shared service
- Used by SandboxJob, CompletesController, ContainerCleanupJob

### 6. New job: `app/jobs/container_cleanup_job.rb`
- Finds runs in `awaiting_followup` with `updated_at` older than 30 minutes
- Destroys their containers, sets status to `completed`
- Scheduled to run every 5 minutes via solid_queue recurring config

### 7. Routes: `config/routes.rb`
```ruby
resources :runs, only: [:index, :show, :create, :new] do
  resources :run_entries, only: [:create]
  resource :followup, only: [:create]   # POST /runs/:run_id/followup
  resource :complete, only: [:create]   # POST /runs/:run_id/complete
end
```

### 8. New controller: `app/controllers/followups_controller.rb`
- Validates run is in `awaiting_followup` state
- Calculates next turn number from `run_entries.maximum(:turn) + 1`
- Enqueues `SandboxJob.perform_later(run.id, prompt, turn: next_turn)`
- Redirects to run show page

### 9. New controller: `app/controllers/completes_controller.rb`
- Destroys container via SandboxManager
- Sets run status to `completed`, clears `container_id`
- Redirects to run show page

### 10. Update RunsController#show: `app/controllers/runs_controller.rb`
- Group entries by `turn`, build a `conversation` array of turn groups
- Each turn group has: `turn_number`, `user_message` (text), `session` (normalized events)
- Pass `conversation` to the view instead of a single `session`

### 11. Update view: `app/views/runs/show.html.erb`
- Iterate over `conversation` array
- Render user message bubble before each agent turn group
- Add `awaiting_followup` badge (indigo)
- Add follow-up form at bottom when status is `awaiting_followup` (textarea + Send button + End conversation button)
- Keep meta-refresh for `queued`/`running` only (no refresh during `awaiting_followup`)

---

## Key Trade-offs

- **Conversation context via file, not API**: The LLM reads `CONVERSATION.md` from the workspace rather than receiving structured message history. This is simpler than building a message-replay system but means context quality depends on the agent exploring the workspace. The AGENTS.md instructions already tell the agent to explore before acting, so this works naturally.
- **No WebSockets**: Keeps existing meta-refresh polling. Consistent with CLAUDE.md guidance to minimize JS.
- **Container cost**: 512MB per idle container. 30-min timeout prevents accumulation.
- **Future optimization**: If conversations get long, we could summarize older turns in CONVERSATION.md using an LLM call before writing it. For now, raw append is fine.

## Verification
1. Create a new run with a prompt → should see agent response, status becomes `awaiting_followup`
2. Send a follow-up → status goes to `running`, then back to `awaiting_followup`
3. Click "End conversation" → status becomes `completed`, container destroyed
4. Leave a run idle for 30+ min → cleanup job marks it completed
5. Check runs index shows `awaiting_followup` badge correctly
