# Hamro Futsal — Lead & Venue Follow-Up Management

Internal Flutter + Firebase app for tracking futsal venue leads: projects,
venues, venue contacts, scheduled calls and meetings, notes, lead status
history, and venue visits.

Firebase project: **`hamro-futsal-lead`**
([console](https://console.firebase.google.com/project/hamro-futsal-lead/overview))
Firestore region: **`asia-south1`** (Mumbai — lowest latency for Nepal).

---

## Plan: Spark (free) — no Cloud Functions required

This app runs entirely on the **free Spark plan**. Nothing in the normal
workflow needs Cloud Functions, a server, or a service-account key.

The two operations that would normally need the Admin SDK are handled on the
client instead, in supported ways:

**Creating employee accounts** — `AccountProvisioner` creates the auth account
on a *secondary* `FirebaseApp`. `FirebaseAuth` keeps one session per app
instance, so the new user is signed in on the second instance while the admin
stays signed in on the default one. The profile document is then written from
the admin's own session, which is what satisfies `allow create: if isAdmin()`.

**Creating the first administrator** — a self-closing bootstrap rule. A signed
in user may create their own profile with `role: "admin"` *only while*
`/system/claimed` does not exist, and the bootstrap is committed as one batch
that creates both that profile and the sentinel. Firestore's `create` fails if
a document already exists, so the sentinel is writable exactly once in the
lifetime of the project. Every later attempt fails twice over: the sentinel
create is rejected, and the `exists()` check is true.

This was verified against the live project, not just reasoned about: a second
account attempting the identical batch got **403**, and attempting to read the
admin's profile got **403**.

### Honest limits of running without a server

| | Spark (current) | With Blaze + Functions |
|---|---|---|
| Create employees | ✅ secondary app | ✅ Admin SDK |
| First admin | ✅ self-closing rule | ✅ `bootstrapFirstAdmin` |
| Role stored in custom claim | ❌ profile document only | ✅ mirrored by trigger |
| Disable at Firebase Auth level | ❌ see below | ✅ |

**Disabling an account** sets `status: "disabled"` on the profile. The security
rules then refuse every read and write for that user, and the app refuses the
sign-in — so they lose access to all data immediately. Their Firebase Auth
login itself remains enabled, because switching that off needs the Admin SDK.
The UI says exactly this rather than implying a harder guarantee.

**Custom claims** cannot be set from a client, so `role` lives only in the
profile document. The rules were written from the start to check the claim
*and* fall back to the profile, so authorisation is correct either way.

### Optional: Cloud Functions

`functions/index.js` is complete and ready. It is **not required**. If you later
upgrade to Blaze, `firebase deploy --only functions` adds custom-claim syncing,
Auth-level disabling, and a server-side status-history trigger. The app keeps
working unchanged if you never do.

---

## First run

The administrator account is **already created** on `hamro-futsal-lead`:

| | |
|---|---|
| email | `admin@gmail.com` |
| password | `FutsalLead@123` |
| uid | `I6We9ZVpLncLTKsVfTbkT6bp4S73` |

Sign in and you land on the admin dashboard. From there everything happens
in-app: create a project → create employees → assign them → they add venues.
There is deliberately no self-service sign-up.

> `admin@gmail.com` is a real Gmail address. Password-reset mail goes to
> whoever owns it. For production, replace it with an address on a domain you
> control.

### Starting over on a fresh Firebase project

1. Enable Email/Password sign-in once in the console — no CLI command exists
   for this: Authentication → Get started → Email/Password → Enable.
2. `flutter pub get && flutter run`
3. Create the first account with
   `node tools/seed_admin.mjs "<email>" "<password>" "<full name>"`.
4. Sign in. With no profile yet the app shows the one-time **"Set up your
   workspace"** screen. Tap *Become administrator*: that runs the self-closing
   bootstrap batch described above and closes it permanently.

## Architecture

Clean architecture, feature-first, BLoC/Cubit for state, `get_it` for DI,
`go_router` for navigation.

```
lib/
├── core/           constants, enums, errors, theme, utils, services, di, router
├── features/<f>/
│   ├── data/       Firestore models + repository implementations
│   ├── domain/     entities + repository contracts (no Firebase types)
│   └── presentation/  cubits, pages, widgets
└── shared/widgets/ reusable UI (status chips, state views, form fields, shell)
```

Rules that are kept, not aspirational:

- **No Firestore calls in widgets.** Widgets talk to cubits; cubits talk to
  repository contracts.
- **Repositories never throw across the domain boundary.** Every call goes
  through `guard()` in `core/errors/error_mapper.dart` and comes back as
  `Result<T>` — either a value or a user-presentable `Failure`.
- **Every stream subscription is cancelled** in the owning cubit's `close()`.
- **Server timestamps everywhere.** Client clocks are never trusted for
  ordering, and the rules require `request.time` on create.

### Firestore collections

`users`, `projects`, `venues`, `venue_contacts`, `activities`, `visits`,
`notes`, `status_history`, `audit_logs`, `notifications`.

All top-level. Nothing important is stored as an array inside a parent
document, so a venue with 200 activities is as cheap to open as one with two.

Every scoped document carries a denormalised **`projectId`**. That is what lets
a single security-rule evaluation authorise a contact, activity, visit or note
without walking up to its parent venue.

Venues also carry denormalised `lastVisitedAt`, `visitCount`, `lastActivityAt`
and `nextFollowUpAt`, so the venue list can answer "visited? due when?" without
a query per row. The source collections remain the truth; these are caches,
and `_refreshNextFollowUp` rebuilds the pointer after every activity write.

---

## Authorisation model

Two roles: `admin` and `employee`. Enforced in **three** places, in this order
of authority:

1. **Firestore security rules** (`firestore.rules`) — the real boundary.
2. **Cloud Functions** for privileged operations that rules cannot express.
3. **UI guards** (`core/router/app_router.dart`) — convenience only. Forcing
   your way to an admin route gets you a screen full of permission errors, not
   data.

`role` lives in the user's profile **and** is mirrored to a custom auth claim
by the `syncUserClaims` trigger. Rules check the cheap, tamper-proof claim
first and fall back to the profile document, so authorisation is correct
before a token has refreshed — and before Functions are deployed at all.

**Employees are scoped by project membership.** `users/{uid}.assignedProjectIds`
is the single source of truth, mirrored onto `projects/{id}.assignedEmployeeIds`.
Both sides are always written in one atomic batch, because a one-sided link
would silently break someone's access.

Clients can never write `role`, `status` or `assignedProjectIds` on their own
profile — the rules reject it.

### Why every record carries `assignedEmployeeId`

This is the single most important thing to understand before editing the rules.

**Firestore evaluates `list` rules against the query, not against each returned
document.** A query is allowed only if its own filters *imply* the rule. So:

```js
// WORKS for queries — the client filters on the same field.
resource.data.assignedEmployeeId == request.auth.uid

// DOES NOT WORK for queries — the list comes from a get() the query
// knows nothing about, so Firestore cannot prove the query is safe and
// denies it outright, even when every matching document would qualify.
resource.data.projectId in profile().assignedProjectIds
```

The first version of these rules used the second form. Reads worked for admins
(`isAdmin()` short-circuits before touching document data) and failed with
`PERMISSION_DENIED` for every employee.

So every employee-visible record — venues, contacts, activities, visits, notes
and status history — carries a denormalised `assignedEmployeeId` holding the
**parent venue's assignee**, and every employee query filters on it. Project
membership still governs which projects an employee may *file* a venue under,
and still guards single-document `get`s; it just cannot be the basis of a list
rule.

Consequence, and it matches the spec: an employee sees the venues **assigned to
them**, not every venue in their project.

When an admin reassigns a venue, `reassign()` rewrites `assignedEmployeeId` on
all of that venue's child records in chunked batches — otherwise the entire
history would become invisible to the new assignee.

### What is immutable

- `status_history` and `audit_logs`: create-only. No update, no delete.
- `visits.isSelfReported`: fixed at creation. The rules refuse to let it change.
- `notes`: the author may correct their own wording, but the original text is
  preserved in `originalText` and the edit is stamped.
- Nothing important is client-deletable. Venues and projects are archived via
  a status field; accounts are disabled, never deleted.

---

## Visit tracking — what the app does and does not claim

This matters, so it is stated plainly in the code and in the UI.

Tapping a button does **not** prove someone went anywhere. Every visit carries
`isSelfReported`:

- **Self-reported** — the default. The employee marked it; no location backs it.
- **Location-supported** — the device returned coordinates at the moment the
  visit was opened, and they are stored with their accuracy radius.

Both are shown with distinct labels everywhere a visit appears. An admin is
never led to treat one as the other.

There is **no background or continuous location tracking**. A single fix is
requested only when the employee taps *Start visit*, after the screen has
explained why. Declining is a supported path, not an error — the visit is
simply recorded as self-reported.

Similarly: the app schedules and records calls. **It does not place them**, and
nothing in it implies a call happened until the employee marks it complete.

---

## Performance

Rules the codebase holds to, with the reasons, because each one was a real
source of jank:

**Never build a `Stream` or `Future` inside `build()`.** A `StreamBuilder`
whose stream is constructed inline cancels its Firestore listener and opens a
new one on *every* rebuild — re-fetching, re-rendering and re-billing. On the
employee list, where searching calls `setState`, that was one fresh listener
per keystroke. Every stream and future now lives in a `State` field, keyed on
the value it depends on so it re-subscribes only when that actually changes.
`grep -rn "stream: sl<\|future: sl<" lib/` should return nothing.

**Debounce anything that re-queries.** Venue search waits 350 ms for a pause in
typing instead of issuing a Firestore query per character.

**Keep derived work out of getters that build() calls.** The venue timeline
merges and sorts four lists; as a plain getter it recomputed on every build of
the detail screen. It is a `late final` field now, so it is computed at most
once per state instance.

**No `IntrinsicHeight` inside a scrolling list.** It forces a second layout
pass per row. The timeline's connector line is drawn with a `Positioned` inside
a `Stack` instead.

**Count only what you display.** Each `count()` aggregation is a round trip.
The admin dashboard renders the full 11-status pipeline, so it counts all 11;
the employee dashboard shows three figures, so it asks for three — eight fewer
round trips on a mobile connection.

**`const` is enforced, not hoped for.** `prefer_const_constructors` and friends
are enabled in `analysis_options.yaml`; a const subtree is skipped wholesale on
rebuild.

## Search and filter limitations

Firestore cannot combine arbitrary predicates, so `VenueFilter` splits
deliberately:

| Pushed to the server (indexed) | Applied in memory (per page) |
|---|---|
| `projectId`, `assignedEmployeeId`, `status`, sort field | `priority`, `area`/`city`, free-text search |

Consequence: **free-text search matches within the fetched page**, not the whole
collection. For a few thousand venues that is fine when combined with a project
or status filter. If the venue count grows past that, add Algolia or Typesense
rather than widening the client-side pass.

Employee name/email search is client-side for the same reason — the user list
is measured in dozens.

`whereIn` is capped at 30 values, so `getProjectsByIds` / `getEmployeesByIds`
chunk their input.

---

## Dashboard performance

Dashboard and report figures use Firestore's server-side `count()` aggregation.
The whole admin dashboard costs a fixed handful of aggregation queries
regardless of database size — no venue documents are downloaded to count them.

---

## Firebase setup

Already done and deployed:

```bash
firebase projects:create hamro-futsal-lead
flutterfire configure --project=hamro-futsal-lead --platforms=android,ios,web
firebase firestore:databases:create "(default)" --location asia-south1
firebase deploy --only firestore:rules,firestore:indexes
```

To redeploy rules or indexes after a change:

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

`lib/firebase_options.dart`, `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist` are generated by FlutterFire. These hold
public client identifiers, not secrets. **No service-account private key exists
anywhere in this repository or in the app** — that is the entire reason the
privileged operations live in Cloud Functions.

---

## Emulator testing

```bash
firebase emulators:start --only auth,firestore,functions
```

Ports: Auth 9099, Firestore 8080, Functions 5001, UI 4000.

To point the app at the emulators, add this after `Firebase.initializeApp` in
`lib/main.dart` (guarded so it never ships in a release build):

```dart
if (kDebugMode && useEmulators) {
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseFunctions.instanceFor(region: 'asia-south1')
      .useFunctionsEmulator('localhost', 5001);
}
```

`configureDependencies()` accepts injected `FirebaseAuth`, `FirebaseFirestore`
and `FirebaseFunctions` instances, which is also how the tests avoid touching
a real project.

To exercise the security rules against the emulator, use
`@firebase/rules-unit-testing` and assert both directions — that an employee
*can* read a venue in their project, and *cannot* read one outside it. The
rules deploy and compile cleanly; automated rules tests are the main remaining
test gap (see below).

---

## Tests

```bash
flutter test          # 102 unit + widget tests
flutter analyze       # clean
./rules_test/run.sh   # 44 security-rules tests against the emulator
```

**Run `./rules_test/run.sh` after touching `firestore.rules` or any repository
query.** It is the only thing that catches a rule/query mismatch: Firestore
matches `list` rules against a query's *filters*, so a rule can be correct for
single-document reads and still deny every query. That failure mode is
invisible to the analyzer and to the widget tests, and has bitten this project
twice — see `rules_test/README.md`.

Covered:

- **Unit** — overdue/upcoming calculation and day boundaries, follow-up
  bucketing, validators, role/project permissions, enum parsing fallbacks,
  venue follow-up and visit logic, visit evidence classification, generated
  password properties, Firebase error mapping, `AuthCubit` session transitions.
- **Widget** — login form validation and failure display, venue card states
  (visited, overdue, archived, won), visit tile evidence labelling.
- **Security rules** — every query *and every write* the app issues, for both
  roles, plus twelve checks that must FAIL: an employee listing another
  employee's venues, listing venues unscoped, listing all users, reading
  another profile, listing notes unscoped, granting themselves admin,
  reassigning their own venue, moving it between projects, rewriting a visit's
  evidence flag, editing immutable status history, and writing a record owned
  by someone else.

  The write cases mirror each repository's outgoing map field for field. That
  is the point: a map that omits `assignedEmployeeId` fails the create rule and
  takes its whole batch down with it, and nothing else in the toolchain sees
  it.

**Not yet covered:** end-to-end integration tests driving the real UI.

## Build

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
flutter build web --release
```

Android applicationId / iOS bundle id: `com.np.hamrofutsal.lead`.

---

## Notifications

`firebase_messaging` is a dependency and the schema has a `notifications`
collection and a `users/{uid}/devices` subcollection, but **no push
notifications are sent yet** — there is no scheduled function writing them and
no device-token registration wired up. The app shows in-app overdue and
upcoming indicators only, and the scheduling screen says so rather than
implying reminders will arrive.
