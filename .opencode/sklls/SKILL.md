---
name: behavior-task-runner
description: Run configured BEHAVIOR-1K robot evaluation tasks and produce rollout videos by starting the OpenPI policy server and then launching OmniGibson evaluation. Use automatically when the user asks to execute, test, demonstrate, or record a BEHAVIOR task, especially Chinese requests containing “打开收音机”, “开启收音机”, “测试打开收音机”, or English requests such as “turn on the radio” and “run turning_on_radio”.
---

# BEHAVIOR Task Runner

Execute a configured BEHAVIOR task end to end. Do not merely print the server and evaluator commands.

## Workflow

1. Map the user request to a supported task:
   - “打开收音机”, “开启收音机”, “turn on the radio”, or `turning_on_radio` -> `turning_on_radio`.
   - For any unsupported task, explain that no checkpoint mapping is configured and do not guess a checkpoint.
2. Resolve this skill's base directory from the path supplied by OpenCode's skill tool.
3. Check that `<skill-base>/config.sh` exists. If it is missing, tell the user to copy `config.sh.example` to `config.sh` and fill the paths. Do not invent machine paths.
4. Run the following command with a timeout long enough for model loading and one full rollout:

   ```bash
   bash <skill-base>/scripts/run_behavior_task.sh turning_on_radio
   ```

5. Let the script manage the server lifecycle. Do not separately start another policy server, do not reuse an unknown process already listening on the configured port, and do not kill unrelated processes.
6. On success, report the values printed as `VIDEO_PATH`, `RUN_DIR`, `SERVER_LOG`, and `EVAL_LOG`.
7. On failure, inspect the printed log paths and summarize the first actionable error. Preserve the run directory for debugging.

## Execution Rules

- Run the workflow immediately when the task intent is explicit; do not ask for confirmation merely because shell commands are required.
- Use the configured task name exactly: `turning_on_radio`.
- Keep the generated video and logs under the configured `WORK_ROOT`.
- Never edit checkpoints or BEHAVIOR/OpenPI source code as part of a normal task run.
- Never claim success unless the evaluator exits successfully and the script prints an existing `VIDEO_PATH`.
- If OpenCode requests permission for the shell command, request approval for only this runner script rather than broad unrestricted shell access.

## Setup and Extension

Read `references/setup.md` when installing, configuring, troubleshooting discovery, or adding more task-to-checkpoint mappings.
