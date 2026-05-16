# GenkiSNS V1 前端架构

> Phase 3a 决策记录。只记录「选了什么、为什么」，不展开实现细节。

---

## 文件夹结构

```
lib/
  main.dart                     ← App 入口、GenkiShell 导航、web preview URL 路由
  models.dart                   ← 数据模型（UserProfile / AiFriend / Post / Comment）
  mock/
    mock_data.dart              ← 所有 mock 数据（defaultUser / presetFriends / mockPosts）
  pages/
    onboarding_page.dart        ← 引导流程（3 步：说明 / 创建主页 / 选 AI 好友）
    home_page.dart              ← 首页（瀑布流 / 空状态）
    create_post_page.dart       ← 发布笔记
    post_detail_page.dart       ← 笔记详情（含评论区）
    profile_page.dart           ← 我的
    about_page.dart             ← 关于
    design_directions_page.dart ← UI 实验室（A/B/C，从「我的」隐藏入口进入）
  theme/
    app_theme.dart              ← 设计 token（AppColors / AppSpacing / AppTheme）
  widgets/
    avatar_mark.dart            ← 头像组件
```

---

## 状态管理

**选择**：`StatefulWidget` + lifting state up（状态提升至 `_GenkiSnsAppState`）

**理由**：V1 只有一个用户会话，全局状态只有三个字段（user / posts / selectedFriendIds），无需引入第三方库。

**迁移条件**：当状态需要跨页面异步更新（例如：真实数据库 stream、评论延时推送），迁移至 Riverpod。

---

## 路由

**选择**：命令式 `Navigator.push` + web preview 专用 URL 参数路由

**理由**：V1 页面流向线性，无深链接需求，无需 go_router。`Uri.base.queryParameters['view']` 仅用于设计看板 iframe 直接访问各页面，不影响 app 实际运行。

### Web preview 路由表

| `?view=` | 页面 |
|---|---|
| `home` | 首页（有内容）|
| `home-empty` | 首页（空状态）|
| `create` | 发布笔记 |
| `detail` | 笔记详情 |
| `profile` | 我的 |
| `about` | 关于 |
| `onboarding-1` | Onboarding — 说明 |
| `onboarding-2` | Onboarding — 创建主页 |
| `onboarding-3` | Onboarding — 选 AI 好友 |
| `designs` | UI 实验室（A/B/C）|
| （无参数）| 正式 app（GenkiShell）|

---

## 设计 Token（`lib/theme/app_theme.dart`）

页面和组件内禁止内联颜色字面量，所有颜色和间距通过 token 引用。

| Token | 值 | 用途 |
|---|---|---|
| `AppColors.background` | `#FFF5F8` | 页面背景 |
| `AppColors.surface` | `#FFFFFF` | 卡片、输入框 |
| `AppColors.ink` | `#231722` | 主文字 |
| `AppColors.muted` | `#806D78` | 次要文字 |
| `AppColors.line` | `#F2D9E3` | 分割线、边框 |
| `AppColors.coral` | `#FF4F8B` | 主品牌色、选中状态 |
| `AppColors.teal` | `#51D1F6` | 辅助强调 |
| `AppColors.blue` | `#755CFF` | 辅助强调 |
| `AppColors.yellow` | `#FFD166` | 辅助强调 |
| `AppColors.softPink` | `#FFEAF2` | 浅色背景块 |

间距：`xs=4 / sm=8 / md=12 / lg=16 / xl=24 / xxl=32`

---

## 已知缺口（Phase 3b 设计看板待确认）

- AI 好友列表目前是 BottomSheet，尚无独立页面，待看板阶段确认形态
- Onboarding 流程代码已写好，但未接入 `main.dart`（下一步实装）
- 发布成功反馈目前仅 Snackbar，是否需要独立过渡页面待确认
- 评论加载状态未设计（V1 评论同步生成，暂无 loading 状态）
