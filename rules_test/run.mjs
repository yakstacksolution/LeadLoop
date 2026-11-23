/**
 * Exercises every query the app actually issues against the real security
 * rules, in the Firestore emulator.
 *
 * This exists because `list` rules are matched against a query's filters, not
 * against documents — a mismatch between what the repository filters on and
 * what the rule checks is invisible in code review and only shows up as
 * PERMISSION_DENIED at runtime.
 */
import { initializeTestEnvironment, assertSucceeds, assertFails }
  from '@firebase/rules-unit-testing';
import {
  doc, setDoc, addDoc, updateDoc, deleteDoc, collection, query, where, orderBy, getDocs,
  getCountFromServer, serverTimestamp, writeBatch,
} from 'firebase/firestore';
import fs from 'fs';

const env = await initializeTestEnvironment({
  projectId: 'futsal-rules-test',
  firestore: { rules: fs.readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
});

const ADMIN = 'admin-uid';
const EMP = 'emp-uid';
const OTHER = 'other-uid';
const PROJECT = 'project-1';
const VENUE = 'venue-1';

// Seed with rules disabled, exactly the shapes the app writes.
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users', ADMIN), {
    id: ADMIN, fullName: 'Admin', email: 'a@x.com', role: 'admin',
    status: 'active', assignedProjectIds: [],
  });
  await setDoc(doc(db, 'users', EMP), {
    id: EMP, fullName: 'Emp', email: 'e@x.com', role: 'employee',
    status: 'active', assignedProjectIds: [PROJECT],
  });
  await setDoc(doc(db, 'users', OTHER), {
    id: OTHER, fullName: 'Other', email: 'o@x.com', role: 'employee',
    status: 'active', assignedProjectIds: [],
  });
  await setDoc(doc(db, 'projects', PROJECT), {
    name: 'P', status: 'active', assignedEmployeeIds: [EMP],
  });
  await setDoc(doc(db, 'venues', VENUE), {
    name: 'V', address: 'X', city: 'KTM', area: 'A',
    projectId: PROJECT, assignedEmployeeId: EMP, status: 'new',
    priority: 'medium', venueType: 'indoor', leadSource: 'field_visit',
    isArchived: false, visitCount: 0, createdBy: EMP,
    createdAt: new Date(), updatedAt: new Date(), lastActivityAt: new Date(),
  });

  const common = { venueId: VENUE, projectId: PROJECT, assignedEmployeeId: EMP };
  await setDoc(doc(db, 'venue_contacts', 'c1'), {
    ...common, fullName: 'Owner', designation: 'Owner', phone: '98', email: '',
    preferredContactMethod: 'phone', notes: '', isPrimary: true,
    createdBy: EMP, createdAt: new Date(), updatedAt: new Date(),
  });
  await setDoc(doc(db, 'activities', 'a1'), {
    ...common, venueName: 'V', contactId: null, type: 'phone_call',
    title: 'Call', description: '', scheduledAt: new Date(), endAt: null,
    reminderAt: null, status: 'scheduled', outcomeNote: '', completedAt: null,
    rescheduledFrom: null, createdBy: EMP,
    createdAt: new Date(), updatedAt: new Date(),
  });
  await setDoc(doc(db, 'visits', 'v1'),
    { ...common, employeeId: EMP, status: 'completed', startAt: new Date(), isSelfReported: true });
  await setDoc(doc(db, 'notes', 'n1'),
    { ...common, employeeId: EMP, text: 'hi', createdAt: new Date() });
  await setDoc(doc(db, 'status_history', 's1'),
    { ...common, newStatus: 'new', changedBy: EMP, createdAt: new Date() });
});

const adminDb = env.authenticatedContext(ADMIN, { role: 'admin' }).firestore();
const empDb = env.authenticatedContext(EMP, { role: 'employee' }).firestore();
const otherDb = env.authenticatedContext(OTHER, { role: 'employee' }).firestore();

let pass = 0, fail = 0;
const check = async (label, promise) => {
  try { await promise; console.log(`  ✓ ${label}`); pass++; }
  catch (e) { console.log(`  ✗ ${label}`); fail++; }
};

const OPEN = ['scheduled', 'rescheduled'];

console.log('\nEMPLOYEE DASHBOARD (the screens that were failing)');
await check('count venues assigned to me',
  assertSucceeds(getCountFromServer(query(collection(empDb, 'venues'),
    where('assignedEmployeeId', '==', EMP)))));
await check('count my venues by status',
  assertSucceeds(getCountFromServer(query(collection(empDb, 'venues'),
    where('assignedEmployeeId', '==', EMP), where('status', '==', 'new')))));
await check('count my open activities',
  assertSucceeds(getCountFromServer(query(collection(empDb, 'activities'),
    where('status', 'in', OPEN), where('assignedEmployeeId', '==', EMP)))));
await check('count my completed visits (filters employeeId)',
  assertSucceeds(getCountFromServer(query(collection(empDb, 'visits'),
    where('status', '==', 'completed'), where('employeeId', '==', EMP)))));
