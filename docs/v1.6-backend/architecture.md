# GenkiSNS V1.6 审核与 LLM 后端架构

> 版本：v1.6
> 日期：2026-06-14
> 关联需求：[需求文档.md](需求文档.md)

## 一、边界

V1.6 后端只负责匿名安装身份、安装实例审核、内容安全审核、限流、预算保护、队列化 LLM 调用和结果校验。

后端不是笔记主数据库。用户笔记、媒体文件、喜欢状态、评论展示状态和本地回复继续保存在移动端 SQLite 与本地文件目录中。

## 二、组件

| 组件 | 位置 | 职责 |
|------|------|------|
| Flutter 客户端 | `apps/mobile/lib/data/services/llm_client.dart` | 生成并保存 `installation_id`，注册安装实例，提交互动生成任务，轮询结果 |
| 本地互动服务 | `apps/mobile/lib/data/services/interaction_service.dart` | 先生成本地模板互动，再在后台尝试真实 LLM 结果 |
| LLM 代理服务 | `services/llm-proxy/src/http.js` | 暴露 V1.6 API，串联审核、限流、预算和队列 |
| JSON Store | `services/llm-proxy/src/store.js` | 保存安装实例、审核状态、任务状态和每日用量 |
| Job Queue | `services/llm-proxy/src/queue.js` | 以固定并发处理任务，调用 LLM provider |
| Provider | `services/llm-proxy/src/llmProvider.js` | 支持 stub 和 OpenAI-compatible 供应商 |

## 三、发布流程

1. 移动端发布笔记时先写入本地 SQLite，并同步生成模板点赞和评论。
2. 如果配置了 `GENKI_API_BASE`，移动端在后台提交 `POST /v1/interactions/jobs`。
3. 后端检查安装实例状态、内容安全、安装实例频率、IP 频率、每日任务上限和每日预算。
4. 检查通过后创建 job 并入队，worker 调用 LLM provider。
5. 后端校验 LLM JSON：评论数量、角色 ID、字段长度和数值范围。
6. 移动端轮询 job，成功后用真实结果替换模板互动；失败、超时、受限或审核不通过时保留本地模板互动。

## 四、配置

移动端后端地址通过 Dart define 配置，便于当前使用 IP 地址，后续切换域名：

```sh
flutter run --dart-define=GENKI_API_BASE=http://<backend-ip>:8787
```

服务端模型供应商、密钥、端口、限流和预算均通过 `services/llm-proxy/.env.example` 中的环境变量配置。

## 五、降级策略

所有后端失败都不能阻塞发帖。后端在受限、审核不通过、预算超限、限流、任务失败或 LLM 结果非法时返回 fallback-friendly 状态；移动端保持本地模板互动作为最终可用结果。
