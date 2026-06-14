# GenkiSNS V1.6 实现计划与验收记录

> 日期：2026-06-14
> 状态：已完成

## 一、实现顺序

1. 后端 API：实现安装实例注册、安装实例状态查询、互动生成任务创建、任务结果查询和内部状态更新接口。
2. 审核与风控：实现 `allowed / limited / blocked` 状态、文本 blocklist 审核、请求体大小限制、单安装实例限流、单 IP 限流、每日任务上限和每日预算保护。
3. 队列与 LLM：实现固定并发 job queue、stub provider、OpenAI-compatible provider、超时处理和结构化结果校验。
4. 移动端接入：发布后先写本地模板互动，再后台提交 job，轮询成功后替换为真实互动。
5. 配置与文档：移动端通过 `GENKI_API_BASE` 指向 IP 或域名，后端通过环境变量配置模型供应商和保护阈值。
6. 回归：运行后端 API 测试和 Flutter 测试。

## 二、当前验收点

| 验收项 | 状态 |
|--------|------|
| 注册或刷新 `installation_id` | 已实现 |
| 返回安装实例审核状态 | 已实现 |
| blocked / limited 安装实例 fallback | 已实现 |
| 内容安全审核在 LLM 前执行 | 已实现 |
| Queue-first LLM 调用 | 已实现 |
| 轮询任务结果 | 已实现 |
| 成功 LLM 结果写回本地 SQLite | 已实现 |
| LLM JSON 结构校验 | 已实现 |
| LLM 结果非法时 fallback | 已实现 |
| 单安装实例限流 | 已实现 |
| 单 IP 限流 | 已实现 |
| 每日任务与预算保护 | 已实现 |
| App 内不保存供应商密钥 | 已实现 |
| 不上传图片和视频文件 | 已实现 |

## 三、暂不进入 V1.6 的内容

- 手机号、邮箱、Apple 登录、Google 登录。
- 完整管理后台。
- 订阅、付费额度、购买验证。
- 服务端笔记主数据、服务端媒体存储、账号级云同步。

## 四、2026-06-14 继续验收记录

- 修复移动端 `LLMClient` 安装 ID 空安全编译问题。
- 补齐 `post_repository_test.dart` 的 LLM 客户端测试依赖导入，覆盖后台 LLM 结果替换时保留本地评论点赞与回复。
- 补齐 SQLite 持久化回归测试，覆盖后台 LLM 成功结果写回本地数据库。
- 为后端 `JobQueue` 增加 `onIdle()`，测试清理前等待队列写入完成，避免并发预算测试在临时目录清理时出现竞态。
- 补齐后端回归测试，覆盖 `limited` 安装实例、IP 限流和非法 LLM 结果 fallback。

已通过：

```sh
cd services/llm-proxy && npm test
cd apps/mobile && flutter test
cd apps/mobile && flutter analyze
```

## 五、完成结论

V1.6 范围已完成。当前交付物包括：

- Flutter 端可配置后端地址、匿名安装 ID、本地优先发布、后台 LLM job 提交与轮询。
- 后端匿名安装实例注册、审核状态维护、内容安全审核、限流、预算保护、队列化 LLM 调用和结果校验。
- Stub provider 支持无密钥本地验收；OpenAI-compatible provider 支持真实托管模型接入。
- fallback-friendly 响应覆盖 blocked、limited、内容审核不通过、限流、预算超限、任务失败和非法 LLM 结果。
- 文档和 README 已说明本地运行、真实 provider 配置、移动端接入和内部审核状态更新方式。
