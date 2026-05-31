# GenkiSNS Repo Structure

> 日期：2026-05-25

---

## 目录

```text
apps/
  mobile/          Flutter iOS / Android App
services/
  llm-proxy/       V1.6 LLM 代理后端
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

后端命令都在 `services/llm-proxy` 下执行。V1.6 后端只负责权益、额度、队列和安全调用 LLM，不负责保存用户笔记。

```bash
cd services/llm-proxy
```

---

## 边界

- Flutter App 不保存真实 LLM provider API key。
- `services/llm-proxy` 保存后端代码和后端环境变量模板。
- `docs/v1-mvp/prototype/board.html` 只保留为设计归档。
