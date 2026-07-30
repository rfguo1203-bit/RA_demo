---
name: turning-on-radio-interactive
description: Complete the BEHAVIOR task turning_on_radio interactively by starting VLA and Env servers, advancing K steps at a time, and stopping when BEHAVIOR reports success.
---

# Turning On Radio Interactive

Use this skill when the user asks to open, turn on, test, demonstrate, or record the radio task, including “打开收音机”, “开启收音机”, “turn on the radio”, or `turning_on_radio`.

## Workflow

Run the shared single-task runner:

```bash
bash <skills-dir>/behavior-interactive-task/scripts/run_task.sh turning_on_radio
```

Report the returned JSON. On success, include `video_path`, `run_dir`, `result_path`, and logs if present.

## Rules

- This is a thin task alias.
- Do not duplicate server lifecycle logic here.
- Do not run unbounded rollouts.
- For a sequence, only start the next task after this runner returns `success=true`; the shared runner stops its owned servers before returning.
