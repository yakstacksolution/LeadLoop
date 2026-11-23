# Security-rules tests

Runs every query the app actually issues against the real `firestore.rules`,
in the Firestore emulator.

```bash
npm install                       # once, in this directory
../rules_test/run.sh              # or: see below
```

## Why this exists

Firestore matches `list` rules against a **query's filters**, not against the
documents it returns. So a rule can be perfectly correct for single-document
reads and still deny every query, if the repository filters on a different
field than the rule checks.

That is not visible in code review and does not show up in `flutter analyze` or
the widget tests — it appears only at runtime as
`PERMISSION_DENIED: Missing or insufficient permissions`. It has bitten this
project twice:

1. Rules checked `projectId in profile().assignedProjectIds`, which is not
   matchable by any query filter — every employee read was denied.
2. Rules checked `assignedEmployeeId` on `visits`, but three repository queries
   filter on `employeeId` — the visit counts were denied.

Add a case here whenever you add or change a query.

## Requirements

The emulator needs **JDK 21+**. If `java -version` reports older:

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@24/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
```