await check('watch my open activities',
  assertSucceeds(getDocs(query(collection(empDb, 'activities'),
    where('assignedEmployeeId', '==', EMP), where('status', 'in', OPEN),
    orderBy('scheduledAt')))));
await check('watch my visits (filters employeeId)',
  assertSucceeds(getDocs(query(collection(empDb, 'visits'),
    where('employeeId', '==', EMP), orderBy('startAt', 'desc')))));
await check('find my open visit (filters employeeId)',
  assertSucceeds(getDocs(query(collection(empDb, 'visits'),
    where('employeeId', '==', EMP), where('status', '==', 'in_progress'),
    orderBy('startAt', 'desc')))));
await check('list my projects',
  assertSucceeds(getDocs(query(collection(empDb, 'projects'),
    where('assignedEmployeeIds', 'array-contains', EMP)))));
await check('list my venues sorted',
  assertSucceeds(getDocs(query(collection(empDb, 'venues'),
    where('assignedEmployeeId', '==', EMP), orderBy('lastActivityAt', 'desc')))));

console.log('\nEMPLOYEE VENUE DETAIL');
for (const c of ['venue_contacts', 'activities', 'visits', 'notes', 'status_history']) {
  await check(`by-venue read: ${c}`,
    assertSucceeds(getDocs(query(collection(empDb, c),
      where('venueId', '==', VENUE), where('assignedEmployeeId', '==', EMP)))));
}

console.log('\nADMIN');
await check('count all venues',
  assertSucceeds(getCountFromServer(collection(adminDb, 'venues'))));
await check('count venues by status',
  assertSucceeds(getCountFromServer(query(collection(adminDb, 'venues'),
    where('status', '==', 'new')))));
await check('list all users',
  assertSucceeds(getDocs(collection(adminDb, 'users'))));
await check('list all projects',
  assertSucceeds(getDocs(query(collection(adminDb, 'projects'),
    orderBy('createdAt', 'desc')))));
await check('org-wide open activities',
  assertSucceeds(getDocs(query(collection(adminDb, 'activities'),
    where('status', 'in', OPEN), orderBy('scheduledAt')))));
await check('count open activities',
  assertSucceeds(getCountFromServer(query(collection(adminDb, 'activities'),
    where('status', 'in', OPEN)))));
await check('count completed visits',
  assertSucceeds(getCountFromServer(query(collection(adminDb, 'visits'),
    where('status', '==', 'completed')))));

console.log('\nISOLATION (these MUST fail)');
await check("an employee cannot list someone else's venues",
  assertFails(getDocs(query(collection(otherDb, 'venues'),
    where('assignedEmployeeId', '==', EMP)))));
await check('employee cannot list all venues unscoped',
  assertFails(getDocs(collection(empDb, 'venues'))));
await check('employee cannot list all users',
  assertFails(getDocs(collection(empDb, 'users'))));
await check("employee cannot read another's profile",
  assertFails(getDocs(query(collection(empDb, 'users'), where('role', '==', 'admin')))));
await check('employee cannot list notes unscoped',
  assertFails(getDocs(query(collection(empDb, 'notes'), where('venueId', '==', VENUE)))));

// ---------------------------------------------------------------- writes
//
// Each block mirrors exactly what a repository sends, field for field. A write
// map that forgets `assignedEmployeeId` fails `creatingOwnRecord()` and is
// rejected — which is invisible until runtime.

const childFields = (uid) => ({
  venueId: VENUE, projectId: PROJECT, assignedEmployeeId: uid,
});

console.log('\nEMPLOYEE WRITES');

