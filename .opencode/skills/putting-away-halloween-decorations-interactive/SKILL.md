---
name: putting-away-halloween-decorations-interactive
description: Run the BEHAVIOR task putting_away_Halloween_decorations interactively using the shared behavior-interactive-task runner. Use for Chinese requests like “收起万圣节装饰”.
---

# Putting Away Halloween Decorations Interactive

Use this skill when the user asks to put away Halloween decorations, including “收起万圣节装饰” or `putting_away_Halloween_decorations`.

## Workflow

Run the shared single-task runner:

```bash
bash <skills-dir>/behavior-interactive-task/scripts/run_task.sh putting_away_Halloween_decorations
```

Report the returned JSON. On success, include `video_path`, `run_dir`, `result_path`, and logs if present.

## Rules

- This is a thin task alias.
- Do not duplicate server lifecycle logic here.
- For a sequence after `turning_on_radio`, only run this after the first task returns `success=true` and its servers have stopped.
