# Interactive BEHAVIOR Skill Plan

## Goal

把当前“一次性跑完整 rollout”的 OpenCode skill 体系改成“Host 可分段控制”的交互式架构。一阶段只完成单任务 `turning_on_radio`：OpenCode 每次让环境推进 K 步，收到 BEHAVIOR 返回的完成信号后决定继续或结束。

本机只做开发与静态检查，不启动 BEHAVIOR、不启动 VLA、不跑仿真验证。

## Current Baseline

- 现有旧 skill 位于 `.opencode/skills/behavior-task-runner`。
- 旧实现通过 `.opencode/skills/behavior-task-runner/scripts/run_behavior_task.sh`：
  - 启动 OpenPI VLA server：`uv run scripts/serve_b1k.py ...`
  - 调用 BEHAVIOR evaluator：`python -m omnigibson.eval.eval ...`
  - evaluator 一直循环到 `terminated or truncated`，最后写视频和 JSON。
- 旧实现需要保留为参考，尤其是：
  - 环境变量
  - checkpoint 路径
  - GPU 设置
  - OpenPI server 启动命令
  - BEHAVIOR evaluator 参数和日志目录组织

## Key Architecture Decision

需要新增 BEHAVIOR-side server/controller 代码，但不修改原 BEHAVIOR 文件。

原因：

- OpenCode 不能直接控制 `omnigibson.eval.eval` 的内部 while loop。
- 现有 `Evaluator.step()` 已经提供单步推进能力，并能通过 `evaluator.env.task.success` 或 step 返回的 `info["done"]["success"]` 获取任务完成信号。
- 最低开发量方案是新增一个薄封装入口，复用 BEHAVIOR 的 `Evaluator`、`WebsocketPolicy` 和视频写入能力，而不是改原 evaluator。

建议新增位置：

- `../BEHAVIOR-1K/OmniGibson/omnigibson/eval/interactive_server.py`

该文件作为新增模块，可用 `python -m omnigibson.eval.interactive_server ...` 启动。它内部持有一个长期存活的 `Evaluator` session，对外暴露少量控制接口。

## Runtime Roles

- Host: OpenCode，通过 skill 调用脚本，负责高层编排。
- Env_server: 新增的 BEHAVIOR interactive server，负责环境 session、K-step 推进、成功信号、视频与日志。
- VLA_server: OpenPI policy server，保持现有启动方式，不改 OpenPI 代码。

## Phase 1 Skills

一阶段建议拆成多个命名 skill。这样 OpenCode 可以把“启动基础设施”“推进环境”“执行具体任务”分开理解，也方便二阶段串联多个任务。

### 1. `behavior-task-runner`

现有 legacy skill，保留作参考，不作为新架构的主入口。

职责：

- 保留旧的一次性 rollout 启动方式。
- 作为 OpenPI VLA server 启动命令、BEHAVIOR evaluator 参数、环境变量和日志组织的参考。
- 必要时可手动用于对比，但新任务编排不依赖它。

目录：

```text
.opencode/skills/behavior-task-runner/
```

### 2. `behavior-vla-server`

新增基础设施 skill，负责 OpenPI VLA server 生命周期。

职责：

- 根据任务名解析 checkpoint 和 policy config。
- 启动 OpenPI VLA server。
- 等待 `/healthz` 或日志 ready。
- 返回 server host、port、pid、log path。
- 只停止自己启动的 server，不杀未知进程。

建议目录：

```text
.opencode/skills/behavior-vla-server/
```

主要脚本：

```text
.opencode/skills/behavior-vla-server/scripts/vla_server.sh
```

命令形态：

```bash
bash .opencode/skills/behavior-vla-server/scripts/vla_server.sh start turning_on_radio
bash .opencode/skills/behavior-vla-server/scripts/vla_server.sh status turning_on_radio
bash .opencode/skills/behavior-vla-server/scripts/vla_server.sh stop turning_on_radio
```

### 3. `behavior-env-server`

新增基础设施 skill，负责 BEHAVIOR interactive Env_server 生命周期。

职责：

- 启动新增的 BEHAVIOR interactive server。
- 管理 Env_server pid、端口、run dir、env log。
- 调用 Env_server 的 `start/status/stop` API。
- 不修改 BEHAVIOR 原有代码，只依赖新增的 `interactive_server.py`。

建议目录：

```text
.opencode/skills/behavior-env-server/
```

主要脚本：

```text
.opencode/skills/behavior-env-server/scripts/env_server.sh
```

命令形态：

```bash
bash .opencode/skills/behavior-env-server/scripts/env_server.sh start turning_on_radio
bash .opencode/skills/behavior-env-server/scripts/env_server.sh status turning_on_radio
bash .opencode/skills/behavior-env-server/scripts/env_server.sh stop turning_on_radio
```

