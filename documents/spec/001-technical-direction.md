# SPEC-001: Technical Direction

Status: draft, based on the initial exploration. Source brief: [ITF-005 AR for CTF](../files/ITF-005%20AR%20for%20CTF.md).

## 1. Context

An AR-assisted Capture The Flag for Bsides Limburg. The event is **indoors**, with stands at which participants find flags. Coaches place flags at stands. Participants walk around, scan them with the app, and then either receive the flag code directly or get it from the person at the stand.

The solution should be reusable for other events and venues.

### Team and constraints

- 2 people, part-time, roughly 3 months.
- Priority: it works reliably on event day.
- Not graded; something usable has to be delivered.
- Learning goals to cover: AR in a cross-platform app, exploring AR technologies, a structured design pattern (MVVM), platform-specific guidelines.
- Development is Linux-based. iOS builds need a Mac. This is out of scope for now; if iOS is required, the client should provide the hardware.

## 2. Decisions

| Area | Decision |
| --- | --- |
| Mobile app | Flutter, Android first, iOS later |
| Architecture | MVVM with Riverpod |
| AR anchoring | Printed QR code laid flat at the stand; the flag is rendered on top of it |
| AR implementation | Native ARCore (Android) and ARKit (iOS) behind a Flutter platform channel or with ar_flutter_plugin_2 |
| Backend | FastAPI service (BFF) with PostgreSQL |
| Scoring | CTFd, behind an adapter. Integration is desirable, not mandatory |
| Coach tooling | In the mobile app, coach role. No separate website |
| QR generation | Backend endpoint producing a printable PDF sheet, triggered from the coach app |
| Hosting | Docker Compose; the same setup runs in the cloud or on an own server |

## 3. AR approach

### 3.1 How a flag is anchored

1. The AR session runs with plane detection enabled.
2. Every camera frame is also passed to a barcode decoder (ML Kit on Android, Vision on iOS).
3. When a QR code is detected, its payload and corner points (screen space) are returned.
4. A hit-test from the QR centre onto the detected plane yields the anchor position.
5. An anchor is created and the flag object is spawned. The corner points can be used to orient the object to match the paper.
6. From then on the AR engine tracks the anchor; the QR code no longer needs to stay in view.

This works indoors, does not depend on the venue looking the same as during setup, and needs no venue-specific scanning or cloud service.

### 3.2 QR payload

- Contains a signed identifier, e.g. `arctf://f/<flagId>?s=<signature>`.
- **Never contains the flag code.** The QR can be photographed.
- The signature lets the backend and app reject forged codes.
- One app build serves every event; flags are data, not bundled assets.

### 3.3 Anti-cheat

The interact action is only available after the anchor has actually been placed (plane found, object spawned), so a photo of a QR code on a screen is not enough.

### 3.4 Flutter / native boundary

AR runs natively; Flutter owns everything else. The contract is defined on the Dart side so that iOS is a second implementation of the same interface rather than a redesign.

```txt
ArView            widget embedding the native AR view
ArController      commands: start, stop, spawnObject(anchorId, model), clear
                  events (stream): planeFound, qrDetected(payload, corners),
                                   anchorPlaced(anchorId), objectTapped(anchorId),
                                   trackingStateChanged(state), error(code)
```

The native side contains no business logic, no networking and no persistence.

### 3.5 Non-AR fallback

Devices without AR support get a plain QR scan mode that uses the same backend and the same payloads. This is an event-day safeguard (BYOD phones), not an extra.

### 3.6 Alternatives evaluated and rejected

| Option | Why not |
| --- | --- |
| GPS / wifi positioning | 10-50 m accuracy indoors; cannot distinguish stands |
| BLE beacons | Extra hardware per stand and venue; crowds degrade signal; positions but cannot anchor AR content |
| Wifi RTT, UWB, BLE AoA | Phone support is partial or absent, or needs venue infrastructure |
| ARCore Geospatial | Based on Street View; effectively outdoor only |
| ARCore Cloud Anchors | Depends on the venue looking the same between setup and event; flaky resolution risk; Flutter plugin support is stale |
| Full VPS (Niantic Spatial VPS 2.0, Immersal, MultiSet) | Requires scanning the entire venue in its final state, vendor cloud dependency; no conference precedent found |
| ARKit ARWorldMap | iOS only; sensitive to lighting changes; size limits |
| Flutter + Unity (AR Foundation) | Extra toolchain and dependency, weak Linux support, blurs MVVM; not needed for QR + plane anchoring |
| Flutter + Unity + Vuforia (`flutter_embed_unity`, as used in the ITF mobile development course) | VuMarks (ID-encoding markers that are also 6DoF targets, free on the Basic licence) fit technically. Rejected: Vuforia officially supports only Windows for Unity development while the team works on Linux (Debian); the course setup pins exact Unity/Flutter/NDK versions with a fragile export pipeline; Vuforia's QR Barcode Scanner is a Premium feature. The learning goals do not require Vuforia or Unity |
| `ar_flutter_plugin` | Last release 4 years ago, Sceneform-based, no image tracking |

