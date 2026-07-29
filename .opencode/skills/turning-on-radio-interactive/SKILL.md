---
name: turning-on-radio-interactive
description: Complete the BEHAVIOR task turning_on_radio interactively by starting VLA and Env servers, advancing K steps at a time, and stopping when BEHAVIOR reports success.
---

# Turning On Radio Interactive

Use this skill when the user asks to open, turn on, test, demonstrate, or record the radio task, including “打开收音机”, “开启收音机”, “turn on the radio”, or `turning_on_radio`.

## Workflow

1. Resolve the sibling skill directories under `.opencode/skills`.
2. Read `<skills-dir>/_shared/config.sh` for `K_STEPS` and `MAX_HOST_ROUNDS`; defaults are acceptable if the config does not override them.
3. Start the VLA server:

   ```bash
   bash <skills-dir>/behavior-vla-server/scripts/vla_server.sh start turning_on_radio
   ```

4. Start the BEHAVIOR Env_server:

   ```bash
   bash <skills-dir>/behavior-env-server/scripts/env_server.sh start turning_on_radio
   ```

5. Repeatedly run bounded interaction:

   ```bash
   bash <skills-dir>/behavior-k-step/scripts/step_k.sh turning_on_radio --k "$K_STEPS"
   ```

6. After each JSON response:
   - If `success=true`, stop Env_server, then stop VLA server, and report success with `video_path`, `run_dir`, `env_log`, and `server_log`.
   - If `done=true` and `success=false`, stop both servers and report the failure/timeout.
   - If `done=false`, continue until the configured `MAX_HOST_ROUNDS` is reached.
7. If the maximum host rounds are reached without success, stop both servers and report incomplete status.

## Rules

- This is the phase-1 task-level entrypoint.
- Do not call the legacy `behavior-task-runner` for normal interactive execution.
- Do not run unbounded rollouts.
- Keep BEHAVIOR/OpenPI source changes out of this skill; it only orchestrates other skills.
- If any start or step command returns `ok=false`, stop owned servers and summarize the JSON error.