### 4. `behavior-k-step`

新增交互 skill，负责让 BEHAVIOR 环境推进 K 步并返回结构化结果。

职责：

- 调用 Env_server 的 `step_k` API。
- 每次只推进 K 步。
- 返回 OpenCode 可读 JSON。
- 暴露 `done/success/terminated/truncated/steps_total/observation_summary`。
- 不直接启动 OpenPI 或 BEHAVIOR，只要求对应 server 已经 ready。

建议目录：

```text
.opencode/skills/behavior-k-step/
```

主要脚本：

```text
.opencode/skills/behavior-k-step/scripts/step_k.sh
```

命令形态：

```bash
bash .opencode/skills/behavior-k-step/scripts/step_k.sh turning_on_radio --k 20
```

### 5. `turning-on-radio-interactive`

新增任务级 skill，一阶段主入口。

职责：

- 将“打开收音机”“turn on the radio”“turning_on_radio”映射到 `turning_on_radio`。
- 调用 `behavior-vla-server` 启动 VLA server。
- 调用 `behavior-env-server` 启动 BEHAVIOR Env_server。
- 循环调用 `behavior-k-step`。
- 根据返回的 `success/done` 决定继续、停止或报告失败。
- 成功后报告视频、run dir 和日志路径。

建议目录：

```text
.opencode/skills/turning-on-radio-interactive/
```

这个 skill 是一阶段用户请求的默认入口；其他几个 skill 是它会用到的基础能力。

## Minimal Host Contract

OpenCode skill 只依赖稳定 CLI/JSON，不理解 BEHAVIOR 内部状态。

推荐命令：

```bash
bash .opencode/skills/behavior-vla-server/scripts/vla_server.sh start turning_on_radio
bash .opencode/skills/behavior-env-server/scripts/env_server.sh start turning_on_radio
bash .opencode/skills/behavior-k-step/scripts/step_k.sh turning_on_radio --k 20
bash .opencode/skills/behavior-env-server/scripts/env_server.sh status turning_on_radio
bash .opencode/skills/behavior-env-server/scripts/env_server.sh stop turning_on_radio
bash .opencode/skills/behavior-vla-server/scripts/vla_server.sh stop turning_on_radio
```

每个命令输出 JSON。核心字段：

```json
{
  "ok": true,
  "task_name": "turning_on_radio",
  "session_id": "20260729-151500",
  "state": "running",
  "steps_total": 40,
  "steps_executed": 20,
  "done": false,
  "success": false,
  "terminated": false,
  "truncated": false,
  "observation_summary": {},
  "run_dir": "/home/robots/g00806422/demo/logs/behavior/turning_on_radio/20260729-151500",
  "video_path": null,
  "server_log": "...",
  "env_log": "..."
}
```

失败时：

```json
{
  "ok": false,
  "task_name": "turning_on_radio",
  "error": "short actionable error",
  "log_path": "..."
}
```

## Phase 1 Scope

### 1. Preserve old runner

- 保留 `.opencode/skills/behavior-task-runner/scripts/run_behavior_task.sh`。
- 在文档中标注它是 legacy end-to-end runner。
- 新交互式实现不要复用它的长 while loop，只复用启动配置和环境变量。

### 2. Add task config

新增或扩展配置，至少包含：

- `WORK_ROOT`
- `BEHAVIOR_ROOT`
- `OPENPI_ROOT`
- `BEHAVIOR_PYTHON`
- `SERVER_HOST`
- `SERVER_PORT`
- `ENV_SERVER_HOST`
- `ENV_SERVER_PORT`
- `K_STEPS`
- `MAX_HOST_ROUNDS`
- `turning_on_radio` checkpoint mapping

二阶段预留：

- `putting_away_Halloween_decorations` task name
- 对应 checkpoint path
- 可能的 instance indices 和 task-specific 参数

### 3. Add `behavior-vla-server`

新增 VLA server 管理 skill 和脚本，负责：

- 启动 OpenPI server。
- 等待 `/healthz` 或日志 ready。
- 记录 PID、端口、日志路径。
- 只停止自己启动的进程。
- 如果端口被占用，返回错误，不杀未知进程。

沿用旧 runner 中的启动方式：

```bash
cd "$OPENPI_ROOT"
uv run scripts/serve_b1k.py \
  --task_name "$TASK_NAME" \
  --control_mode "$CONTROL_MODE" \
  --max_len "$MAX_LEN" \
  --port "$SERVER_PORT" \
  policy:checkpoint \
  --policy.config "$POLICY_CONFIG" \
  --policy.dir "$TASK_CKPT"
```

### 4. Add BEHAVIOR interactive server

新增 BEHAVIOR 文件，不修改旧文件。

职责：

