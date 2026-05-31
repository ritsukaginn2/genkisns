# GenkiSNS V1 后端与数据架构

> 日期：2026-05-24
> 状态：Phase 5 已接入本地数据库、真实图片引用与 V1 视频发布
> 关联文档：[需求文档.md](需求文档.md)、[frontend_architecture.md](frontend_architecture.md)

---

## 一、架构目标

V1 只服务一个核心闭环：

```text
用户发布笔记 -> 生成 AI 点赞和评论 -> 用户在详情页获得回应感
```

因此 V1 的数据层需要支撑单人、本机持久化和 App 重启恢复；不做账号、云同步、跨设备和多用户关系。

---

## 二、存储策略

| 层 | V1 选择 | 原因 |
|----|---------|------|
| App 数据 | Repository + SQLite 本地数据库 | V1 需要本机持久化，发帖和互动状态不能只存在内存里 |
| 媒体 | 复制到 App 文档目录，SQLite 保存本地引用 | 首页和详情页需要在重启后继续回显图片或视频 |
| LLM 密钥 | V1 不接入真实 LLM 供应商 | 不需要在 App 内保存或展示供应商密钥 |
| 云端数据 | 不做 | V1 没有账号、同步和多设备需求 |

正式 App 使用 SQLite 实现 `PostStore`，测试和设计预览可以注入内存实现。所有页面只依赖 Repository/Service 接口，不直接依赖 mock data。

### 2.1 SQLite 表设计

| 表 | 保存内容 |
|----|----------|
| `posts` | 笔记正文、发布时间、喜欢数、用户喜欢状态、互动生成状态 |
| `post_images` | 媒体类型、来源、本地文件引用、视频缩略图、视频时长、展示顺序、预览色 |
| `comments` | AI 评论内容、AI 好友快照、评论喜欢数、用户喜欢状态 |
| `local_replies` | 用户本地二级回复、目标评论、回复对象快照 |

`PostRepository` 每次创建笔记、切换喜欢、回复或删除回复后，都把完整笔记聚合写回 `PostStore`。

---

## 三、核心模块

| 模块 | 职责 |
|------|------|
| `UserRepository` | 提供默认用户资料 |
| `AiFriendRepository` | 提供预设 AI 好友列表 |
| `PostRepository` | 创建、读取、更新笔记，并把变更写入 `PostStore` |
| `PostStore` | 定义笔记聚合的本地持久化接口 |
| `SqlitePostStore` | 保存笔记、图片/视频、评论、喜欢状态和本地回复 |
| `InteractionService` | 根据笔记内容和 AI 好友人设生成本地模板互动 |
| `ImagePickerService` | 处理拍照、拍视频、相册选择、已选媒体回显、本地文件复制和媒体引用生成 |

---

## 四、数据模型

### 4.1 UserProfile

| 字段 | 类型 | 说明 |
|------|------|------|
| `nickname` | `String` | 昵称 |
| `avatarInitial` | `String` | 头像文字 |
| `bio` | `String` | 个人简介 |
| `ipLocation` | `String` | 发布时自动识别的属地文案 |

### 4.2 AiFriend

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 稳定角色 ID |
| `name` | `String` | 角色名 |
| `avatarInitial` | `String` | 头像文字 |
| `relationship` | `String` | 与用户关系 |
| `personality` | `String` | 性格关键词 |
| `speakingStyle` | `String` | 说话风格 |
| `color` | `Color` | 当前 Flutter 头像颜色 |

### 4.3 Post

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 本地生成 |
| `text` | `String` | 笔记正文；可为空，但必须和媒体至少一项有内容 |
| `images` | `List<PostImageRef>` | 兼容字段：最多 9 张图片，或 1 个视频 |
| `createdAt` | `DateTime` | 发布时间 |
| `likeCount` | `int` | AI 生成点赞数 + 当前用户喜欢状态变化 |
| `comments` | `List<Comment>` | AI 评论和本地回复所属评论 |
| `userLiked` | `bool` | 当前用户是否点过喜欢 |
| `interactionStatus` | `success / fallback` | AI 互动生成状态 |

### 4.4 PostImageRef

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 本地生成 |
| `type` | `image / video` | 媒体类型 |
| `source` | `camera / album / preview` | 媒体来源 |
| `localRef` | `String` | 本次会话内媒体引用 |
| `thumbnailRef` | `String?` | 视频封面图本地引用 |
| `durationMillis` | `int?` | 视频时长 |
| `sortIndex` | `int` | 展示顺序 |
| `previewColor` | `Color?` | 当前 Flutter 占位预览色 |

