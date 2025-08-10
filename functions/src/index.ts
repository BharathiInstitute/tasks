/**
 * Firebase Functions (v2) entrypoint.
 * Defines a callable to upsert Firebase Auth users from the Flutter app.
 */

import {setGlobalOptions} from "firebase-functions/v2/options";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import admin from "firebase-admin";

// Initialize Admin SDK exactly once.
if (!admin.apps.length) {
	admin.initializeApp();
}

setGlobalOptions({
	region: "asia-south1",
	maxInstances: 10,
});

type UpsertUserInput = {
	email: string;
	password?: string;
	displayName?: string;
	uid?: string;
};

type UpsertUserOutput = {
	ok: boolean;
	action: "created" | "updated";
	uid: string;
	email: string;
};

/**
 * Callable: adminUpsertUser
 * Creates or updates a Firebase Auth user. Returns plain JSON (web-safe).
 */
export const adminUpsertUser = onCall(async (request) => {
	const data = (request.data || {}) as UpsertUserInput;
	const email = (data.email || "").trim().toLowerCase();
	const password = data.password?.trim();
	const displayName = data.displayName?.trim();
	const explicitUid = data.uid?.trim();

	if (!email) {
		throw new Error("email is required");
	}

	// Find existing user by explicit UID or by email
	let existingUid: string | undefined = explicitUid;
	if (!existingUid) {
		try {
			const user = await admin.auth().getUserByEmail(email);
			existingUid = user.uid;
		} catch (_err) {
			// Not found -> will create
		}
	}

	if (existingUid) {
		// Update
		const update: admin.auth.UpdateRequest = {};
		if (email) {
			update.email = email;
		}
		if (displayName !== undefined) {
			update.displayName = displayName;
		}
		if (password) {
			update.password = password;
		}
		const updated = await admin.auth().updateUser(existingUid, update);
		const res: UpsertUserOutput = {
			ok: true,
			action: "updated",
			uid: updated.uid,
			email: updated.email || email,
		};
		return res;
	}

	// Create
	const created = await admin.auth().createUser({
		email,
		password: password || undefined,
		displayName: displayName || undefined,
		disabled: false,
	});
	const res: UpsertUserOutput = {
		ok: true,
		action: "created",
		uid: created.uid,
		email,
	};
	return res;
});

/**
 * Auth trigger: when a user is created, seed a role in custom claims.
 * If no admin exists yet, the first user becomes admin; otherwise employee.
 * Also writes a users/{uid} profile doc for convenience.
 */
/**
 * Bootstrap callable: If no admin exists, the caller becomes admin.
 * Safe to deploy anytime; after an admin exists it will refuse.
 */
export const seedFirstAdmin = onCall(async (request) => {
	if (!request.auth) {
		throw new HttpsError("unauthenticated", "Sign in required.");
	}
	const auth = admin.auth();
	// Check if any admin exists already
	let anyAdmin = false;
	let nextPageToken: string | undefined = undefined;
	do {
		const list = await auth.listUsers(1000, nextPageToken);
		anyAdmin = list.users.some((u) => (u.customClaims as any)?.role === "admin");
		nextPageToken = list.pageToken;
	} while (!anyAdmin && nextPageToken);
	if (anyAdmin) {
		throw new HttpsError("failed-precondition", "An admin already exists.");
	}
	await auth.setCustomUserClaims(request.auth.uid, {role: "admin"});
	await admin.firestore().doc(`users/${request.auth.uid}`).set({
		role: "admin",
		roleSeededAt: admin.firestore.FieldValue.serverTimestamp(),
	}, {merge: true});
	return {ok: true, role: "admin"};
});

/**
 * Admin-only callable to set a user's role (custom claim) by email.
 */
export const setRoleByEmail = onCall(async (request) => {
	const ctx = request.auth;
	if (!ctx || (ctx.token as any)?.role !== "admin") {
		throw new HttpsError("permission-denied", "Admins only.");
	}

	const data = (request.data || {}) as {email?: string; role?: string};
	const email = (data.email || "").trim().toLowerCase();
	const role = (data.role || "").trim().toLowerCase();
	if (!email || (role !== "admin" && role !== "employee")) {
		throw new HttpsError("invalid-argument", "Provide email and role=admin|employee");
	}

	const auth = admin.auth();
	const db = admin.firestore();
	let userRecord;
	try {
		userRecord = await auth.getUserByEmail(email);
	} catch (_err) {
		throw new HttpsError("not-found", "No user with that email.");
	}

	await auth.setCustomUserClaims(userRecord.uid, {role});
	await db.doc(`users/${userRecord.uid}`).set({
		roleChangedAt: admin.firestore.FieldValue.serverTimestamp(),
		role,
	}, {merge: true});

	return {uid: userRecord.uid, email, role};
});
