# SPEC-001: Technical Direction

Status: draft, based on the initial exploration. Source brief: [ITF-005 AR for CTF](../files/ITF-005%20AR%20for%20CTF.md).

The AR approach (3.1) and the presentation (5.4) are the team's recommendation, pending the first client meeting on 2026-12-07. The options in 3.7 are presented there, together with a marker-AR spike. Everything behind the detection boundary (3.4) and the API are independent of that choice and are built first.

## 1. Context

An AR-assisted Capture The Flag for Bsides Limburg. The main goal is to make participants engage with the booths. The event is **indoors**.

### 1.1 Flow

1. A participant has the app installed and walks to a booth.
2. The booth has a printed QR code. The participant points the camera at it.
3. If the code is valid for the event, a flag appears on the QR code.
4. The participant taps the flag and a question is shown.
5. The participant talks to the people at the booth, who tell them the answer.
6. The participant types the answer into the app. If it is correct, the API returns the CTFd flag.
7. The participant submits that flag on the CTFd platform themselves.

The app has no link with CTFd. CTFd handles accounts, teams, scoring and the scoreboard on its own.

The solution should be reusable for other events and venues.

### 1.2 Team and constraints

- 2 people, part-time, roughly 3 months.
- Priority: it works reliably on event day.
- Not graded; something usable has to be delivered.
- Learning goals to cover: AR in a cross-platform app, exploring AR technologies, a structured design pattern (MVVM), platform-specific guidelines.
- Development is Linux-based. iOS builds need a Mac. This is out of scope for now.
- The product must not be Android-only in practice. Code that only one platform can run must be kept to a minimum, because iOS cannot be tested by the team.

## 2. Decisions

| Area | Decision |
| --- | --- |
| Mobile app | Flutter, Android first, iOS later |
| Architecture | MVVM with Riverpod & go-router |
| Detection boundary | A `BoothDetector` interface emits booth sightings with an optional pose (3.4). AR approaches are implementations behind it |
| AR approach | Recommendation, pending client: marker-based AR. The printed QR code is the marker; the flag is rendered on top of it while it is in view |
| AR implementation | Recommendation, pending client: AR without an AR SDK, entirely in Dart. `mobile_scanner` (ML Kit on Android, Vision on iOS) for QR payload and corner points, placement on the code from a homography (no 3D pose, see 3.1), rendering with Flutter widgets, `Transform` and `CustomPainter`. No custom native code |
| QR payload | Random scan token per booth; the app caches only its hash (3.2) |
| Answer check | In the API: normalisation plus fuzzy matching against accepted answers (4.2). If needed with an AI model |
| Flags | Stored only on the server; returned by the API after a correct answer |
| Participants | Anonymous. The app generates a random device ID on first launch |
| Rate limit | 3 answer attempts per minute per device ID, across all booths (4.3) |
| Scoring | CTFd, not integrated. Participants submit flags on CTFd themselves |
| Backend | Go API on `net/http` with PostgreSQL |
| Database access | `sqlc` (queries in SQL, generated type-safe Go) on `pgx/v5`; migrations with `goose` (4.6) |
| Coach tooling | In the mobile app, coach role. No separate website |
| QR generation | API endpoint producing a printable PDF sheet, triggered from the coach app |
| Hosting | Docker Compose (API + PostgreSQL) on a device at the venue |

## 3. AR approach

### 3.1 Recommended: marker-based AR

Pending the client meeting (see 3.7 for the alternatives). The flag is anchored to the QR code itself, as in classic marker-based AR. It exists only while the code is in view; when the code leaves the frame, the flag disappears. This is intended behaviour.

