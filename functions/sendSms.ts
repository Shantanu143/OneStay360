import * as functions from 'firebase-functions';

export type SmsPayload = {
  to: string; // E.164 phone number e.g. +919876543210
  message: string;
};

export interface SmsProviderConfig {
  provider?: 'twilio' | 'msg91' | 'webhook' | 'mock';
  twilio?: {
    accountSid: string;
    authToken: string;
    fromPhone: string;
  };
  msg91?: {
    authKey: string;
    templateId: string;
    senderId?: string;
  };
  webhookUrl?: string;
}

/**
 * Pluggable SMS delivery engine supporting Twilio, MSG91, generic HTTP webhooks,
 * or simulated execution when credentials are not configured in the environment.
 */
export async function sendSms(payload: SmsPayload): Promise<{ success: boolean; provider: string; messageId?: string }> {
  const { to, message } = payload;
  if (!to || !message) {
    throw new Error('Both "to" phone number and "message" are required for SMS delivery.');
  }

  // Check environment variables
  const twilioSid = process.env.TWILIO_ACCOUNT_SID;
  const twilioAuth = process.env.TWILIO_AUTH_TOKEN;
  const twilioFrom = process.env.TWILIO_FROM_PHONE;

  const msg91AuthKey = process.env.MSG91_AUTH_KEY;
  const msg91TemplateId = process.env.MSG91_TEMPLATE_ID;

  const webhookUrl = process.env.SMS_WEBHOOK_URL;

  // 1. Twilio Provider
  if (twilioSid && twilioAuth && twilioFrom) {
    try {
      const authHeader = `Basic ${Buffer.from(`${twilioSid}:${twilioAuth}`).toString('base64')}`;
      const bodyParams = new URLSearchParams({
        To: to,
        From: twilioFrom,
        Body: message,
      });

      const resp = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${twilioSid}/Messages.json`,
        {
          method: 'POST',
          headers: {
            Authorization: authHeader,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: bodyParams.toString(),
        }
      );

      const data = (await resp.json()) as any;
      if (!resp.ok) {
        throw new Error(data.message || `Twilio SMS request failed with HTTP ${resp.status}`);
      }

      functions.logger.info('sms_sent_twilio', { to, messageId: data.sid });
      return { success: true, provider: 'twilio', messageId: data.sid };
    } catch (err: any) {
      functions.logger.error('sms_failed_twilio', { to, error: err.message });
      throw err;
    }
  }

  // 2. MSG91 Provider
  if (msg91AuthKey && msg91TemplateId) {
    try {
      const resp = await fetch('https://control.msg91.com/api/v5/flow/', {
        method: 'POST',
        headers: {
          authkey: msg91AuthKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          template_id: msg91TemplateId,
          mobiles: to.replace('+', ''),
          var1: message,
        }),
      });

      const data = (await resp.json()) as any;
      if (!resp.ok || data.type === 'error') {
        throw new Error(data.message || `MSG91 SMS request failed with HTTP ${resp.status}`);
      }

      functions.logger.info('sms_sent_msg91', { to, response: data });
      return { success: true, provider: 'msg91', messageId: data.request_id };
    } catch (err: any) {
      functions.logger.error('sms_failed_msg91', { to, error: err.message });
      throw err;
    }
  }

  // 3. Webhook Provider
  if (webhookUrl) {
    try {
      const resp = await fetch(webhookUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ to, message, timestamp: new Date().toISOString() }),
      });

      if (!resp.ok) {
        throw new Error(`SMS webhook returned HTTP ${resp.status}`);
      }

      functions.logger.info('sms_sent_webhook', { to, url: webhookUrl });
      return { success: true, provider: 'webhook' };
    } catch (err: any) {
      functions.logger.error('sms_failed_webhook', { to, error: err.message });
      throw err;
    }
  }

  // Fallback: Safe Mock / Log for dev & staging environments
  functions.logger.warn('sms_not_configured_simulated', {
    to,
    messageLength: message.length,
    hint: 'Set TWILIO_ACCOUNT_SID, MSG91_AUTH_KEY, or SMS_WEBHOOK_URL to activate real SMS dispatch.',
  });

  return { success: true, provider: 'mock' };
}

