---
name: behavior-k-step
description: Advance an already-started interactive BEHAVIOR environment by K policy-controlled steps and return task status JSON.
---

# BEHAVIOR K-Step

Advance the current BEHAVIOR session by a bounded number of VLA-controlled steps.

## Workflow

Run:

```bash
bash <skill-base>/scripts/step_k.sh turning_on_radio --k 20
```

Use the returned JSON fields:

- `success=true`: the task is complete.
- `done=true` and `success=false`: the episode ended or timed out without success.
- `done=false`: call this skill again if the task-level skill decides to continue.

## Rules

- Do not start servers here.
- Do not loop indefinitely inside this skill.
- Keep stdout as JSON.
