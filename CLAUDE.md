# Developmemt Workflow

# 1. UI
- Always use tailwind, mobile first

# 2. Rails 
- Never send inastance vartianles to views. Always send locals explicitly.
- When using turbo frames/streams, create partials for the action and render it from view explicitly.
- Minimize javascript code. Prefer server side rendering, form submissions and turbo for live updates.
- Always use permitted params for POST/PUT routes