- 创建 `Evaluator(cfg)`。
- `reset()` 并 `load_task_instance(instance_id)`。
- 可选 `start_recording(video_path)`。
- 接收 `step_k` 请求后执行最多 K 次 `evaluator.step()`。
- 每步后检查：
  - `terminated`
  - `truncated`
  - `bool(evaluator.env.task.success)`
- K 步结束或 done 后返回 JSON。
- `stop` 时关闭视频 writer、聚合 metrics、释放环境。

接口建议先用 HTTP，比自定义 stdin loop 更容易被 Host 调用和调试：

- `GET /healthz`
- `POST /session/start`
- `POST /session/step`
- `GET /session/status`
- `POST /session/stop`

一阶段可以只支持单 session，避免并发和资源管理复杂化。

### 5. Add `behavior-env-server`

新增：

- `.opencode/skills/behavior-env-server/SKILL.md`
- `.opencode/skills/behavior-env-server/scripts/env_server.sh`

职责：

- source `config.sh`。
- 管理 run dir 和 pid files。
- 启动 BEHAVIOR interactive server。
- 把 `start/status/stop` 转成 HTTP 请求。
- 输出 OpenCode 可读 JSON。

状态文件建议放在：

```text
$WORK_ROOT/logs/behavior_interactive/<task_name>/current.env
$WORK_ROOT/logs/behavior_interactive/<task_name>/<session_id>/
```

### 6. Add `behavior-k-step`

新增：

- `.opencode/skills/behavior-k-step/SKILL.md`
- `.opencode/skills/behavior-k-step/scripts/step_k.sh`

职责：

- source `config.sh`。
- 调用 Env_server 的 `POST /session/step`。
- 支持 `--k` 参数。
- 原样输出 Env_server 返回的 JSON。
- 遇到 Env_server 未启动或不健康，返回短错误和日志路径。

### 7. Add `turning-on-radio-interactive`

新增任务级主 skill：

- `.opencode/skills/turning-on-radio-interactive/SKILL.md`

OpenCode 执行逻辑：

1. 用户请求 `turning_on_radio` 或“打开收音机”时，先调用 `behavior-vla-server`。
2. 再调用 `behavior-env-server`。
3. 循环调用 `behavior-k-step`。
3. 如果 JSON 中 `success=true`，调用 `stop` 并报告结果。
4. 如果 `done=true` 但 `success=false`，停止并报告任务失败或超时。
5. 如果达到 `MAX_HOST_ROUNDS` 仍未成功，停止并报告未完成。
6. 清理顺序为先停 Env_server，再停 VLA_server。

## Phase 1 Deliverables

- `AGENTS.md`：项目职责和约束。
- `plan.md`：本计划。
- `.opencode/skills/behavior-task-runner/`：保留 legacy runner。
- `.opencode/skills/behavior-vla-server/`：新增 VLA server 管理 skill。
- `.opencode/skills/behavior-env-server/`：新增 BEHAVIOR Env_server 管理 skill。
- `.opencode/skills/behavior-k-step/`：新增 K-step 交互 skill。
- `.opencode/skills/turning-on-radio-interactive/`：新增一阶段任务级主 skill。
- 共享配置文件：可先复用 legacy `config.sh`，也可后续抽到 `.opencode/skills/_shared/config.sh`，以实际 OpenCode skill 发现规则为准。
- `../BEHAVIOR-1K/OmniGibson/omnigibson/eval/interactive_server.py`：新增 BEHAVIOR Env_server。

## Risks and Open Questions

- BEHAVIOR evaluator 的 `Evaluator` 是否能在一次进程内稳定执行多次 K-step，需要服务器端验证。
- `evaluator.step()` 返回的 `terminated/truncated` 与 `env.task.success` 的关系需要实测确认；一阶段以 `env.task.success` 为主。
- 视频 writer 在分段 step 下应持续打开，到 stop 时关闭；如果中途 crash，需要保留可诊断日志。
- 如果二阶段两个任务必须在同一个 BEHAVIOR 世界状态中连续执行，需要额外设计跨 task reset 或 scene transition；如果两个任务是独立 episode，二阶段只需要顺序启动两个 session。

## Recommended Implementation Order

1. 保留并标注 `behavior-task-runner` 为 legacy/reference。
2. 抽出共享配置，或确定多个 skill 如何引用 legacy `config.sh`。
3. 新增 `interactive_server.py`，复用 `eval.py` 的 cfg 构造逻辑和 `Evaluator`。
4. 接入 `start/step/status/stop` HTTP API。
5. 实现 `behavior-vla-server` skill。
6. 实现 `behavior-env-server` skill。
7. 实现 `behavior-k-step` skill。
8. 实现 `turning-on-radio-interactive` task skill。
9. 为 `turning_on_radio` 接入 checkpoint mapping。
10. 静态检查文件路径、命令参数和 JSON 契约。
11. 交给服务器运行验证，根据实际错误迭代。
