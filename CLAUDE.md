# GenkiSNS 开发规范

## 严格遵守 mobile-app-design skill 工作流

本项目**必须**按照 mobile-app-design skill 的六个阶段顺序推进，不得跳跃。

```
Phase 0:  Discovery（已完成）
Phase 1:  需求文档（已完成）→ docs/v1-mvp/需求文档.md
Phase 1.5:UI 方向选板（已完成）→ 选定方向 B（小红书/笔记风格）
Phase 2:  主页面设计看板（已完成）→ docs/v1-mvp/prototype/board.html
Phase 3:  前端架构 + 设计看板 + 可点击原型（当前阶段 ★）
  3a: 前端架构文档（已完成）→ docs/v1-mvp/frontend_architecture.md
  3b: 所有页面/子页面/组件/状态的静态设计看板（进行中）
  3c: 完成看板后，再串联可点击原型
Phase 4:  需求最终确认 + 前后端架构对齐（未开始）
Phase 5:  实装（用真实数据替换 mock）（未开始）
Phase 6:  打磨、测试、发布准备（未开始）
```

## 当前阶段规则（Phase 3b）

- **只做 UI**。不接真实 LLM、不写业务逻辑、不做数据持久化。
- 每次 UI 改动后执行 `flutter build web --release --base-href "/build/web/"` 并在 board.html 验证效果。
- 看板地址：`http://localhost:8181/docs/v1-mvp/prototype/board.html`（服务器：`python3 -m http.server 8181 --directory .`）
- 设计看板必须覆盖所有页面、子页面、状态，经用户 sign-off 后才进入 3c。

## Phase 3b 待完成项

参见 board.html 底部「缺口」区块：
- [ ] Onboarding 流程 UI 确认（代码已有，待接入 main.dart）
- [ ] AI 好友列表：BottomSheet 还是独立页面？
- [ ] 发布成功反馈：Snackbar 够用，还是需要过渡页？
- [ ] 评论 loading 状态（V1 同步生成，是否需要 skeleton？）

## 禁止事项（Phase 3b 期间）

- ❌ 接入 LLM API
- ❌ 实现数据持久化（SQLite / 云端）
- ❌ 实现 Onboarding → 首页的真实跳转逻辑（UI 可以做，逻辑等 Phase 5）
- ❌ 在没有完成 Phase 3 sign-off 的情况下进入 Phase 4/5

## 设计方向

- **UI 风格**：B 方向（小红书/笔记风格），品牌色 coral `#FF4F8B`
- **UI 实验室**：A（朋友圈）/ B（当前主方向）/ C（碎语）保留在 `design_directions_page.dart`，入口在「我的」→「UI 实验室」
- **设计 token**：全部在 `lib/theme/app_theme.dart`，禁止页面内内联颜色字面量

## 关键文档

- 需求文档：`docs/v1-mvp/需求文档.md`
- 前端架构：`docs/v1-mvp/frontend_architecture.md`
- 设计看板：`docs/v1-mvp/prototype/board.html`
