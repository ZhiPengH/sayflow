<claude-mem-context>
# Memory Context

# claude-mem status

This project has no memory yet. The current session will seed it; subsequent sessions will receive auto-injected context for relevant past work.

Memory injection starts on your second session in a project.

`/learn-codebase` is available if the user wants to front-load the entire repo into memory in a single pass (~5 minutes on a typical repo, optional). Otherwise memory builds passively as work happens.

Live activity: http://localhost:37701
How it works: `/how-it-works`

This message disappears once the first observation lands.
</claude-mem-context>

## 发布流程（正式版）

用户说「发布」（且确认手动测试已通过）后，运行 `Scripts/ship_release.sh`。该脚本会依次：校验 dist/ 中已公证 DMG 的 SHA-256 与 staple 票据 → 推送发布分支并通过 PR 合并到 main → 调用 `Scripts/publish_release.sh --use-existing-artifacts` 发布 GitHub Release。

规则：

- 用户未明确确认手动测试通过时，不得执行任何 push、PR 合并或 release 操作；先询问。
- 发布必须走 `Scripts/notarize_release.sh` + `Scripts/ship_release.sh`；禁止手工 `gh release create`、手工 push tag 或直接 push main（main 受分支保护，走 PR + admin merge）。
- 只汇报关键结果：DMG 校验、PR 编号、Release 链接；不要复述完整脚本输出。
- 发布失败时保留现场，报告失败步骤与退出码，不要自动重试发布动作。
