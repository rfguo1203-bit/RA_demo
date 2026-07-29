---
name: behavior-vla-server
description: Start, inspect, and stop the OpenPI VLA websocket server for configured BEHAVIOR tasks. Use when an interactive BEHAVIOR task needs policy inference infrastructure.
---

# BEHAVIOR VLA Server

Manage only the OpenPI VLA server process started by this skill.

## Workflow

1. Resolve this skill directory.
2. For `turning_on_radio`, run:

   ```bash
   bash <skill-base>/scripts/vla_server.sh start turning_on_radio
   ```

3. Check status with:

   ```bash
   bash <skill-base>/scripts/vla_server.sh status turning_on_radio
   ```

4. Stop only this skill's owned server with:

   ```bash
   bash <skill-base>/scripts/vla_server.sh stop turning_on_radio
   ```

## Rules

- Do not edit OpenPI code.
- Do not kill a process unless its pid was written by this skill.
- If the configured port is already in use by an unknown process, return the JSON error and ask the user to resolve it.
- Keep stdout as JSON so other skills can consume it.
