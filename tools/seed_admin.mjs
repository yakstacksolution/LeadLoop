/**
 * One-time bootstrap of the first administrator.
 *
 * Creates the Firebase Auth account and its `/users/{uid}` admin profile.
 *
 * Why this exists: creating the first admin is a chicken-and-egg problem. The
 * security rules only let an existing admin create a user profile, and there is
 * no admin yet. The `bootstrapFirstAdmin` Cloud Function solves this properly,
 * but Functions need the Blaze plan. This script is the Spark-plan equivalent.
 *
 * It uses only the public web API key and the user's own ID token — no service
 * account key is involved, and it never modifies the security rules.
 *
 * Creating the AUTH ACCOUNT always works once Email/Password sign-in is on.
 * Writing the PROFILE only works if an admin already exists, because the rules
 * correctly refuse a self-granted admin role. On a brand-new project the
 * profile write is expected to fail, and the script prints the two supported
 * ways to finish the bootstrap.
 *
 * Usage:  node tools/seed_admin.mjs <email> <password> "<full name>"
 */

import fs from 'fs';
import path from 'path';

const [, , email, password, fullName = 'Administrator'] = process.argv;

if (!email || !password) {
  console.error('Usage: node tools/seed_admin.mjs <email> <password> "<full name>"');
  process.exit(1);
}

// The web API key is a public client identifier, read straight from the
// generated FlutterFire options so this never drifts out of sync.
const optionsPath = path.join(process.cwd(), 'lib', 'firebase_options.dart');
const optionsSource = fs.readFileSync(optionsPath, 'utf8');

const apiKey = optionsSource.match(/apiKey:\s*'([^']+)'/)?.[1];
const projectId = optionsSource.match(/projectId:\s*'([^']+)'/)?.[1];

if (!apiKey || !projectId) {
  console.error('Could not read apiKey/projectId from lib/firebase_options.dart.');
  process.exit(1);
}

async function identityToolkit(method, body) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:${method}?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    },
  );
  return { ok: response.ok, data: await response.json() };
}

// ---- 1. create (or sign in to) the auth account --------------------------

let auth = await identityToolkit('signUp', {
  email,
  password,
  returnSecureToken: true,
});

if (!auth.ok) {
  const code = auth.data?.error?.message ?? 'UNKNOWN';

  if (code === 'CONFIGURATION_NOT_FOUND' || code === 'OPERATION_NOT_ALLOWED') {
    console.error(
      '\nEmail/Password sign-in is not enabled on this Firebase project.\n\n' +
        'Enable it once, then re-run:\n' +
        `  https://console.firebase.google.com/project/${projectId}/authentication/providers\n` +
        '  Authentication → Get started → Email/Password → Enable → Save\n',
    );
    process.exit(3);
  }

  if (code === 'EMAIL_EXISTS') {
    // Re-runnable: fall back to signing in so the profile can still be seeded.
    console.log(`Account ${email} already exists — signing in to seed its profile.`);
    auth = await identityToolkit('signInWithPassword', {
      email,
      password,
      returnSecureToken: true,
    });

    if (!auth.ok) {
      console.error(
        `That account exists but the supplied password is wrong ` +
          `(${auth.data?.error?.message}).`,
      );
      process.exit(2);
    }
  } else {
    console.error(`Could not create the account: ${code}`);
    process.exit(2);
  }
} else {
  console.log(`Created auth account for ${email}`);
}

const { localId: uid, idToken } = auth.data;

// ---- 2. write the admin profile document ---------------------------------

// Firestore's REST API takes typed values, hence the verbose shape.
const profile = {
  fields: {
    id: { stringValue: uid },
    fullName: { stringValue: fullName },
    email: { stringValue: email.toLowerCase() },
    phone: { stringValue: '' },
    employeeCode: { stringValue: '' },
    role: { stringValue: 'admin' },
    status: { stringValue: 'active' },
    assignedProjectIds: { arrayValue: { values: [] } },
    createdAt: { timestampValue: new Date().toISOString() },
    updatedAt: { timestampValue: new Date().toISOString() },
    createdBy: { stringValue: uid },
  },
};

const writeResponse = await fetch(
  `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}`,
  {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(profile),
  },
);

if (!writeResponse.ok) {
  // Expected on a fresh project: the rules refuse to let anyone hand themselves
  // the admin role, which is exactly what they are there for.
  console.log(`\nAuth account is ready (uid ${uid}), but the admin profile was`);
  console.log(`refused by the security rules (HTTP ${writeResponse.status}).`);
  console.log('\nThat refusal is correct — nobody may grant themselves admin.');
  console.log('Finish the bootstrap in one of these two supported ways:\n');
  console.log('  A. Deploy Cloud Functions (needs the Blaze plan), then sign in');
  console.log('     to the app. It shows a one-time "Set up your workspace"');
  console.log('     screen that calls bootstrapFirstAdmin, which grants admin');
  console.log('     server-side only while no admin exists.\n');
  console.log('  B. Create the profile document once in the Firebase console:');
  console.log(`     https://console.firebase.google.com/project/${projectId}/firestore/databases/-default-/data`);
  console.log(`     Collection "users", document ID exactly: ${uid}`);
  console.log('     Fields:');
  console.log(`       id                 (string)  ${uid}`);
  console.log(`       fullName           (string)  ${fullName}`);
  console.log(`       email              (string)  ${email.toLowerCase()}`);
  console.log('       role               (string)  admin');
  console.log('       status             (string)  active');
  console.log('       assignedProjectIds (array)   (leave empty)');
  console.log('       createdAt          (timestamp) now');
  console.log('\nThen sign in to the app.');
  process.exit(0);
}

console.log(`Wrote admin profile /users/${uid}`);
console.log('\nDone. Sign in to the app with these credentials.');
console.log(`  email:    ${email}`);
console.log(`  uid:      ${uid}`);
console.log('\nNote: this account is an admin via its profile document. Once Cloud');
console.log('Functions are deployed, the syncUserClaims trigger will also mirror the');
console.log('role into a custom auth claim.');
