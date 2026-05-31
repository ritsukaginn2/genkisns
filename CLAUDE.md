# GenkiSNS 开发规范

## 当前 Repo 结构

```text
apps/mobile/          Flutter App
services/llm-proxy/   V1.6 LLM 代理后端
docs/                 产品、设计、架构文档
```

移动端相关命令都在 `apps/mobile` 下执行：

```bash
cd apps/mobile
flutter analyze
flutter test
flutter run -d <device-id>
```

## 当前阶段

- V1 Flutter App 已进入原生运行验收阶段。
- V1 已接入本地 SQLite，发布内容、图片引用、喜欢、AI 评论和本地回复需要跨重启恢复。
- V1 不接入真实 LLM 后端，AI 互动先由本地模板生成。
- V1.6 实现 `services/llm-proxy`、付费额度、队列和真实 LLM。
- 真实 LLM provider API key 禁止写入 Flutter App，只能放在后端环境变量或云端 secret 中。

## 关键规则

- Phase 4+ 验收使用 `flutter run`，不再用 `board.html` 或 `build/web` 作为正式验收入口。
- `docs/v1-mvp/prototype/board.html` 只作为设计归档。
- Flutter 正式代码在 `apps/mobile/lib/`。
- Flutter 测试在 `apps/mobile/test/`。
- UI 实验室和设计预览继续与正式 App 路由隔离。
- 后端代码只放在 `services/llm-proxy/`，不要混进 Flutter 工程。

## 关键文档

- V1 需求文档：`docs/v1-mvp/需求文档.md`
- V1.6 需求文档：`docs/v1.6-llm-billing/需求文档.md`
- V1 前端架构：`docs/v1-mvp/frontend_architecture.md`
- V1 后端与数据架构：`docs/v1-mvp/backend_architecture.md`
- V1 Flutter Run 验收清单：`docs/v1-mvp/FlutterRun验收清单.md`
