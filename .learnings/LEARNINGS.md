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
