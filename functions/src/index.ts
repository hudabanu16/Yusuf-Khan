import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";

admin.initializeApp();
const db = admin.firestore();

const gmailUser = defineSecret("QUIK_GMAIL_USER");
const gmailPass = defineSecret("QUIK_GMAIL_APP_PASSWORD");

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

/**
 * Generates a 6-digit OTP code.
 * @return {string}
 */
function generateOtp(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

export const sendWorkspaceOtp = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const email = (request.data?.email ?? "").toString().trim().toLowerCase();
    const password = (request.data?.password ?? "").toString();
    const displayName = (request.data?.displayName ?? "").toString();
    const logoUrl = (request.data?.logoUrl ?? "").toString();
    const companyData = request.data?.companyData ?? {};
    const adminPermissions = request.data?.adminPermissions ?? {};

    if (!email) {
      throw new HttpsError("invalid-argument", "Email required");
    }

    if (!password) {
      throw new HttpsError("invalid-argument", "Password required");
    }

    const registrationRef = db.collection("workspace_registrations").doc();
    const otp = generateOtp();

    await registrationRef.set({
      registrationId: registrationRef.id,
      email,
      password,
      displayName,
      logoUrl,
      companyData,
      adminPermissions,
      otp,
      verified: false,
      status: "pending_email_verification",
      otpSentCount: 1,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const transporter = buildTransporter();

    await transporter.sendMail({
      from: `"QUIK ERP" <${gmailUser.value()}>`,
      to: email,
      subject: "QUIK ERP - Email Verification OTP",
      text: `Your OTP is: ${otp}`,
    });

    return {
      success: true,
      registrationId: registrationRef.id,
    };
  },
);

export const resendWorkspaceOtp = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const registrationId =
      (request.data?.registrationId ?? "").toString().trim();

    if (!registrationId) {
      throw new HttpsError("invalid-argument", "Registration ID required");
    }

    const registrationRef = db
      .collection("workspace_registrations")
      .doc(registrationId);
    const snap = await registrationRef.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Registration not found");
    }

    const data = snap.data() || {};
    const email = (data.email ?? "").toString().trim().toLowerCase();

    if (!email) {
      throw new HttpsError("failed-precondition", "Email missing in draft");
    }

    const otp = generateOtp();

    await registrationRef.update({
      otp,
      otpSentCount: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const transporter = buildTransporter();

    await transporter.sendMail({
      from: `"QUIK ERP" <${gmailUser.value()}>`,
      to: email,
      subject: "QUIK ERP - Email Verification OTP",
      text: `Your OTP is: ${otp}`,
    });

    return {success: true};
  },
);

export const verifyWorkspaceOtpAndCreateWorkspace = onCall(
  {secrets: [gmailUser, gmailPass]},
  async (request) => {
    const registrationId =
      (request.data?.registrationId ?? "").toString().trim();
    const otp =
      (request.data?.otp ?? "").toString().trim();

    if (!registrationId) {
      throw new HttpsError("invalid-argument", "Registration ID required");
    }

    if (!otp) {
      throw new HttpsError("invalid-argument", "OTP required");
    }

    const registrationRef = db
      .collection("workspace_registrations")
      .doc(registrationId);
    const snap = await registrationRef.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Registration not found");
    }

    const data = snap.data() || {};

    if ((data.otp ?? "").toString() !== otp) {
      throw new HttpsError("invalid-argument", "Invalid OTP");
    }

    const companyId = db.collection("companies").doc().id;

    await registrationRef.update({
      verified: true,
      status: "otp_verified",
      companyId,
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      email: data.email ?? "",
      password: data.password ?? "",
      displayName: data.displayName ?? "",
      logoUrl: data.logoUrl ?? "",
      companyData: data.companyData ?? {},
      adminPermissions: data.adminPermissions ?? {},
      companyId,
    };
  },
);
