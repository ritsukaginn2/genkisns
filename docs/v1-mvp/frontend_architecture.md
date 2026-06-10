# GenkiSNS V1 前端架构

> Phase 3a 决策记录。只记录「选了什么、为什么」，不展开实现细节。

---

## 文件夹结构

```
apps/mobile/
  lib/
    main.dart                     ← App 入口、GenkiShell 正式导航
    models.dart                   ← 数据模型（UserProfile / AiFriend / Post / Comment / LocalReply / PostImageRef）
    data/
      repositories/
        user_repository.dart      ← 默认用户资料数据源
        ai_friend_repository.dart ← V1 预设 AI 好友数据源
        post_repository.dart      ← 笔记创建、读取与写穿持久化
      services/
        interaction_service.dart  ← AI 互动生成入口与 fallback
        image_picker_service.dart ← 系统相机拍照/拍视频、App 内相册选择、文件复制和本地引用生成
        icloud_backup_service.dart ← iOS iCloud 备份/恢复本机数据库和媒体目录
      stores/
        post_store.dart           ← 笔记本地持久化接口与内存测试实现
        sqlite_post_store.dart    ← SQLite 本机持久化实现
    design_preview/
      preview_routes.dart         ← web preview URL 路由（仅设计板使用）
      board_preview_page.dart     ← 设计板组件 / 路由 / 反馈状态 iframe 预览
    mock/
      mock_data.dart              ← 所有 mock 数据（defaultUser / presetFriends / mockPosts）
    pages/
      home_page.dart              ← 首页（瀑布流 / 空状态）
      create_post_page.dart       ← 发布笔记（媒体来源 / 相册选择 / 已选回显 / 满图 / 单视频）
      post_detail_page.dart       ← 笔记详情（视频播放 / 喜欢 / 评论喜欢 / 回复 / 删除回复 / 删除笔记）
      profile_page.dart           ← 我的
      icloud_backup_page.dart     ← iCloud 备份/恢复
      friends_page.dart           ← AI 好友列表
      about_page.dart             ← 关于
      design_directions_page.dart ← UI 实验室（A/B/C，从「我的」隐藏入口进入）
    theme/
      app_theme.dart              ← 设计 token（AppColors / AppSpacing / AppTheme）
    widgets/
      avatar_mark.dart            ← 头像组件
      page_header.dart            ← 二级页统一顶部栏
services/llm-proxy/               ← V1.6 LLM 代理后端
```

---

## 状态管理

**选择**：`StatefulWidget` + Repository + SQLite `PostStore`（状态提升至 `_GenkiSnsAppState`）

**理由**：V1 只有一个本机用户，核心状态是默认用户、AI 好友、笔记、媒体、喜欢和本地回复；状态量还不需要第三方状态库，但用户创建内容必须落本地数据库。

**迁移条件**：当状态需要跨页面异步推送（例如：数据库 stream、评论延时推送、后台同步），迁移至 Riverpod。

---

## 路由

**选择**：命令式 `Navigator.push` + web preview 专用 URL 参数路由

**理由**：V1 页面流向线性，无深链接需求，无需 go_router。`Uri.base.queryParameters['view']` 仅用于设计看板 iframe 直接访问各页面，不影响 app 实际运行。

**边界**：正式 app 只走 `GenkiShell` 内部 `Navigator.push`。所有 `?view=` 预览入口集中在 `apps/mobile/lib/design_preview/preview_routes.dart`，不可散落到正式页面里。

### Web preview 路由表

| `?view=` | 页面 |
|---|---|
| `home` | 首页（有内容）|
| `home-empty` | 首页（空状态）|
| `create` | 发布笔记（空图） |
| `create-image-source` | 发布笔记（媒体来源选择层） |
| `create-album-picker` | 发布笔记（相册媒体选择层） |
| `create-album-reopen` | 发布笔记（相册已选回显） |
| `create-images` | 发布笔记（3 张图） |
| `create-full` | 发布笔记（9 张图满状态） |
| `detail` | 笔记详情（图文 + AI 评论） |
| `detail-text` | 笔记详情（纯文字） |
| `detail-liked` | 笔记详情（帖子已喜欢） |
| `detail-comment-liked` | 笔记详情（评论已喜欢） |
| `detail-reply` | 笔记详情（回复输入层） |
| `detail-replied` | 笔记详情（回复已提交） |
| `detail-reply-delete` | 笔记详情（删除回复确认层） |
| `detail-reply-deleted` | 笔记详情（回复已删除） |
| `profile` | 我的 |
| `friends` | AI 好友 |
| `about` | 关于 |
| `designs` | UI 实验室（A/B/C）|
| `board-navigation` | 入口与子状态预览 |
| `board-feedback` | 弹窗与反馈预览 |
| `board-components` | 组件库总览 |
| `board-components-core` | 基础组件 |
| `board-components-content` | 内容组件 |
| （无参数）| 正式 app（GenkiShell）|

---

## 设计 Token（`apps/mobile/lib/theme/app_theme.dart`）

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

## Phase 3b 已确认

### 正式 App 路由模型

V1 不使用底部 Tab。

- 首页点击头像 -> 我的页
- 首页点击发布按钮 -> 发布笔记页
- 首页点击笔记卡片 -> 笔记详情页
- 我的页点击 AI 好友 / 关于 GenkiSNS / UI 实验室 -> 对应二级页
- 发布成功 -> 返回首页

### 已确认页面状态