1. `mobile_scanner` runs the camera preview and decodes QR codes on every frame (`DetectionSpeed.unrestricted`, QR format only). Each detection returns the payload and four corner points in camera-image coordinates.
2. The corners are mapped to screen coordinates. The preview is drawn with `BoxFit.cover`, so the mapping is a uniform scale of `max(viewW / imgW, viewH / imgH)` plus a centring offset. `Barcode.scaleCorners` stretches both axes independently and is not used for this.
3. Corners are smoothed per corner (One Euro filter; an exponential moving average is acceptable as a first version).
4. Tracking state uses hysteresis: a marker counts as tracked after 3 consecutive detections and as lost after about 250 ms without one, after which the flag fades out. This prevents flicker from missed frames and flashes from false detections.
5. The four corners and the known square of the code give a homography from the unit square to the screen. It gives the code's centre (the image of the square's centre, which stays correct under perspective) and its size on screen (the square root of the outline's area).
6. The presentation (5.4) is rendered on top of the camera preview in two parts: a shadow lying flat on the paper, mapped with the homography (embedded in a `Matrix4` on a `Transform`), and the presentation standing upright on the screen with its foot on the code's centre, scaled with the code's size. The first presentation is a flag (`Icons.flag` until there is artwork).
7. A tap on the standing presentation opens the question (5.3).

No 3D pose is estimated. Participants look at the code from above, and from above an object standing perpendicular to the paper points at the camera and is seen end-on, so a pose adds nothing visible. A pose decomposition was tried (Zhang's method with a focal length from an estimated 70° field of view): with real corners it lost the tilt and kept pointing the normal at the camera, because it reads tilt only from perspective, which is weak at arm's length. Upright on the screen looks the same on a table and on a wall, and needs no camera calibration.

While the phone moves, the flag trails slightly behind the code and settles once the phone is held still. This is accepted. The preview is shown live, while ML Kit reports corners for a frame that is already a little older, and the two streams cannot be synchronised without native camera code. Predicting the corners ahead was rejected: it overshoots when the phone stops and makes jitter worse. The lag does not affect use, because the question only opens while the code is tracked and stable. If the standing flag trails visibly, prediction can be tried for its position only.

Several codes can be in view at once. Each is tracked and rendered independently; the tap decides which booth is used.

This works indoors, needs no venue scanning or cloud service, runs on every phone with a camera, and keeps all AR logic in Dart so that iOS needs no second implementation.

### 3.2 QR payload and print

- The payload is `arctf://b/<token>`: a random 128-bit scan token per booth, base64url-encoded.
- The token is the proof that the participant saw the printed code. It is not stored on the device; it is only sent to the API with an answer.
- The event data the app caches maps `SHA-256(token)` to the booth (question, presentation). A scanned code is valid when its hash is in the cache; this works offline. Codes from other events or unrelated QR codes are ignored.
- The payload never contains the question's answer or the flag.
- A short payload with low error correction gives fewer, larger modules, which improves detection distance and corner stability.
- The code is printed at least 10 cm wide on matte paper. No glossy lamination: venue lighting causes glare that breaks detection.
- One app build serves every event; booths are data, not bundled assets.

### 3.3 Anti-cheat

- The barrier is the conversation at the booth: the answer comes from the booth staff, and the flag only from the API after a correct answer.
- When the detector provides a pose, the question can only be opened while the code is tracked and stable (see 3.1, step 4).
- A photographed QR code shows the question, not the answer. This is accepted.
- A CTFd flag is the same for every participant and can be shared after it is obtained. The app cannot prevent this; it is accepted.

### 3.4 Detection boundary

The boundary sits at the domain level, not at the QR level, so that every option in 3.7 fits behind it. An image-tracking detector has no QR payload, and a world-tracking plugin owns the camera, so a boundary that exposes QR payloads or corners would not survive those choices.

```txt
BoothDetector     commands: start, stop
                  events (stream): sighted(BoothSighting), lost(boothRef), error(code)
BoothSighting     boothRef (valid for the cached event), scan token, pose (optional)
```

- Each implementation turns its own input into a valid `boothRef`: a QR detector hashes the token and looks it up in the cache, an image-tracking detector maps the image name to a booth.
- Payload parsing and token lookup are shared pure Dart functions with unit tests.
- ViewModels depend only on `BoothDetector`. They must work without a pose; the pose only adds the AR overlay and the check in 3.3.
- The first implementation is `mobile_scanner` without a pose (plain QR scan). It is independent of the AR choice and is built before the client meeting. The marker-AR implementation adds corners and pose on the same source.
- Implementations are swapped with a Riverpod provider override; tests use a fake.
- For marker AR, the pose maths and the smoothing filters are pure functions with unit tests.

### 3.5 Device support

With marker-based AR, any phone with a camera supports the AR view. With an approach that needs ARCore/ARKit (3.7), unsupported phones use the pose-less QR detector, which already exists. Camera permission denied and no camera available are explicit flows.

### 3.6 Alternatives evaluated and rejected

| Option | Why not |
| --- | --- |
| GPS / wifi positioning | 10-50 m accuracy indoors; cannot distinguish booths |
| BLE beacons | Extra hardware per booth and venue; crowds degrade signal; positions but cannot anchor AR content |
| Wifi RTT, UWB, BLE AoA | Phone support is partial or absent, or needs venue infrastructure |
| ARCore Geospatial | Based on Street View; effectively outdoor only |
| ARCore Cloud Anchors | Depends on the venue looking the same between setup and event; flaky resolution risk; Flutter plugin support is stale |
| Full VPS (Niantic Spatial VPS 2.0, Immersal, MultiSet) | Requires scanning the entire venue in its final state, vendor cloud dependency; no conference precedent found |
| ARKit ARWorldMap | iOS only; sensitive to lighting changes; size limits |
| Own native ARCore + ML Kit layer behind a platform channel | iOS needs a second implementation in Swift that the team cannot build or test without a Mac; the product would be Android-only in practice |
| `ar_flutter_plugin` | Last release 4 years ago, Sceneform-based, no image tracking |
| `ar_flutter_plugin_2` | Unmaintained since March 2025; Dart SDK constraint `<3.0.0` does not resolve on current Flutter; no 16 KB page-size support; `onNodeTap` broken. Forking it costs more than writing a native layer |
| Flutter + Unity (AR Foundation) | Extra toolchain and dependency, blurs MVVM; iOS export still needs Xcode on macOS or Unity Build Automation, so it does not solve iOS testability |
| Flutter + Unity + Vuforia (`flutter_embed_unity`, as used in the ITF mobile development course) | VuMarks (ID-encoding markers that are also 6DoF targets, free on the Basic licence) fit technically. Rejected: Vuforia officially supports only Windows for Unity development while the team works on Linux (Debian); the course setup pins exact Unity/Flutter/NDK versions with a fragile export pipeline; Vuforia's QR Barcode Scanner is a Premium feature. The learning goals do not require Vuforia or Unity |
| Web AR (MindAR, AR.js, WebXR) as the product | The learning goals require a cross-platform mobile app; WebXR AR is not available in iOS Safari; it would split the codebase |
| HMAC-signed QR payload | The key must be on the device to verify offline, so whoever extracts it can generate codes. A random token with only its hash cached gives the same offline check with no secret on the device |

### 3.7 Options for the client meeting

Presented to the client as experiences, not as techniques. All three fit behind `BoothDetector`.

| Experience | Technique | Trade-offs |
| --- | --- | --- |
| A flag appears on the booth's sheet while the code is in view; tap it (recommended) | Marker-based AR, entirely in Dart (3.1) | Works on every phone with a camera; same code on Android and iOS; lowest risk. The object disappears when the code leaves the frame |
| The object stays in the room; walk around it | World tracking with `ar_flutter_plugin_plus` | More impressive. ARCore/ARKit phones only. Android (ARCore + Filament) and iOS (ARKit + SceneKit) are separate implementations with different renderers, so Android testing says little about iOS. No camera-frame access: QR detection needs snapshots plus a user tap to place the object |
| The booth's own artwork comes to life | Image tracking with `ar_flutter_plugin_plus` | Sponsor branding as the trigger. Needs distinctive artwork per booth. Open flashing bug in continuous tracking; image width hard-coded to 20 cm |

A marker-AR spike is demonstrated at the meeting.

## 4. System architecture

```txt
┌──────────────────────────┐
│ Flutter app              │
│  Participant / Coach UI  │
│  MVVM + Riverpod         │
│  BoothDetector ◄── mobile_scanner (ML Kit / Vision)
└────────────┬─────────────┘
             │ REST
┌────────────▼─────────────┐
│ Go API (net/http, sqlc)  │
│  events, booths, answer  │
│  check, rate limit,      │
│  QR/PDF                  │
└────────────┬─────────────┘
       ┌─────▼────┐
       │PostgreSQL│
       └──────────┘

CTFd: separate, no connection. Participants submit flags there themselves.
```

### 4.1 Data model

- **Event**: a set of booths. The API serves the active event; the app fetches its data at start and caches it.
- **Booth**: scan token, question, accepted answers (one or more), flag, presentation. One question per booth.

Only the hash of the scan token and the question and presentation are sent to participants. Accepted answers and flags never leave the API except the flag after a correct answer.

### 4.2 Answer check

1. Both the submitted answer and each accepted answer are normalised: trim, lowercase, collapse whitespace, strip diacritics.
2. The answer is correct if it equals an accepted answer or is within a Levenshtein distance of 1 (normalised answers up to 8 characters) or 2 (longer answers). These thresholds are starting values, tuned with real answers.
3. Several accepted answers per question cover spelling variants and synonyms.
4. **Staff override**: when enabled in the API configuration, a staff code is accepted as a correct answer at every booth. It lets booth staff unlock the flag when the check refuses a correct answer. It is disabled by setting no code.

The check is deterministic and implemented with the Go standard library.

### 4.3 Rate limit

- 3 answer attempts per minute per device ID, across all booths. Correct answers count.
- The device ID is a random UUID generated by the app on first launch, stored locally and sent as a header. A reinstall gives a new ID.
- Implemented in memory (sliding window), single API instance. Limits are lost on restart.
- Exceeding the limit returns `429 Too Many Requests` with `Retry-After`; the app shows a countdown.
- The device ID is client-supplied and can be spoofed. This is accepted: the stakes are low and booth answers are hard to brute-force.

### 4.4 Offline tolerance

Event wifi is assumed to be unreliable.

- The event's booth data is fetched at start and cached on the device.
- Scanning, rendering and showing the question work offline.
- Checking an answer needs the API. When it cannot be reached, the app keeps the typed answer and offers a retry. There is no background queue: the participant is at the booth and waits for the result.

### 4.5 Why Go with `net/http`

- The backend owner knows Go; the API is small enough that the language choice is not otherwise constrained.
- `net/http` `ServeMux` supports method and path patterns (`POST /booths/{id}/answers`). `crypto/rand` and `crypto/sha256` cover scan tokens. No router framework is needed.
- Middleware is a plain `func(http.Handler) http.Handler`. Coach endpoints live on their own `ServeMux`, wrapped in an authentication middleware and mounted under `/admin/`.
- A single static binary keeps the Docker image small and running on a laptop at the venue simple.
- Request validation is explicit and must be done for every endpoint at the boundary. The OpenAPI document is not generated for free; if a generated Dart client is wanted, add `huma` on top of `net/http` or write the spec first.

### 4.6 Database access

- `sqlc` generates type-safe Go from plain SQL queries, checked against the schema at generation time. Chosen over GORM: no ORM magic or reflection, and the API has only fixed queries.
- Driver: `pgx/v5` (`sql_package: pgx/v5` in `sqlc.yaml`).
- Migrations: `goose`, with SQL migration files. `sqlc` reads its schema from the same migration folder, so there is one source of truth. Migrations are embedded in the binary (`embed.FS`) and run at startup, so the laptop deployment stays a single binary plus PostgreSQL.
- Generated code is never edited by hand; it is regenerated with `sqlc generate`.

## 5. Mobile app

### 5.1 Pattern

MVVM with Riverpod. View (widgets) -> ViewModel (Riverpod notifiers) -> Repository -> data sources (REST API, local cache, `BoothDetector`). Detection is injected behind the `BoothDetector` interface so it can be swapped and faked in tests.

The code is organised feature-first, with two layers per feature:

```txt
lib/
├── main.dart
├── core/                  cross-feature code only (theme, API client, device ID, shared widgets)
└── features/<feature>/
    ├── data/
    │   ├── models/        immutable value types, with pure derived values and transforms as methods
    │   └── repositories/  wrap data sources (plugins, REST, cache); a repository's provider sits in its file
    └── presentation/
        ├── view_models/   Riverpod notifiers that screens watch; the only providers widgets use
        ├── screens/
        └── widgets/
test/                      mirrors lib/
```

- Logic that processes state over time (such as tracking codes across frames) lives in the view model file as top-level pure functions, so it is unit-tested without Riverpod.
- A feature never imports another feature; shared code moves to `core/`. Folders are created when the first file needs them.
- A repository wraps its data source directly. A `data/sources/` folder is added once a repository combines several sources; DTOs are split from models once an API shape differs from the model the app uses.

Riverpod is chosen over the `setState` + `ChangeNotifier` approach taught in the course: the app combines a remote API, an offline cache, a camera-driven tracking stream and role-dependent screens, which is beyond what screen-local state handles cleanly.

### 5.2 Platform guidelines

Material on Android and platform-appropriate behaviour on iOS (navigation, permission prompts, adaptive widgets). Camera permission handling is an explicit flow, not an afterthought. The scan screen guides the user (hold the phone above the code, move closer) and offers a torch toggle for dark venues.

### 5.3 Question and answer

- Tapping the flag shows the question in AR, as a card with the flag, and in a regular sheet. The sheet stays open when the code leaves the frame, so the participant keeps the question while talking to the booth staff.
- The sheet has the answer field. A correct answer shows the flag with a copy action and a short instruction to submit it on CTFd.
- A wrong answer shows a plain retry message. Rate limiting shows the remaining wait time.
- Flags obtained are kept on the device, so the participant can copy them again later.

### 5.4 Presentation

Presentation is a field on the booth, so new presentations need no schema change. Each value maps to a built-in presentation rendered in Flutter as a flat widget standing upright on the screen (an icon, or a bundled image once there is artwork); no 3D model files are loaded. The first value is the standing flag from 3.1. Further presentations are chosen with the client.

### 5.5 Roles

| Role | Capabilities |
| --- | --- |
| Coach / admin | Create events and booths (question, accepted answers, flag, presentation), generate and export printable QR sheets |
| Participant | Scan QR codes through the AR view, open a booth's question, submit an answer, view and copy obtained flags |

Coach endpoints require authentication. Participant endpoints are anonymous and identified only by the device ID.

## 6. Deployment

One `docker-compose` setup: the Go API and PostgreSQL. On event day it runs on a laptop at the venue. CTFd is hosted separately and is not part of this setup. For now the API address is configured in the app.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| Venue wifi isolates clients, so phones cannot reach the laptop | To be settled with the client before the event: own access point, a reachable venue network segment, or a cloud server |
| Laptop or API fails during the event | Dry run before the event; booth data is cached so scanning still works; staff override is not a fix for an unreachable API |
| Answer check refuses correct spoken answers | Several accepted answers per booth, tuned fuzzy thresholds, staff override |
| Corner jitter makes the flag shake | Per-corner smoothing filter; tune on real phones in the first spike |
| Overlay lags behind the preview when the phone moves | Unrestricted detection speed, lower camera resolution; participants hold still at a booth |
| Detection fails at steep angles, in glare or in low light | Large matte print, scan-screen guidance, torch toggle; measure the angle limit in the first spike |
| Corner coordinates rotated or offset on some Android devices | Day-one test that draws the mapped corners on the preview; cover the mapping with unit tests |
| Participants must install the app on event day | Android via Play Store or a direct APK link; iOS via TestFlight or the App Store, which needs an Apple Developer account from the client |
| iOS cannot be tested by the team | No native code of our own; iOS builds through hosted macOS CI once the client provides an Apple Developer account and a test device |
| AI-generated code references non-existent plugin APIs | Pin versions, verify against source, test on a physical device |
| Device testing consumes most of the time | Budget for it explicitly; dry run on campus before the event |

## 8. Out of scope (for now)

- CTFd integration (accounts, flag submission, scoreboard)
- How the app finds the server and how TLS is set up on the venue network; decided after the client meeting
- iOS builds and release (needs a Mac or hosted macOS CI, and an Apple Developer account from the client)
- More than one question per booth
- Flutter web build as a zero-install fallback
- Cloud Anchors / VPS
- Separate web admin
