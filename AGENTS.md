# AGENTS.md

AR-assisted Capture The Flag app for Bsides Limburg. Coaches place printed QR codes flat on tables at stands. Participants scan them in an AR view, a flag object appears on top of the paper, and tapping it reveals the flag code or tells them to get it from the person at the stand. Scores go to CTFd.

Source of truth for decisions and their rationale: [documents/spec/001-technical-direction.md](documents/spec/001-technical-direction.md). Original brief: [documents/files/ITF-005 AR for CTF.md](documents/files/ITF-005%20AR%20for%20CTF.md). If a change contradicts the spec, stop and ask; if a decision changes, update the spec in the same change.

## Repository layout

```txt
code/
├── flutter/             Flutter app (package `ar_ctf`), native AR code lives in android/ (and later ios/)
├── api/                 FastAPI backend (BFF), managed with uv, Python >= 3.14
└── docker-compose.yml   API + PostgreSQL (CTFd will be hosted somewhere else)
documents/
├── spec/                Numbered specs: NNN-short-name.md
└── files/               Briefs and other project documents
justfile                 Root task runner, loads code/flutter and code/api as modules
```

## Commands

Run from the repo root. `just` lists everything.

| Task | Flutter | API |
| --- | --- | --- |
| Install deps | `just flutter get` | `just api sync` |
| Format | `just flutter fmt` | `just api fmt` |
| Lint / analyze | `just flutter analyze` | `just api lint` |
| Test | `just flutter test` | `just api test` |
| Run | `just flutter run [debug\|profile\|release]` | `just api dev` (reload) / `just api run` |
| Environment | `just flutter devices`, `just flutter doctor` | |

Each module also works on its own from its directory (`cd code/api && just dev`).

## Quality gate

All code must be formatted and pass linting before a change is done. No exceptions for generated-looking or "temporary" code.

- Flutter: `just flutter fmt`, `just flutter analyze` with zero issues (infos included), `just flutter test` green.
- API: `just api fmt`, `just api lint` with zero findings, type check clean, `just api test` green.
- Lint level is moderate:
  - Flutter: `flutter_lints` plus `strict-casts`, `strict-inference`, `strict-raw-types` and extra rules such as `prefer_const_constructors`, `always_declare_return_types`, `prefer_final_locals`.
  - Python: ruff rule sets `E`, `F`, `I`, `B`, `UP`, `SIM`, `ASYNC`, and basedpyright/pyright in standard mode.
- Do not silence findings (`// ignore:`, `# noqa`, `# type: ignore`) unless there is no reasonable fix; add a comment explaining why.
- Never edit generated files (`*.g.dart`, `*.freezed.dart`); regenerate them with `dart run build_runner build -d`.

## Stack

| Area | Decision |
| --- | --- |
| Mobile app | Flutter, Android first. iOS later (no Mac available; keep the code iOS-ready) |
| Architecture | MVVM with Riverpod, code generation style |
| AR anchoring | Printed QR code flat on the table; flag rendered on top of it |
| AR implementation | **Open**, to be settled by the first spike: native ARCore + ML Kit behind a platform channel, or `ar_flutter_plugin_2`. Do not add an AR plugin or native AR code without asking |
| Backend | FastAPI BFF with PostgreSQL |
| Scoring | CTFd behind a `ScoringAdapter`. Desirable, not mandatory |
| Coach tooling | In the mobile app under a coach role. No separate website |
| Hosting | Docker Compose, same stack locally, on an own server or in the cloud |

Not used, do not introduce: Unity, Vuforia, Firebase, Cloud Anchors / VPS, BLE beacons, a separate web admin, WebSockets for the scoreboard, a custom scoring engine.

## Architecture rules

### Flutter app

