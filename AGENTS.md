# Project Notes

- 本仓只维护 OpenCode skills 和相关开发文件；实际运行在服务器上完成，本机不运行、不验证仿真或模型。
- BEHAVIOR 代码本机也有，路径为 `../BEHAVIOR-1K`，与服务器端一致；如需改动，可新增文件后推送到服务器。
- OpenPI 相关代码原则上不修改；本仓只需要保留并复用其 VLA server 启动方式、环境变量和 checkpoint 配置。
- 大项目目标：用 OpenCode 作为 Host 调度 VLA，在 BEHAVIOR 仿真环境中完成任务。
- 当前目标：让 OpenCode 串联两个 BEHAVIOR 任务：
  - `turning_on_radio`
  - `putting_away_Halloween_decorations`
- 现有实现把启动 BEHAVIOR 和 VLA client 打包成一个长运行 skill；用户说“打开收音机”后 skill 一次性跑完整 rollout 并保存视频。
- 现有问题：长运行任务让 OpenCode 无法在中途观察、判断终止或切换到下一个任务。

## Proposed Runtime Roles

- Host: OpenCode，负责任务编排、阶段判断、调用 skill。
- Env_server: BEHAVIOR，负责仿真环境、observation、step、任务完成信号。
- VLA_server: VLA policy，接收 observation 并返回 action。

## Interaction Model

Host 向 Env_server 下发“交互 K 轮”的指令；Env_server 每轮把 observation 发给 VLA_server，拿到 action 后执行 step。K 轮结束后，Env_server 返回 observation 和任务完成信号给 Host。Host 决定继续 K 轮、结束当前任务，或进入下一个任务。

## Milestones

1. 单任务 `turning_on_radio`：构建新的交互式 skill，支持启动两个 server、运行 K 轮、接收任务完成信号，并由 Host 决定继续或结束。
2. 双任务串联：当用户表达“先做 A 再做 B”时，OpenCode 能识别并依次调用对应 skill。
3. 模型判定：不再依赖仿真环境完成信号，改由判定 skill 与记忆系统基于 observation 判断任务是否完成。

## Development Rules

- 本机只做静态开发，不启动 BEHAVIOR、不启动 VLA、不跑验证。
- 遇到依赖安装问题，先与用户一起解决，不擅自更换方案。
- 优先保持 skill 接口小而稳定，把任务配置、server 生命周期和 K-step 控制拆清楚。
- 保留旧 skill 作为参考，尤其是 BEHAVIOR/OpenPI client 的启动命令、环境变量和日志组织方式。
- 如需扩展 BEHAVIOR，只新增入口脚本或模块，不修改原有 BEHAVIOR 文件。