Cloud Anchors or a VPS remain possible as a later experiment behind the same `ArController` contract. They are not part of the core scope.

## 4. System architecture

```txt
┌──────────────────────────┐
│ Flutter app              │
│  Participant / Coach UI  │
│  MVVM + Riverpod         │
│  ArController ◄──► native AR (ARCore / ARKit)
└────────────┬─────────────┘
             │ REST
┌────────────▼─────────────┐
│ FastAPI BFF              │
│  events, flags, QR/PDF,  │
│  AR presentation data,   │
│  roles, identity         │
│        │ ScoringAdapter  │
└────────┼─────────────────┘
         │            │
   ┌─────▼────┐  ┌────▼─────┐
   │PostgreSQL│  │  CTFd    │
   └──────────┘  └──────────┘
```

### 4.1 Backend (BFF)

- Owns the data CTFd does not model: events, flag/checkpoints, QR codes, AR presentation (model, interaction type), hints, coach and participant roles.
- Exposes one clean API to the app. The app never talks to CTFd directly.
- Delegates scoring, teams, flag validation and the scoreboard to CTFd through a `ScoringAdapter` interface. Other adapters (e.g. a simple local scorer) can be added without touching the app.
- Holds the privileged CTFd token. This token must never reach the client.

### 4.2 Why a BFF instead of the app talking to CTFd

- CTFd authentication is web/cookie based and has no OAuth, which is a poor fit for a mobile app.
- AR-specific data has no clean home inside CTFd.
- Keeps CTFd optional.
- Allows signed QR payloads and a single place for validation.

### 4.3 Why CTFd for scoring

Teams, flag validation, scoring and a live scoreboard already exist and are familiar to a CTF audience. Rebuilding them would consume a large part of the project for no gain.

### 4.4 Scoreboard

Polling is sufficient: the BFF polls CTFd every 10-15 s and serves the cached result. WebSockets are a possible later upgrade.

### 4.5 Offline tolerance

Event wifi is assumed to be unreliable.

- The event's flag list and AR data are fetched once at join and cached on the device.
- Scanning and rendering work offline.
- Only flag submission needs the network; it is queued and retried.

## 5. Mobile app

### 5.1 Pattern

MVVM with Riverpod. View (widgets) -> ViewModel (Riverpod notifiers) -> Repository -> data sources (REST API, local cache, `ArController`). The AR module is injected behind the `ArController` interface so it can be faked in tests and the non-AR fallback can share the same ViewModels.

Riverpod is chosen over the `setState` + `ChangeNotifier` approach taught in the course: the app combines a remote API, an offline cache with a submission queue, a native AR event stream and role-dependent screens, which is beyond what screen-local state handles cleanly.

### 5.2 Platform guidelines

Material on Android and platform-appropriate behaviour on iOS (navigation, permission prompts, adaptive widgets). Camera permission handling and AR-unsupported-device handling are explicit flows, not afterthoughts.

### 5.3 Roles

| Role | Capabilities |
| --- | --- |
| Coach / admin | Create events and flags, assign points, hints and challenge type, generate and export printable QR sheets, monitor scoreboard and submission status in real time |
| Participant | Join an event, scan QR codes through the AR view, interact with the spawned flag, submit flag codes, view scoreboard |

### 5.4 Interaction on a flag

Interaction type is a field on the flag so new types can be added without schema changes. Planned types:

- **Reveal**: tap the object, the flag code is shown.
- **Ask the stand**: tap the object, the app instructs the participant to get the code from the person at the stand.
- Later candidates: mini-challenge, multi-stand combinations.

Flags that matter should use "ask the stand" or a challenge, since a QR can be photographed.

## 6. Deployment

One `docker-compose` setup: FastAPI, PostgreSQL, CTFd (with its own database and cache). It can run on a laptop at the venue, on an own server, or in the cloud. TLS and authentication are designed with the assumption that the event network is untrusted.

## 7. Risks

| Risk | Mitigation |
| --- | --- |
| No usable Flutter AR plugin exists | Thin native layer behind a Dart interface; spike early |
| QR codes photographed and shared | Signed payload without flag code; "ask the stand" interaction; anchor must be placed before interaction |
| Poor event wifi | Local caching, queued submissions, option to host on a local machine |
| Unsupported or old phones | Non-AR QR scan fallback |
| Plane detection slow or fails on reflective or featureless tables | User guidance in the UI, hit-test fallback to estimated depth |
| CTFd API/auth quirks | All CTFd access isolated in one adapter |
| AI-generated code references non-existent plugin APIs | Pin versions, verify against source, test on a physical device |
| Device testing consumes most of the time | Budget for it explicitly; dry run on campus before the event |

## 8. Out of scope (for now)

- iOS builds and release (needs a Mac supplied by the client)
- Cloud Anchors / VPS
- Separate web admin
- WebSocket scoreboard
- Custom scoring engine
