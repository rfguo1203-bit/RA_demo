---
name: behavior-env-server
description: Start, inspect, and stop the interactive BEHAVIOR environment server used for K-step robot task control.
---

# BEHAVIOR Env Server

Manage the BEHAVIOR interactive server process. This skill starts only the environment server; it expects the VLA server to already be ready.

## Workflow

1. Start the server:

   ```bash
   bash <skill-base>/scripts/env_server.sh start turning_on_radio
   ```

2. Check status:

   ```bash
   bash <skill-base>/scripts/env_server.sh status turning_on_radio
   ```

3. Stop the server:

   ```bash
   bash <skill-base>/scripts/env_server.sh stop turning_on_radio
   ```

## Rules

- Do not modify existing BEHAVIOR files; this skill depends on the added `omnigibson.eval.interactive_server` module.
- Do not start or stop OpenPI here.
- Keep stdout as JSON.