- Layers: View (widgets) → ViewModel (Riverpod notifiers) → Repository → data sources (REST client, local cache, `ArController`). Widgets never call data sources directly.
- Riverpod with code generation: `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `build_runner`. Use `@riverpod` annotations, not hand-written providers.
- AR is accessed only through the `ArController` interface (commands: `start`, `stop`, `spawnObject`, `clear`; event stream: `planeFound`, `qrDetected`, `anchorPlaced`, `objectTapped`, `trackingStateChanged`, `error`). Keep the contract platform-neutral so iOS is a second implementation, not a redesign.
- Native AR code contains no business logic, networking or persistence.
- A non-AR fallback (plain QR scan) shares the same ViewModels and backend. Treat it as a required feature.
- Offline tolerance: event data and AR data are fetched at join and cached. Scanning and rendering work offline. Only flag submission needs the network; it is queued and retried.
- Follow platform guidelines: Material 3 on Android, adaptive behaviour where iOS differs. Camera permission and "AR unsupported" are explicit flows.

### Backend

- The app talks only to the BFF. It never talks to CTFd directly.
- The BFF owns what CTFd does not model: events, flags/checkpoints, QR codes, AR presentation data, hints, roles.
- All CTFd access goes through one `ScoringAdapter` implementation. Other adapters must be addable without touching the app.
- The CTFd admin token stays server-side. It never appears in responses, logs or the app.
- Scoreboard: the BFF polls CTFd every 10-15 s and serves a cached result.
- Assume the event network is untrusted (TLS, authenticated endpoints).

### QR codes and anti-cheat

- QR payload is a signed identifier, e.g. `arctf://f/<flagId>?s=<signature>`. It never contains the flag code.
- Reject payloads with an invalid signature in both app and backend.
- In AR mode, the interact action is only enabled after the anchor is placed.
- Interaction type is a field on the flag (`reveal`, `ask_the_stand`, more later) so new types need no schema change.

## Conventions

- Language: English for code, comments, docs and commits.
- Commits: Conventional Commits with a scope, as in the existing history: `chore(flutter): …`, `feat(api): …`, `chore(just): …`, `spec(001): …`, `ci: …`. One logical change per commit.
- Specs: `documents/spec/NNN-short-name.md`, numbered in order. Do not leave open questions in a spec; put decisions in it.
- Secrets: `.env` files are gitignored; commit only `.env.example`.
- Dependencies: pin versions, and verify plugin APIs against the package source or docs before using them. Flutter AR plugins in particular are poorly documented and change between forks; do not rely on remembered APIs.
- Development happens on Linux (Debian). Do not add tooling that requires Windows or macOS.

## Working principles

### The Ponytail workflow (lazy senior dev mode)

Before writing any code, stop at the first rung that holds:

1. **YAGNI:** Does this need to be built at all?
2. **Reuse:** Does it already exist in this codebase? Reuse existing helpers and patterns.
3. **Stdlib first:** Does the Dart SDK, the Flutter framework, the Python standard library or FastAPI already do this? Use it.
4. **Native platform:** Does an Android/iOS platform feature cover it? Use it.
5. **Existing deps:** Does an already-installed dependency solve it? Use it.
6. **Simplicity:** Can this be one clean line? Make it one line.
7. **Minimal diff:** Only then write the minimum code that works.

Execution rules:

- **Maximize Material 3:** Never hand-roll custom widgets when a Flutter Material 3 widget exists (e.g. `FilledButton`, `TextFormField`, `Card`, `ListTile`, `AlertDialog`, `SnackBar`, `NavigationBar`, `Badge`). Use `ThemeData`/`ColorScheme` instead of hard-coded colours and styles.
- **Ban AI slop and tropes:** No decorative glowing gradients, fake security badges or invented marketing copy. Keep the UI clean, high-contrast and functional.
- **No unrequested abstractions:** No boilerplate, layers, base classes or provider wrappers nobody asked for. The layers in "Architecture rules" are the required ones; do not add more.
- **Deletion over addition:** Boring over clever. Fewest files possible.
- **Shortcuts and ceilings:** Mark intentional simplifications with a `ponytail:` comment naming the ceiling and the upgrade path.
- **Non-negotiables:** Never be lazy about input validation at trust boundaries, security, or error handling that prevents data loss.

### Comments and documentation

- **No redundant comments:** No inline comments that repeat the code (e.g. `count++; // increment count`).
- **If a comment doesn't answer "how?" or "why?", omit it.**
- **Allowed comments:**
  - Doc comments on public APIs: `///` dartdoc in Dart, docstrings in Python.
  - High-level `why:` / `how:` context explaining non-obvious constraints.
  - Actionable `todo:` comments describing future improvements or known rough edges.
  - `ponytail:` comments documenting intentional MVP simplifications.
- **Style:** Short comments in lowercase (`// why: …` in Dart and Kotlin, `# why: …` in Python). Capital letters only for multi-line contextual explanations.

### Functions and files

- **Single responsibility:** Functions, classes and widgets do one clear thing.
- **DRY:** Never duplicate logic; extract reusable widgets and utilities.
- **Clean code:** Zero dead code, unused imports or magic numbers (use named constants).
