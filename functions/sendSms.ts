import * as functions from 'firebase-functions';

export type SmsPayload = {
  to: string; // E.164 phone number
  message: string;
};

// Stub transport: replace with real SMS provider (Twilio, MSG91, etc.).
export async function sendSms(payload: SmsPayload): Promise<void> {
  try {
    functions.logger.info('sms_stub_send', payload);
  } catch (err) {
    functions.logger.error('sms_stub_failed', { error: err, to: payload.to });
    throw err;
  }
}
