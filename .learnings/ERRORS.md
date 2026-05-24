## [ERR-20260509-001] webapp-testing-python-command

**Logged**: 2026-05-09T00:00:00+08:00
**Priority**: low
**Status**: pending
**Area**: tests

### Summary
The webapp-testing helper docs used `python`, but this environment only had `python3`.

### Error
```text
zsh:1: command not found: python
```

### Context
- Attempted to run `/Users/ritsukaginn/.claude/skills/webapp-testing/scripts/with_server.py --help`.
- The workspace shell is zsh on macOS.

### Suggested Fix
Use `python3` for local Playwright/helper script commands in this environment.

### Metadata
- Reproducible: yes
- Related Files: /Users/ritsukaginn/.claude/skills/webapp-testing/SKILL.md

---

## [ERR-20260524-001] shell-command-substitution-in-rg

**Logged**: 2026-05-24T20:15:00+08:00
**Priority**: low
**Status**: pending
**Area**: tests

### Summary
An `rg` command used backticks inside a double-quoted search pattern, causing the shell to execute `flutter run` by command substitution.

### Error
```text
rg -n "Review Surface Handoff|Phase 4 onward|Verify with `flutter run`|..."
```

### Context
- The accidental command launched a resident `flutter run` process.
- The process had to be killed manually, which produced a broken-pipe stack trace.

### Suggested Fix
When searching for literal text that includes backticks, wrap the pattern in single quotes or escape the backticks.

### Metadata
- Reproducible: yes
- Related Files: /Users/ritsukaginn/.claude/skills/mobile-app-design/SKILL.md

---

## [ERR-20260510-002] background-http-server-exited

**Logged**: 2026-05-10T00:00:00+08:00
**Priority**: low
**Status**: pending
**Area**: frontend

### Summary
Starting `python3 -m http.server` with `nohup ... &` briefly showed a listener, but the server exited before `curl` could connect.

### Error
```text
curl: (7) Failed to connect to localhost port 8095 after 0 ms: Couldn't connect to server
```

### Context
- Attempted to restart the GenkiSNS prototype preview on port 8095.
- `lsof` showed the listener immediately after start, but a follow-up `curl -I` failed and the log file was empty.

### Suggested Fix
For preview servers that need to survive after the command returns, start the server with `subprocess.Popen(..., start_new_session=True)` and redirect stdout/stderr to a log file. Plain backgrounding or a non-detached `Popen` can exit before browser verification.

### Metadata
- Reproducible: unknown
- Related Files: docs/v1-mvp/prototype/designs.html

---

## [ERR-20260510-001] flutter-build-web-hang

**Logged**: 2026-05-10T00:00:00+08:00
**Priority**: medium
**Status**: pending
**Area**: frontend

### Summary
`flutter build web --base-href /build/web/ --no-wasm-dry-run` hung in dart2js for several minutes and had to be killed.

### Error
```text
Target dart2js failed: ProcessException: Process exited abnormally with exit code -15
Compiling lib/main.dart for the Web... 168.6s
Error: Failed to compile application for the Web.
```

### Context
- Command was run after updating `lib/pages/design_directions_page.dart`.
- `flutter analyze` passed before the build.
- The failure was caused by manually killing the hung dart2js process, not by a Dart compile error.

### Suggested Fix
Use debug web build or `flutter run -d web-server` for fast UI preview, and retry release build separately after clearing `.dart_tool` if needed.

### Metadata
- Reproducible: unknown
- Related Files: lib/pages/design_directions_page.dart

---

## [ERR-20260510-003] flutter-web-networkidle-timeout

**Logged**: 2026-05-10T00:00:00+08:00
**Priority**: low
**Status**: pending
**Area**: tests

### Summary
Playwright `page.goto(..., wait_until='networkidle')` timed out against the Flutter debug web build even though the app was reachable and rendered.

### Error
```text
Page.goto: Timeout 30000ms exceeded while waiting for networkidle
```

### Context
- The app returned HTTP 200 and later rendered successfully.
- A follow-up check using `wait_until='domcontentloaded'` plus `wait_for_selector('flutter-view, flt-glass-pane')` passed.

### Suggested Fix
For Flutter debug web smoke tests, prefer `domcontentloaded` plus waiting for the Flutter root element instead of relying on `networkidle`.

### Metadata
- Reproducible: unknown
- Related Files: build/web/index.html

---

## [ERR-20260513-001] playwright-framelocator-api-misuse

**Logged**: 2026-05-13T00:00:00+08:00
**Priority**: low
**Status**: pending
**Area**: tests

### Summary
Tried to call `wait_for_selector` on a Playwright `FrameLocator`, which is not supported by the Python sync API.

### Error
```text
AttributeError: 'FrameLocator' object has no attribute 'wait_for_selector'
```

### Context
- Occurred while checking `docs/v1-mvp/prototype/board.html` iframe content.
- The iframe needed to be converted to a real `Frame` first.

### Suggested Fix
Use `locator(...).element_handle().content_frame()` before calling frame methods like `wait_for_selector`.

### Metadata
- Reproducible: yes
- Related Files: docs/v1-mvp/prototype/board.html

---

## [ERR-20260509-002] product-design-misalignment

**Logged**: 2026-05-09T00:00:00+08:00
**Priority**: high
**Status**: pending
**Area**: frontend

### Summary
The GenkiSNS design directions were too concept-art oriented and did not sufficiently respect that the product is an SNS.

### Error
```text
User feedback: "你这几套设计更加丑。 你先搞清楚这个产品是什么产品。 这是一个sns产品。"
```

### Context
- The design directions page was rewritten into five visual concepts such as magazine, sticker, luxury, glass dashboard, and film archive.
- These directions over-emphasized visual mood and under-emphasized SNS product structure: feed, post cards, author identity, engagement actions, comments, publish entry, profile, and navigation.

### Suggested Fix
Future GenkiSNS UI directions should start from recognizable SNS screens and interaction patterns, then vary brand tone within that product frame. Each direction should include a real feed card, publish affordance, bottom navigation, engagement row, and comment preview.

### Metadata
- Reproducible: yes
- Related Files: lib/pages/design_directions_page.dart

---
