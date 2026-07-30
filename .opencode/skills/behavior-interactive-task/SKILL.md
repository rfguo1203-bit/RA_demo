---
name: behavior-interactive-task
description: Run one configured BEHAVIOR task interactively to completion by reusing the VLA server, Env server, and K-step skills. Supports turning_on_radio and putting_away_Halloween_decorations.
---

# BEHAVIOR Interactive Task

Run exactly one BEHAVIOR task with the interactive K-step architecture.

Supported tasks:

- `turning_on_radio`
- `putting_away_Halloween_decorations`

## Workflow

Run:

```bash
bash <skill-base>/scripts/run_task.sh turning_on_radio
```

or:

```bash
bash <skill-base>/scripts/run_task.sh putting_away_Halloween_decorations
```

The script will:

1. Start the task's VLA server.
2. Start the task's BEHAVIOR Env_server.
3. Advance the task by `K_STEPS` chunks.
4. Stop Env_server and VLA server when the task succeeds, ends, or reaches `MAX_HOST_ROUNDS`.

## Rules

- Use this skill for a single task only.
- For a user request with two tasks, the Host should call this skill once per task in the requested order.
- If the first task fails, do not start the second task.
- Do not use the legacy end-to-end runner.
- Keep stdout as JSON.
