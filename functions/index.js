/**
 * Hamro Futsal — privileged server-side operations.
 *
 * Everything in here needs the Admin SDK: creating an auth account without
 * signing the calling admin out, writing custom claims, disabling accounts and
 * minting password-reset links. None of it can be done safely from the Flutter
 * client, which is why no service-account key ever ships in the app.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

setGlobalOptions({ region: 'asia-south1', maxInstances: 10 });

const ROLES = ['admin', 'employee'];
const STATUSES = ['active', 'disabled'];

// ---------------------------------------------------------------- helpers

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'You must be signed in.');
  }
  return request.auth;
}

/**
 * Confirms the caller is an active admin. The custom claim is authoritative,
 * but we re-read the profile so that an admin who was disabled a moment ago
 * cannot keep acting on a still-valid token.
 */
async function requireActiveAdmin(request) {
  const { uid } = requireAuth(request);
  const snap = await db.collection('users').doc(uid).get();
  const profile = snap.data();

  if (!snap.exists || profile.role !== 'admin') {
    throw new HttpsError('permission-denied', 'Admin privileges are required.');
  }
  if (profile.status !== 'active') {
    throw new HttpsError('permission-denied', 'Your account is disabled.');
  }
  return { uid, profile };
}

function cleanString(value, field, { required = true, max = 200 } = {}) {
  const text = typeof value === 'string' ? value.trim() : '';
  if (required && text.length === 0) {
    throw new HttpsError('invalid-argument', `${field} is required.`);
  }
  if (text.length > max) {
    throw new HttpsError('invalid-argument', `${field} is too long.`);
  }
  return text;
}

function cleanEmail(value) {
  const email = cleanString(value, 'Email').toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new HttpsError('invalid-argument', 'That email address is not valid.');
  }
  return email;
}

function cleanIdList(value, field) {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) {
    throw new HttpsError('invalid-argument', `${field} must be a list.`);
  }
  const ids = value.filter((id) => typeof id === 'string' && id.trim().length > 0);
  if (ids.length > 100) {
    throw new HttpsError('invalid-argument', `${field} has too many entries.`);
  }
  return [...new Set(ids)];
}

