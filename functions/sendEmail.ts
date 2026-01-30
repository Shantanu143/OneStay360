import * as functions from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
import Mailgun from 'mailgun.js';
import FormData from 'form-data';

export type EmailPayload = {
  to: string;
  subject: string;
  html: string;
  text?: string;
};

const MAILGUN_API_KEY = defineSecret('MAILGUN_API_KEY');
const MAILGUN_DOMAIN = defineSecret('MAILGUN_DOMAIN');
const MAILGUN_FROM = defineSecret('MAILGUN_FROM');
const MAILGUN_API_BASE = defineSecret('MAILGUN_API_BASE'); // optional, default US

// Best-effort transactional email sender using Mailgun sandbox. Never throws to callers.
export async function sendEmail(payload: EmailPayload): Promise<void> {
  const apiKey = MAILGUN_API_KEY.value();
  const domain = MAILGUN_DOMAIN.value();
  const from = MAILGUN_FROM.value();
  const apiBase = MAILGUN_API_BASE.value() || 'https://api.mailgun.net';

  if (!apiKey || !domain || !from) {
    functions.logger.error('email_missing_mailgun_config', {
      hasKey: Boolean(apiKey),
      hasDomain: Boolean(domain),
      hasFrom: Boolean(from),
    });
    return;
  }

  try {
    const mg = new Mailgun(FormData).client({ username: 'api', key: apiKey, url: apiBase });
    const response = await mg.messages.create(domain, {
      from,
      to: payload.to,
      subject: payload.subject,
      html: payload.html,
      text: payload.text,
    });
    functions.logger.info('email_sent', { to: payload.to, subject: payload.subject, id: (response as any)?.id });
  } catch (error) {
    functions.logger.error('email_failed', {
      to: payload.to,
      error,
    });
  }
}

export function buildWelcomeEmail(options: {
  businessName: string;
  propertyName: string;
  planName: string;
  activationDate: string;
  to: string;
}): EmailPayload {
  const { businessName, propertyName, planName, activationDate, to } = options;
  const subject = '🎉 Your property is now live on OneStay360';
  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>Welcome to OneStay360</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f6f9fc; margin: 0; padding: 0; }
    .container { max-width: 640px; margin: 0 auto; background: #ffffff; padding: 24px; border-radius: 12px; }
    .banner { text-align: center; margin-bottom: 16px; }
    .banner img { max-width: 220px; }
    .title { font-size: 22px; font-weight: 700; margin: 0 0 12px; }
    .body { font-size: 15px; color: #1f2937; line-height: 1.6; }
    .list { margin: 12px 0 16px; padding-left: 20px; }
    .footer { margin-top: 24px; font-size: 13px; color: #6b7280; }
  </style>
</head>
<body>
  <div class="container">
    <div class="banner">
      <img src="https://onestay360.com/logo.png" alt="OneStay360" />
    </div>
    <div class="title">Welcome to OneStay360 🎉</div>
    <div class="body">
      <p>Hi ${businessName},</p>
      <p>Your property ${propertyName} has been successfully activated on OneStay360.</p>
      <p><strong>Plan:</strong> ${planName}<br/>
         <strong>Activated on:</strong> ${activationDate}</p>
      <p>You can now:</p>
      <ul class="list">
        <li>Manage rooms and beds</li>
        <li>Track tenants and occupancy</li>
        <li>Handle billing and renewals from your dashboard</li>
      </ul>
      <p>If you need any help, just reply to this email — we’re here to help.</p>
      <p class="footer">— Team OneStay360<br/>https://onestay360.com</p>
    </div>
  </div>
</body>
</html>`;

  return { to, subject, html };
}

export function buildInvitationEmail(options: {
  businessName: string;
  inviterName: string;
  role: 'owner' | 'manager' | 'staff';
  propertyNames: string[];
  inviteLink: string;
  expiresOn: string;
  to: string;
}): EmailPayload {
  const { businessName, inviterName, role, propertyNames, inviteLink, expiresOn, to } = options;
  const subject = `You’ve been invited to join ${businessName} on OneStay360`;
  const propertiesList = propertyNames.length ? propertyNames.join(', ') : 'No properties assigned';
  const roleLabel = role === 'owner'
    ? 'Owner'
    : role === 'manager'
        ? 'Manager'
        : 'Staff';

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Invitation</title>
  <style>
    body { margin:0; padding:0; background:#f5f7fb; font-family: 'Segoe UI', Arial, sans-serif; color:#0f172a; }
    .wrapper { width:100%; padding:16px; }
    .card { max-width:640px; margin:0 auto; background:#ffffff; border-radius:16px; padding:24px; box-shadow:0 4px 24px rgba(15,23,42,0.08); }
    .header { font-size:22px; font-weight:700; margin:0 0 8px; }
    .sub { color:#475569; margin:0 0 16px; }
    .badge { display:inline-block; padding:6px 12px; border-radius:999px; background:#ecfeff; color:#0ea5e9; font-weight:600; font-size:13px; letter-spacing:0.2px; }
    .section-title { margin:20px 0 8px; font-weight:700; font-size:16px; }
    .list { margin:0 0 16px; padding:0; color:#1f2937; }
    .cta { display:inline-block; padding:12px 18px; background:#0f766e; color:#ffffff; text-decoration:none; border-radius:10px; font-weight:600; }
    .footer { margin-top:24px; font-size:13px; color:#64748b; line-height:1.5; }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="card">
      <div class="header">You’re invited to join ${businessName}</div>
      <p class="sub">${inviterName} invited you to collaborate on OneStay360.</p>
      <div class="badge">Role: ${roleLabel}</div>

      <div class="section-title">Assigned properties</div>
      <p class="list">${propertiesList}</p>

      <p><a href="${inviteLink}" class="cta">Accept Invitation</a></p>

      <div class="footer">
        This invitation expires on <strong>${expiresOn}</strong>.<br/>
        If you weren’t expecting this, you can safely ignore the email.
      </div>
    </div>
  </div>
</body>
</html>`;

  const text = `You're invited to join ${businessName} as ${roleLabel}. Properties: ${propertiesList}. Accept: ${inviteLink}. Expires on ${expiresOn}.`;

  return { to, subject, html, text };
}
