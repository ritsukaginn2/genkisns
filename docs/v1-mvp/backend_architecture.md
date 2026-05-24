# GenkiSNS V1 后端与数据架构

> 日期：2026-05-24
> 状态：Phase 4 初版
> 关联文档：[需求文档.md](需求文档.md)、[frontend_architecture.md](frontend_architecture.md)

---

## 一、架构目标

V1 只服务一个核心闭环：

```text
用户发布笔记 -> 生成 AI 点赞和评论 -> 用户在详情页获得回应感
```

因此 V1 的数据层只需要支撑单人、单次 App 会话，不做账号、云同步、跨设备、多用户关系和重启恢复。

---

## 二、存储策略

| 层 | V1 选择 | 原因 |
|----|---------|------|
| App 数据 | 会话内本地 Repository | V1 验证体验闭环，不先引入数据库复杂度 |
| 图片 | 会话内图片引用 | V1 只需要发布页和详情页可展示本次选择的图片 |
| LLM 密钥 | 不进入 App | 避免把供应商密钥放进客户端 |
| 云端数据 | 不做 | V1 没有账号、同步和多设备需求 |

V1 可以先用内存实现 Repository。所有页面只依赖 Repository/Service 接口，不直接依赖 mock data。这样 Phase 5 替换 mock 时不需要重写 UI。

---

## 三、核心模块

| 模块 | 职责 |
|------|------|
| `UserRepository` | 提供默认用户资料 |
| `AiFriendRepository` | 提供预设 AI 好友列表 |
| `PostRepository` | 创建、读取、更新本次会话内的笔记 |
| `InteractionService` | 根据笔记内容请求 AI 互动，失败时返回备用模板 |
| `ImagePickerService` | 处理拍照、相册多选、已选图片回显 |

---

## 四、数据模型

### 4.1 UserProfile

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | V1 固定默认用户 |
| `nickname` | `String` | 昵称 |
| `avatarInitial` | `String` | 头像文字 |
| `avatarColor` | `Color/String` | 头像颜色 token 或色值 |
| `bio` | `String` | 个人简介 |
| `ipLocation` | `String` | 发布时自动识别的属地文案 |

### 4.2 AiFriend

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 稳定角色 ID |
| `name` | `String` | 角色名 |
| `avatarInitial` | `String` | 头像文字 |
| `avatarColor` | `Color/String` | 头像颜色 token 或色值 |
| `relationship` | `String` | 与用户关系 |
| `personality` | `String` | 性格关键词 |
| `speakingStyle` | `String` | 说话风格 |

### 4.3 Post

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 本地生成 |
| `authorUserId` | `String` | V1 固定为默认用户 |
| `text` | `String` | 笔记正文；可为空，但必须和 `images` 至少一项有内容 |
| `images` | `List<PostImage>` | 最多 9 张 |
| `createdAt` | `DateTime` | 发布时间 |
| `ipLocationSnapshot` | `String` | 发布时属地快照 |
| `aiLikeCount` | `int` | AI 生成的点赞数 |
| `userLiked` | `bool` | 当前用户是否点过喜欢 |
| `llmStatus` | `pending / success / fallback` | AI 互动生成状态 |

### 4.4 PostImage

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 本地生成 |
| `postId` | `String` | 所属笔记 |
| `source` | `camera / album` | 图片来源 |
| `localRef` | `String` | 本次会话内图片引用 |
| `sortIndex` | `int` | 展示顺序 |

### 4.5 Comment

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 本地生成或 LLM 返回后补齐 |
| `postId` | `String` | 所属笔记 |
| `actorId` | `String` | AI 好友 ID |
| `actorNameSnapshot` | `String` | 生成评论时的角色名快照 |
| `actorAvatarSnapshot` | `String` | 生成评论时的头像文字快照 |
| `actorAvatarColorSnapshot` | `Color/String` | 生成评论时的头像颜色快照 |
| `content` | `String` | 评论内容 |
| `createdAt` | `DateTime` | 生成时间 |
| `deliveredAt` | `DateTime` | 展示到评论区的时间 |
| `likeCount` | `int` | 评论喜欢数 |
| `userLiked` | `bool` | 当前用户是否喜欢该评论 |

### 4.6 LocalReply

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `String` | 本地生成 |
| `commentId` | `String` | 所属一级评论 |
| `authorUserId` | `String` | V1 固定为默认用户 |
| `targetActorNameSnapshot` | `String` | 被回复对象名称快照 |
| `content` | `String` | 回复内容 |
| `createdAt` | `DateTime` | 回复时间 |

---

## 五、LLM 交互契约

App 不直接保存 LLM 密钥。V1 通过开发者预配置的 OpenAI 兼容接口或代理服务生成互动。

### 请求

```json
{
  "post_id": "post_001",
  "text": "今天买到喜欢很久的小东西。",
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

- 请求失败、超时、JSON 不合法、角色 ID 不存在时，帖子仍发布成功。
- 业务层使用备用模板生成至少 1 条评论。
- `llmStatus` 记录为 `fallback`，但 V1 不需要在 UI 中展示错误。

---

## 六、前端对齐

| 页面 | 数据来源 |
|------|----------|
| 首页 | `PostRepository.listPosts()` |
| 发布笔记页 | `ImagePickerService`、`PostRepository.createPost()` |
| 笔记详情页 | `PostRepository.getPost()`、`PostRepository.updatePostLike()`、`PostRepository.updateCommentLike()`、`PostRepository.addLocalReply()`、`PostRepository.deleteLocalReply()` |
| 我的页 | `UserRepository.getDefaultUser()`、`AiFriendRepository.listSelectedFriends()` |
| AI 好友页 | `AiFriendRepository.listSelectedFriends()` |
| 关于页 | 静态文案 |
| UI 实验室 | 设计预览数据，不进入正式数据层 |

Phase 4 起，前后端对齐验收必须通过 `flutter run` 在模拟器或真实设备中完成。`board.html` 和 `build/web` 只作为设计归档或开发调试，不作为实现验收入口。

---

## 七、实现顺序

1. 建立 Repository/Service 接口。
2. 把 `mock/mock_data.dart` 从页面直连改为 Repository 初始化数据。
3. 实现会话内 `PostRepository`。
4. 实现发布笔记后调用 `InteractionService`。
5. 接入 LLM 结构化返回和 fallback。
6. 把图片颜色 mock 替换为真实图片引用。
7. 用现有设计板和正式 mock app 路径回归验证。