async function writeAuditLog(action, entityType, entityId, performedBy, metadata = {}) {
  await db.collection('audit_logs').add({
    action,
    entityType,
    entityId,
    performedBy,
    metadata,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/** Generates a password an admin can hand over once, before the first reset. */
function temporaryPassword() {
  // 18 URL-safe characters of CSPRNG output — comfortably above Firebase's
  // 6-character minimum and never derived from the user's own details.
  return require('crypto').randomBytes(18).toString('base64url');
}

// ---------------------------------------------------------------- bootstrap

/**
 * Creates the very first admin. Deliberately callable by any signed-in user,
 * but ONLY while the users collection holds no admin at all — after that it is
 * permanently closed. This is what turns a freshly provisioned project into a
 * usable one without ever shipping a service-account key.
 */
exports.bootstrapFirstAdmin = onCall(async (request) => {
  const { uid, token } = requireAuth(request);

  const existingAdmins = await db
    .collection('users')
    .where('role', '==', 'admin')
    .limit(1)
    .get();

  if (!existingAdmins.empty) {
    throw new HttpsError(
      'failed-precondition',
      'An administrator already exists. Ask them to create your account.',
    );
  }

  const fullName = cleanString(request.data?.fullName ?? token.name ?? 'Administrator', 'Full name');

  await auth.setCustomUserClaims(uid, { role: 'admin' });

  await db.collection('users').doc(uid).set({
    id: uid,
    fullName,
    email: (token.email || '').toLowerCase(),
    phone: cleanString(request.data?.phone, 'Phone', { required: false, max: 30 }),
    employeeCode: '',
    role: 'admin',
    status: 'active',
    assignedProjectIds: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: uid,
  });

  await writeAuditLog('bootstrap_admin', 'user', uid, uid, { fullName });

  return { ok: true, uid, role: 'admin' };
});

// ---------------------------------------------------------------- employees

/**
 * Creates an employee (or another admin) without disturbing the caller's own
 * session — the reason this cannot be done with the client SDK.
 */
exports.createEmployee = onCall(async (request) => {
  const { uid: callerUid } = await requireActiveAdmin(request);
  const data = request.data || {};

  const fullName = cleanString(data.fullName, 'Full name');
  const email = cleanEmail(data.email);
  const phone = cleanString(data.phone, 'Phone', { required: false, max: 30 });
  const employeeCode = cleanString(data.employeeCode, 'Employee code', { required: false, max: 40 });
  const role = ROLES.includes(data.role) ? data.role : 'employee';
  const assignedProjectIds = cleanIdList(data.assignedProjectIds, 'Assigned projects');

  const password =
    typeof data.password === 'string' && data.password.length >= 8
      ? data.password
      : temporaryPassword();

  let userRecord;
  try {
    userRecord = await auth.createUser({
      email,
      password,
      displayName: fullName,
      emailVerified: false,
      disabled: false,
    });
  } catch (error) {
    if (error.code === 'auth/email-already-exists') {
      throw new HttpsError('already-exists', 'An account with that email already exists.');
    }
    if (error.code === 'auth/invalid-password') {
      throw new HttpsError('invalid-argument', 'That password is too weak.');
    }
    throw new HttpsError('internal', error.message);
  }

  const newUid = userRecord.uid;

  try {
    await auth.setCustomUserClaims(newUid, { role });

    await db.collection('users').doc(newUid).set({
      id: newUid,
      fullName,
      email,
      phone,
      employeeCode,
      role,
      status: 'active',
      assignedProjectIds,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: callerUid,
    });

    // Keep the reverse index on each project in step.
    await Promise.all(
      assignedProjectIds.map((projectId) =>
        db
          .collection('projects')
          .doc(projectId)
          .update({
            assignedEmployeeIds: admin.firestore.FieldValue.arrayUnion(newUid),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          })
          .catch(() => null),
      ),
    );
  } catch (error) {
    // Never leave an auth account behind with no profile — it would be able to
    // sign in while matching no security rule.
    await auth.deleteUser(newUid).catch(() => null);
    throw new HttpsError('internal', `Could not finish creating the account: ${error.message}`);
  }

  await writeAuditLog('create_employee', 'user', newUid, callerUid, { email, role, fullName });

  const resetLink = await auth.generatePasswordResetLink(email).catch(() => null);

  return {
    ok: true,
    uid: newUid,
    email,
    // Returned once, so the admin can hand over credentials in person. The
    // caller must not persist it.
    temporaryPassword: data.password ? null : password,
    passwordResetLink: resetLink,
  };
});

/** Enables or disables an account in both Firebase Auth and the profile. */
exports.setEmployeeStatus = onCall(async (request) => {
  const { uid: callerUid } = await requireActiveAdmin(request);
  const targetUid = cleanString(request.data?.uid, 'User id');
  const status = request.data?.status;

  if (!STATUSES.includes(status)) {
    throw new HttpsError('invalid-argument', 'Status must be "active" or "disabled".');
  }
  if (targetUid === callerUid && status === 'disabled') {
    throw new HttpsError('failed-precondition', 'You cannot disable your own account.');
  }

  await auth.updateUser(targetUid, { disabled: status === 'disabled' });
  await db.collection('users').doc(targetUid).update({
    status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Disabling should take effect immediately, not at the next token refresh.
  if (status === 'disabled') {
    await auth.revokeRefreshTokens(targetUid);
  }

  await writeAuditLog('set_employee_status', 'user', targetUid, callerUid, { status });

  return { ok: true, uid: targetUid, status };
});

/** Changes a user's role and keeps the custom claim authoritative. */
exports.setEmployeeRole = onCall(async (request) => {
  const { uid: callerUid } = await requireActiveAdmin(request);
  const targetUid = cleanString(request.data?.uid, 'User id');
  const role = request.data?.role;

  if (!ROLES.includes(role)) {
    throw new HttpsError('invalid-argument', 'Role must be "admin" or "employee".');
  }
  if (targetUid === callerUid) {
    throw new HttpsError('failed-precondition', 'You cannot change your own role.');
  }

  await auth.setCustomUserClaims(targetUid, { role });
  await db.collection('users').doc(targetUid).update({
    role,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await auth.revokeRefreshTokens(targetUid);

  await writeAuditLog('set_employee_role', 'user', targetUid, callerUid, { role });

  return { ok: true, uid: targetUid, role };
});

/** Replaces a user's project assignments, keeping both sides of the link. */
exports.setEmployeeProjects = onCall(async (request) => {
  const { uid: callerUid } = await requireActiveAdmin(request);
  const targetUid = cleanString(request.data?.uid, 'User id');
  const projectIds = cleanIdList(request.data?.assignedProjectIds, 'Assigned projects');

  const userRef = db.collection('users').doc(targetUid);
  const snap = await userRef.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'That user does not exist.');
  }

  const previous = snap.data().assignedProjectIds || [];
  const added = projectIds.filter((id) => !previous.includes(id));
  const removed = previous.filter((id) => !projectIds.includes(id));

  await userRef.update({
    assignedProjectIds: projectIds,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await Promise.all([
    ...added.map((projectId) =>
      db
        .collection('projects')
        .doc(projectId)
        .update({ assignedEmployeeIds: admin.firestore.FieldValue.arrayUnion(targetUid) })
        .catch(() => null),
    ),
    ...removed.map((projectId) =>
      db
        .collection('projects')
        .doc(projectId)
        .update({ assignedEmployeeIds: admin.firestore.FieldValue.arrayRemove(targetUid) })
        .catch(() => null),
    ),
  ]);

  await writeAuditLog('set_employee_projects', 'user', targetUid, callerUid, { added, removed });

  return { ok: true, uid: targetUid, assignedProjectIds: projectIds };
});

/**
 * Permanently removes an employee: their auth login, their profile and their
 * place on every project.
 *
 * OPTIONAL — the app does not call this. Deleting an employee runs on the
 * client (see EmployeeRepositoryImpl.deleteEmployee) so the project can stay
 * on the free Spark plan; that path cannot remove the auth login, which is
 * the one thing this function adds. Deploy it if you move to Blaze.
 *
 * Their work is never deleted — venues, contacts, activities, visits and notes
 * are handed to the admin doing the deletion, because `assignedEmployeeId` is
 * what the security rules scope every employee query by. Orphaning those
 * documents would leave records no one but an admin could ever read again.
 */
exports.deleteEmployee = onCall(async (request) => {
  const { uid: callerUid } = await requireActiveAdmin(request);
  const targetUid = cleanString(request.data?.uid, 'User id');

  if (targetUid === callerUid) {
    throw new HttpsError('failed-precondition', 'You cannot delete your own account.');
  }

  const userRef = db.collection('users').doc(targetUid);
  const snap = await userRef.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'That user does not exist.');
  }
  const profile = snap.data();

  // Reassign everything that is scoped by employee, in batches. Collections
  // are handled one at a time so a large account cannot blow the 500-write
  // limit of a single batch.
  const reassigned = {};
  for (const collection of ['venues', 'venue_contacts', 'activities', 'visits', 'notes']) {
    let moved = 0;
    for (;;) {
      const page = await db
        .collection(collection)
        .where('assignedEmployeeId', '==', targetUid)
        .limit(400)
        .get();
      if (page.empty) break;

      const batch = db.batch();
      page.docs.forEach((doc) => {
        batch.update(doc.ref, {
          assignedEmployeeId: callerUid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
      moved += page.size;

      if (page.size < 400) break;
    }
    if (moved > 0) reassigned[collection] = moved;
  }

  // Drop them from the reverse index on each project.
  const projectIds = profile.assignedProjectIds || [];
  await Promise.all(
    projectIds.map((projectId) =>
      db
        .collection('projects')
        .doc(projectId)
        .update({
          assignedEmployeeIds: admin.firestore.FieldValue.arrayRemove(targetUid),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        })
        .catch(() => null),
    ),
  );

  // The login goes first: if the profile delete then failed, a sign-in with no
  // profile matches no rule, which is safe. The reverse order would not be.
  await auth.deleteUser(targetUid).catch((error) => {
    if (error.code !== 'auth/user-not-found') throw error;
  });
  await userRef.delete();

  await writeAuditLog('delete_employee', 'user', targetUid, callerUid, {
    email: profile.email || null,
    reassignedTo: callerUid,
    reassigned,
  });

  return { ok: true, uid: targetUid, reassigned };
});

/** Mints a password-reset link an admin can pass to an employee. */
exports.sendPasswordReset = onCall(async (request) => {
  const { uid: callerUid } = await requireActiveAdmin(request);
  const email = cleanEmail(request.data?.email);

  const link = await auth.generatePasswordResetLink(email).catch((error) => {
    throw new HttpsError('not-found', `Could not create a reset link: ${error.message}`);
  });

  await writeAuditLog('send_password_reset', 'user', email, callerUid, {});

  return { ok: true, email, link };
});

// ---------------------------------------------------------------- triggers

/**
 * Mirrors role/status changes made directly on a profile document into the
 * custom claims, so the security rules' cheap claim check never goes stale.
 */
exports.syncUserClaims = onDocumentWritten('users/{userId}', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  const userId = event.params.userId;

  if (!after) return null; // profile removed — nothing to mirror

  const roleChanged = before?.role !== after.role;
  const statusChanged = before?.status !== after.status;
  if (!roleChanged && !statusChanged) return null;

  await auth.setCustomUserClaims(userId, { role: after.role }).catch(() => null);

  if (after.status === 'disabled') {
    await auth.updateUser(userId, { disabled: true }).catch(() => null);
    await auth.revokeRefreshTokens(userId).catch(() => null);
  } else if (statusChanged && after.status === 'active') {
    await auth.updateUser(userId, { disabled: false }).catch(() => null);
  }

  return null;
});

/**
 * Appends a status_history entry whenever a venue's lead status changes,
 * regardless of which client made the change. Writing history server-side is
 * what makes "do not overwrite historical information" actually hold.
 */
exports.recordVenueStatusChange = onDocumentWritten('venues/{venueId}', async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!after || !before) return null;
  if (before.status === after.status) return null;

  await db.collection('status_history').add({
    venueId: event.params.venueId,
    projectId: after.projectId,
    previousStatus: before.status,
    newStatus: after.status,
    changedBy: after.lastStatusChangedBy || after.assignedEmployeeId || 'system',
    reason: after.lastStatusChangeReason || '',
    source: 'trigger',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return null;
});