- 首页：有内容 / 空状态
- 发布笔记：空媒体 / 媒体来源选择 / 相册图片多选 / 相册已选回显 / 已添加图片 / 9 张满图 / 已添加视频
- 笔记详情：图文 / 纯文字 / 帖子已喜欢 / 评论已喜欢 / 回复输入 / 回复已提交 / 删除回复确认 / 回复已删除
- 我的与子页：我的 / AI 好友 / 关于 GenkiSNS / UI 实验室
- 组件库：头像、按钮、输入框、媒体选择、视频封面、笔记卡片、评论项、设置入口、底部 Sheet、确认层

### 交互规则

- 发布页点击添加媒体后，先出现媒体来源选择层：相机、相册、取消。
- 相机入口打开系统相机，由用户在系统相机内拍照或拍视频。
- 相机一次添加 1 张图片或 1 个视频。
- App 内相册选择层支持多选，最多补足到 9 张。
- App 内相册选择层支持视频单选。
- 再次打开相册选择层时，已添加的相册图片保持勾选；确认后以当前勾选集合同步发布页图片。
- V1 不支持图片和视频混排；视频与图片互斥。
- 发布成功后不弹出“AI 将会评论”的提示，直接回首页。
- 笔记详情支持帖子喜欢、评论喜欢、回复评论和删除笔记。
- 自己发送的本地回复可以删除，删除前出现确认层。
- 删除笔记入口在详情页右上角更多操作中，删除前出现确认层，删除后返回首页。

### Phase 3c 正式 Mock App 验收路径

无参数启动正式 App 后，必须可以完整走通：

```text
首页空状态
  -> 发布笔记
  -> 输入文字或添加媒体：相机 / 相册图片多选 / 相册视频单选 / 已选回显
  -> 发布成功回首页
  -> 打开笔记详情
  -> 喜欢帖子 / 喜欢评论 / 回复评论 / 删除自己的回复
  -> 返回首页
  -> 头像进入我的
  -> 打开 AI 好友 / 关于 GenkiSNS / UI 实验室
```

### 不进入 V1 主流程

- Onboarding / 创建资料 / 选择初始 AI 好友已移出 V1，放入 V2 首次设置。
- 评论生成中的 loading 状态暂不进入 V1 主流程。

---

## Phase 3.5 清理记录

- 设计板和 `?view=` 预览路由已隔离到 `apps/mobile/lib/design_preview/`。
- `apps/mobile/lib/main.dart` 只保留正式 app 入口、正式导航和发帖状态。
- V1 已移除 onboarding 代码；首次设置流程进入 V2。
- 已删除未使用的 `SectionLabel` 辅助组件。

---

## Phase 4c 前后端对齐

- 页面不直接读取 `apps/mobile/lib/mock/mock_data.dart`；Phase 5 改为读取 Repository/Service。
- `apps/mobile/lib/mock/mock_data.dart` 只保留为 Repository 初始化种子和设计预览数据。
- `Post.images` 使用 `PostImageRef` 兼容保存媒体来源、类型、排序和本地引用；图片通过本地文件路径回显，视频通过缩略图和详情页播放器回显，预览色只用于设计板和兜底占位。
- `Comment.actorColor` 是当前 UI 渲染字段；接数据层后来自 `actorAvatarColorSnapshot`。
- UI 实验室和 board preview 继续留在 `apps/mobile/lib/design_preview/` 与正式数据层隔离。
- Phase 5 已建立 `UserRepository`、`AiFriendRepository`、`PostRepository`、`InteractionService` 和 `ImagePickerService`。正式 app 入口不再自己拼装帖子和评论。

### 页面数据源

| 页面 | Phase 5 数据源 |
|------|----------------|
| 首页 | `PostRepository.listPosts()` |
| 发布笔记页 | `ImagePickerService`、`PostRepository.createPost()`、本地图片/视频文件 |
| 笔记详情页 | `PostRepository.getPost()`、喜欢/回复相关更新方法 |
| 我的页 | `UserRepository.getDefaultUser()`、`AiFriendRepository.listSelectedFriends()` |
| AI 好友页 | `AiFriendRepository.listSelectedFriends()` |
| 关于页 | 静态文案 |
| UI 实验室 | 设计预览数据 |

### Phase 4+ 验收方式

- Phase 4 起不再使用 `board.html` 或 `build/web` 作为验收入口。
- 设计板只保留为 Phase 3 的页面/状态归档。
- 正式验收使用 `flutter run` 运行到 iOS Simulator、Android Emulator 或真实移动设备。
- 如果没有可用设备，先解决设备环境，不用 Web 结果替代验收。

### Phase 5 本地数据层

- 正式 App 启动时打开 SQLite `genki_sns_v1.db` 并加载本机笔记。
- 发布笔记、帖子喜欢、评论喜欢、本地回复、删除回复和删除笔记都写回 SQLite。
- 系统相机和相册媒体会复制到 App 文档目录，数据库保存 `localRef`；视频额外保存 `thumbnailRef` 和 `durationMillis`。
- iOS 端变更后自动排队备份 SQLite 数据库和 `post_media/` 到 iCloud Drive 容器。
- iOS 端启动时如果本机数据库不存在，会尝试从 iCloud 备份恢复。
- iCloud 备份只解决卸载重装后的本机数据恢复，不处理多设备实时同步和冲突合并。
- 测试和设计预览可注入 `MemoryPostStore`，不影响正式 App 路径。
