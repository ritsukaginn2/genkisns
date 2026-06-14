# GenkiSNS Repo Structure

> 日期：2026-05-25

---

## 目录

```text
apps/
  mobile/          Flutter iOS / Android App
services/
  llm-proxy/       V1.6 审核与 LLM 调用后端
docs/              产品、设计、架构、验收文档
```

---

## 移动端命令

所有 Flutter 命令都在 `apps/mobile` 下执行：

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
```

---

## 后端命令

```bash
cd services/llm-proxy
npm test
npm start
```

V1.6 后端职责：

- 用户/安装实例审核与风控状态。
- 发帖内容进入 LLM 前的安全审核。
- 队列化调用 LLM，并把真实 provider API key 放在服务端。
- 限流、预算保护、日志和可 fallback 的错误返回。
- 不保存 V1 用户笔记、图片、喜欢状态和本地回复的主数据。

---

## 边界

- Flutter App 不保存真实 LLM provider API key。
- `services/llm-proxy` 是 V1.6 后端代码与环境变量模板的归属目录。
- `docs/v1-mvp/prototype/board.html` 只保留为设计归档。
