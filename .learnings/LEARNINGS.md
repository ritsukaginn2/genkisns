## [LRN-20260524-001] correction

**Logged**: 2026-05-24T20:12:00+08:00
**Priority**: medium
**Status**: pending
**Area**: frontend

### Summary
Phase 4+ mobile app acceptance should use `flutter run` on a simulator or real device, not the web/HTML design board.

### Details
The mobile app design workflow should treat HTML/Flutter Web boards as Phase 1.5-3 design surfaces. After Phase 3.5 cleanup, Phase 4 requirements and architecture sign-off must move to the runnable Flutter app through `flutter run`. Web boards can remain as an archive or scenario inventory, but should not be used as Phase 4+ acceptance.

### Suggested Action
Keep project acceptance docs and future implementation checks centered on native Flutter runtime. If no simulator or real device is available, document that as a blocker instead of falling back to web.

### Metadata
- Source: user_feedback
- Related Files: /Users/ritsukaginn/.claude/skills/mobile-app-design/SKILL.md, docs/v1-mvp/前端Mock验收清单.md
- Tags: mobile-app-design, flutter-run, phase4

---

## [LRN-20260524-003] correction

**Logged**: 2026-05-24T21:51:09+08:00
**Priority**: high
**Status**: pending
**Area**: backend

### Summary
V1 mobile acceptance is not closed unless user-created posts, media references, likes, comments, and local replies persist across app restarts.

### Details
Treating V1 data as session-only was a backend design miss for GenkiSNS. Even before cloud sync or real LLM integration, the single-user app needs a local database layer so publishing and interaction behavior can be accepted in native Flutter.

### Suggested Action
Keep a local persistence contract in the V1 architecture: Repository APIs write through a store, production uses SQLite on device, tests can inject memory/FFI stores, and docs must distinguish local persistence from later cloud sync.

### Metadata
- Source: user_feedback
- Related Files: docs/v1-mvp/backend_architecture.md, docs/v1-mvp/需求文档.md, lib/data/stores/post_store.dart
- Tags: v1, local-db, flutter, acceptance

---

## [LRN-20260524-002] best_practice

**Logged**: 2026-05-24T21:25:00+08:00
**Priority**: medium
**Status**: pending
**Area**: frontend

### Summary
For Flutter apps with mutable root state, prefer `MaterialApp.home` or an update-aware router over an `onGenerateRoute` closure that captures the initial home widget.

### Details
In GenkiSNS, the publish flow wrote a new post into `PostRepository`, but the root route was built through `onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => home)`. That captured the initial empty `GenkiShell`, so popping back from the publish page showed stale posts even though the repository had data.

### Suggested Action
When the root screen must reflect session state changes, let `MaterialApp` rebuild the root child directly or use a router/state pattern that updates the active route. Add a widget flow test that publishes content and expects it on the home screen.

### Metadata
- Source: error
- Related Files: lib/main.dart, test/widget_test.dart
- Tags: flutter, routing, state-refresh
- Pattern-Key: flutter.root_route_state_refresh

---
