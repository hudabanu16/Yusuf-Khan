import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";

admin.initializeApp();
const db = admin.firestore();

/* ===================== SECRETS ===================== */

const gmailUser = defineSecret("QUIK_GMAIL_USER");
const gmailPass = defineSecret("QUIK_GMAIL_APP_PASSWORD");

/* ===================== HELPERS ===================== */

/**
 * Generates a 6-digit OTP.
 * @return {string}
 */
function generateOtp(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Builds the Gmail transporter for OTP emails.
 * @return {nodemailer.Transporter}
 */
function buildTransporter() {
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: gmailUser.value(),
      pass: gmailPass.value(),
    },
  });
}

/* =========================================================
   ================= WORKSPACE OTP ==========================
   ========================================================= */

export const sendWorkspaceOtp = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const email =
      (request.data?.email ?? "").toString().trim().toLowerCase();

    if (!email) {
      throw new HttpsError("invalid-argument", "Email required");
    }

    const otp = generateOtp();
    const draftRef = db.collection("workspace_requests").doc();

    await draftRef.set({
      draftId: draftRef.id,
      email,
      otp,
      verified: false,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const transporter = buildTransporter();

    await transporter.sendMail({
      from: `"QUIK ERP" <${gmailUser.value()}>`,
      to: email,
      subject: "QUIK ERP - Workspace Verification OTP",
      text: `Your OTP is: ${otp}`,
    });

    return {draftId: draftRef.id};
  },
);

export const verifyWorkspaceOtpAndCreateWorkspace = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const draftId = request.data?.draftId;
    const otp = request.data?.otp;

    if (!draftId || !otp) {
      throw new HttpsError("invalid-argument", "Missing data");
    }

    const ref = db.collection("workspace_requests").doc(draftId);
    const snap = await ref.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Draft not found");
    }

    const data = snap.data() || {};

    if (data.otp !== otp) {
      throw new HttpsError("invalid-argument", "Invalid OTP");
    }

    await ref.update({
      verified: true,
      status: "verified",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {success: true};
  },
);

/* =========================================================
   ================= JOIN COMPANY OTP =======================
   ========================================================= */

export const sendJoinCompanyOtp = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const inviteCode =
      (request.data?.inviteCode ?? "").toString().trim().toUpperCase();
    const fullName = (request.data?.fullName ?? "").toString().trim();
    const email =
      (request.data?.email ?? "").toString().trim().toLowerCase();
    const password = (request.data?.password ?? "").toString();

    if (!inviteCode) {
      throw new HttpsError("invalid-argument", "Invite code required");
    }

    if (!fullName) {
      throw new HttpsError("invalid-argument", "Full name required");
    }

    if (!email) {
      throw new HttpsError("invalid-argument", "Email required");
    }

    if (!password) {
      throw new HttpsError("invalid-argument", "Password required");
    }

    const inviteQuery = await db
      .collectionGroup("invites")
      .where("code", "==", inviteCode)
      .where("status", "==", "pending")
      .where("isActive", "==", true)
      .limit(1)
      .get();

    if (inviteQuery.empty) {
      throw new HttpsError(
        "not-found",
        "Invalid or already used invite code",
      );
    }

    const inviteDoc = inviteQuery.docs[0];
    const inviteData = inviteDoc.data();
    const companyRef = inviteDoc.ref.parent.parent;

    if (!companyRef) {
      throw new HttpsError("failed-precondition", "Company not found");
    }

    const companySnap = await companyRef.get();
    const companyData = companySnap.data() || {};

    const companyName =
      (companyData.companyName ?? companyData.name ?? "")
        .toString()
        .trim();

    const inviteEmail =
      (inviteData.email ?? "").toString().trim().toLowerCase();

    if (inviteEmail && inviteEmail !== email) {
      throw new HttpsError(
        "permission-denied",
        "Invite is for another email",
      );
    }

    const otp = generateOtp();
    const draftRef = db.collection("join_company_requests").doc();

    await draftRef.set({
      draftId: draftRef.id,
      inviteCode,
      inviteId: inviteDoc.id,
      companyId: companyRef.id,
      companyName,
      fullName,
      email,
      password,
      role: inviteData.role ?? "sales",
      isAdmin: inviteData.role === "admin",
      phone: inviteData.phone ?? "",
      permissions: inviteData.permissions ?? {},
      verified: false,
      status: "pending",
      otp,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const transporter = buildTransporter();

    await transporter.sendMail({
      from: `"QUIK ERP" <${gmailUser.value()}>`,
      to: email,
      subject: "QUIK ERP - Join Company OTP",
      text: `Your OTP is: ${otp}`,
    });

    return {draftId: draftRef.id};
  },
);

export const resendJoinCompanyOtp = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const draftId = request.data?.draftId;

    if (!draftId) {
      throw new HttpsError("invalid-argument", "Draft ID required");
    }

    const ref = db.collection("join_company_requests").doc(draftId);
    const snap = await ref.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Draft not found");
    }

    const data = snap.data() || {};
    const email = data.email;

    const otp = generateOtp();

    await ref.update({
      otp,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const transporter = buildTransporter();

    await transporter.sendMail({
      from: `"QUIK ERP" <${gmailUser.value()}>`,
      to: email,
      subject: "QUIK ERP - Resend OTP",
      text: `Your OTP is: ${otp}`,
    });

    return {success: true};
  },
);

export const verifyJoinCompanyOtp = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const draftId = request.data?.draftId;
    const otp = request.data?.otp;

    if (!draftId || !otp) {
      throw new HttpsError("invalid-argument", "Missing data");
    }

    const ref = db.collection("join_company_requests").doc(draftId);
    const snap = await ref.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Draft not found");
    }

    const data = snap.data() || {};

    if (data.otp !== otp) {
      throw new HttpsError("invalid-argument", "Invalid OTP");
    }

    await ref.update({
      verified: true,
      status: "verified",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      email: data.email,
      password: data.password,
      fullName: data.fullName,
      companyId: data.companyId,
      companyName: data.companyName,
      inviteId: data.inviteId,
      role: data.role,
      isAdmin: data.isAdmin,
      phone: data.phone,
      permissions: data.permissions,
    };
  },
);