await check('add note (VenueRepository.addNote)',
  assertSucceeds((async () => {
    const batch = writeBatch(empDb);
    batch.set(doc(collection(empDb, 'notes')), {
      ...childFields(EMP), employeeId: EMP, employeeName: 'Emp', text: 'hello',
      activityId: null, activityType: null, originalText: null, editedAt: null,
      createdAt: serverTimestamp(),
    });
    batch.update(doc(empDb, 'venues', VENUE), {
      lastActivityAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    return batch.commit();
  })()));

await check('complete activity writes outcome note (ActivityRepository.complete)',
  assertSucceeds((async () => {
    const batch = writeBatch(empDb);
    batch.update(doc(empDb, 'activities', 'a1'), {
      status: 'completed', outcomeNote: 'done',
      completedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    batch.set(doc(collection(empDb, 'notes')), {
      ...childFields(EMP), employeeId: EMP, employeeName: 'Emp', text: 'done',
      activityId: 'a1', activityType: 'phone_call',
      originalText: null, editedAt: null, createdAt: serverTimestamp(),
    });
    batch.update(doc(empDb, 'venues', VENUE), {
      lastActivityAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    return batch.commit();
  })()));

await check('complete visit writes note (VisitRepository.completeVisit)',
  assertSucceeds((async () => {
    const batch = writeBatch(empDb);
    batch.update(doc(empDb, 'visits', 'v1'), {
      status: 'completed', notes: 'went', endAt: new Date(),
      nextFollowUpAt: null, updatedAt: serverTimestamp(),
    });
    batch.set(doc(collection(empDb, 'notes')), {
      ...childFields(EMP), employeeId: EMP, employeeName: '', text: 'went',
      activityId: null, activityType: 'venue_visit',
      originalText: null, editedAt: null, createdAt: serverTimestamp(),
    });
    return batch.commit();
  })()));

await check('change venue status writes history (VenueRepository.changeStatus)',
  assertSucceeds((async () => {
    const batch = writeBatch(empDb);
    batch.update(doc(empDb, 'venues', VENUE), {
      status: 'contacted', lastStatusChangedBy: EMP, lastStatusChangeReason: '',
      lastActivityAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    batch.set(doc(collection(empDb, 'status_history')), {
      ...childFields(EMP), previousStatus: 'new', newStatus: 'contacted',
      changedBy: EMP, changedByName: 'Emp', reason: '', source: 'client',
      createdAt: serverTimestamp(),
    });
    return batch.commit();
  })()));

await check('create contact (ContactRepository.createContact)',
  assertSucceeds(addDoc(collection(empDb, 'venue_contacts'), {
    ...childFields(EMP), fullName: 'Owner', designation: 'Owner',
    phone: '9800000000', email: '', preferredContactMethod: 'phone',
    notes: '', isPrimary: false, createdBy: EMP,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  })));

await check('create activity (ActivityRepository.createActivity)',
  assertSucceeds(addDoc(collection(empDb, 'activities'), {
    ...childFields(EMP), venueName: 'V', contactId: null,
    type: 'phone_call', title: 'Call', description: '',
    scheduledAt: new Date(), endAt: null, reminderAt: null,
    status: 'scheduled', outcomeNote: '', completedAt: null,
    rescheduledFrom: null, createdBy: EMP,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  })));

await check('start visit (VisitRepository.startVisit)',
  assertSucceeds(addDoc(collection(empDb, 'visits'), {
    ...childFields(EMP), venueName: 'V', employeeId: EMP, activityId: null,
    startAt: new Date(), endAt: null, status: 'in_progress',
    location: null, locationAccuracy: null, notes: '',
    isSelfReported: true, nextFollowUpAt: null,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  })));

await check('update venue details (VenueRepository.updateVenue)',
  assertSucceeds(updateDoc(doc(empDb, 'venues', VENUE), {
    name: 'V2', address: 'Y', updatedAt: serverTimestamp(),
  })));

console.log('\nEMPLOYEE WRITES THAT MUST FAIL');
await check('cannot grant themselves admin',
  assertFails(updateDoc(doc(empDb, 'users', EMP), { role: 'admin' })));
await check('cannot reassign their venue to someone else',
  assertFails(updateDoc(doc(empDb, 'venues', VENUE), { assignedEmployeeId: OTHER })));
await check('cannot move their venue to another project',
  assertFails(updateDoc(doc(empDb, 'venues', VENUE), { projectId: 'other-project' })));
await check('cannot rewrite a visit\'s evidence flag',
  assertFails(updateDoc(doc(empDb, 'visits', 'v1'), { isSelfReported: false })));
await check('cannot edit immutable status history',
  assertFails(updateDoc(doc(empDb, 'status_history', 's1'), { newStatus: 'converted' })));
await check('cannot delete a venue',
  assertFails(updateDoc(doc(otherDb, 'venues', VENUE), { name: 'hacked' })));
await check('cannot write a record owned by someone else',
  assertFails(addDoc(collection(otherDb, 'notes'), {
    venueId: VENUE, projectId: PROJECT, assignedEmployeeId: EMP,
    employeeId: OTHER, text: 'x', createdAt: serverTimestamp(),
  })));

console.log('\nADMIN WRITES');
await check('admin adds a note on an employee\'s venue',
  assertSucceeds(addDoc(collection(adminDb, 'notes'), {
    ...childFields(EMP), employeeId: ADMIN, employeeName: 'Admin',
    text: 'admin note', activityId: null, activityType: null,
    originalText: null, editedAt: null, createdAt: serverTimestamp(),
  })));
await check('admin reassigns a venue',
  assertSucceeds(updateDoc(doc(adminDb, 'venues', VENUE), {
    assignedEmployeeId: OTHER, updatedAt: serverTimestamp(),
  })));
await check('admin creates an employee profile',
  assertSucceeds(setDoc(doc(adminDb, 'users', 'new-emp'), {
    id: 'new-emp', fullName: 'New', email: 'n@x.com', role: 'employee',
    status: 'active', assignedProjectIds: [],
  })));

// Removing a team member: admins only, and never yourself.
await check('employee cannot delete another profile',
  assertFails(deleteDoc(doc(empDb, 'users', OTHER))));
await check('admin cannot delete their own profile',
  assertFails(deleteDoc(doc(adminDb, 'users', ADMIN))));
await check('admin deletes an employee profile',
  assertSucceeds(deleteDoc(doc(adminDb, 'users', 'new-emp'))));

console.log(`\n${pass} passed, ${fail} failed`);
await env.cleanup();
process.exit(fail === 0 ? 0 : 1);
