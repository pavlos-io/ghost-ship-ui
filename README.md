# Ghost Ship UI

Web interface for running AI coding agents in sandboxed Docker containers using [opencode](https://opencode.ai).

## Prerequisites

- Ruby 3.3.4
- PostgreSQL
- Docker (for sandbox containers)

## Local Setup

```bash
# Install Ruby dependencies
bundle install

# Create and migrate databases
bin/rails db:prepare

# Build the sandbox Docker image
docker build -f Dockerfile.sandbox -t ghost-ship-sandbox .
```

## Running

```bash
bin/dev
```

This starts three processes via foreman (see `Procfile.dev`):
- **web** — Rails server on port 3000
- **css** — Tailwind CSS watcher
- **worker** — Solid Queue background job processor

Visit [http://localhost:3000](http://localhost:3000).

## Testing

```bash
bin/rails test
```

## Architecture

- **Rails 8.1** with Hotwire (Turbo + Stimulus), Propshaft, Importmap
- **PostgreSQL** for primary data and Solid Queue/Cache/Cable backing stores
- **Solid Queue** for background jobs (sandbox execution)
- **Tailwind CSS 4** for styling
- **Docker** — each run provisions a `ghost-ship-sandbox` container with opencode CLI installed, executes the agent, then streams results back