### 4.5 Comment

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 本地生成 |
| `postId` | `String` | 所属笔记 |
| `actorId` | `String` | AI 好友 ID |
| `actorNameSnapshot` | `String` | 生成评论时的角色名快照 |
| `actorAvatarSnapshot` | `String` | 生成评论时的头像文字快照 |
| `actorColor` | `Color` | 生成评论时的头像颜色快照 |
| `content` | `String` | 评论内容 |
| `createdAt` | `DateTime` | 生成时间 |
| `likeCount` | `int` | 评论喜欢数 |
| `userLiked` | `bool` | 当前用户是否喜欢该评论 |
| `replies` | `List<LocalReply>` | 当前用户本地二级回复 |

### 4.6 LocalReply

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 本地生成 |
| `commentId` | `String` | 所属一级评论 |
| `authorNameSnapshot` | `String` | 回复作者名称快照 |
| `authorAvatarSnapshot` | `String` | 回复作者头像文字快照 |
| `targetActorNameSnapshot` | `String` | 被回复对象名称快照 |
| `content` | `String` | 回复内容 |
| `createdAt` | `DateTime` | 回复时间 |

---

## 五、AI 互动生成契约

V1 不接入云端 LLM。`InteractionService` 在本机根据笔记内容、媒体类型、图片数量、默认用户资料和 AI 好友人设生成点赞数与评论。生成失败时使用最小备用模板，不阻塞发帖。

### 请求

```json
{
  "post_id": "post_001",
  "text": "今天买到喜欢很久的小东西。",
  "media_type": "image",
  "image_count": 3,
  "user": {
    "nickname": "Ritsuka",
    "bio": "把真实 SNS 不方便发的快乐，先存在这里。"
  },
  "friends": [
    {
      "id": "friend_mika",
      "name": "美香",
      "relationship": "高中同学",
      "personality": "会夸、爱起哄",
      "speaking_style": "像很熟的老朋友，句子短，反应快。"
    }
  ]
}
```

### 响应

```json
{
  "ai_like_count": 18,
  "comments": [
    {
      "actor_id": "friend_mika",
      "content": "这个颜色太适合你了",
      "delay_seconds": 6,
      "like_count": 2
    }
  ]
}
```

### 失败处理

- 评论生成异常时，帖子仍发布成功。
- 业务层使用备用模板生成至少 1 条评论。
- `interactionStatus` 记录为 `fallback`，但 V1 不需要在 UI 中展示错误。

---

## 六、前端对齐

| 页面 | 数据来源 |
|------|----------|
| 首页 | `PostRepository.listPosts()` |
| 发布笔记页 | `ImagePickerService`、`PostRepository.createPost()` |
| 笔记详情页 | `PostRepository.getPost()`、`PostRepository.togglePostLike()`、`PostRepository.toggleCommentLike()`、`PostRepository.addLocalReply()`、`PostRepository.deleteLocalReply()` |
| 我的页 | `UserRepository.getDefaultUser()`、`AiFriendRepository.listSelectedFriends()` |
| AI 好友页 | `AiFriendRepository.listSelectedFriends()` |
| 关于页 | 静态文案 |
| UI 实验室 | 设计预览数据，不进入正式数据层 |

Phase 4 起，前后端对齐验收必须通过 `flutter run` 在模拟器或真实设备中完成。`board.html` 和 `build/web` 只作为设计归档或开发调试，不作为实现验收入口。

---

## 七、实现顺序

1. 建立 Repository/Service 接口。（已完成）
2. 把 `apps/mobile/lib/mock/mock_data.dart` 从页面直连改为 Repository 初始化数据。（已完成）
3. 实现 `PostRepository` 写穿 `PostStore`。（已完成）
4. 接入 SQLite 本地数据库，支持 App 重启恢复。（已完成）
5. 实现发布笔记后调用 `InteractionService`。（已完成）
6. 实现本地模板互动和 fallback。（已完成）
7. 建立拍照、拍视频、App 内相册选择、已选回显、本地文件复制和媒体引用模型。（已完成）
8. 用 `flutter run` 在模拟器或真实设备中回归验证。（本阶段必做）
