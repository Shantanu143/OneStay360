"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendWhatsAppTemplate = sendWhatsAppTemplate;
exports.sendWhatsAppText = sendWhatsAppText;
const functions = __importStar(require("firebase-functions"));
function getWhatsAppConfig() {
    const config = functions.config();
    return {
        phoneNumberId: config.whatsapp?.phone_number_id || process.env.WHATSAPP_PHONE_NUMBER_ID || '',
        accessToken: config.whatsapp?.access_token || process.env.WHATSAPP_ACCESS_TOKEN || '',
    };
}
/**
 * Send WhatsApp template message (for transactional messages)
 * Templates must be pre-approved by Meta
 */
async function sendWhatsAppTemplate(payload) {
    const { phoneNumberId, accessToken } = getWhatsAppConfig();
    // Normalize phone number - ensure it starts with country code
    let phone = payload.to.replace(/\D/g, '');
    if (phone.length === 10) {
        phone = '91' + phone; // Default to India
    }
    if (!phone.startsWith('91') && phone.length === 10) {
        phone = '91' + phone;
    }
    // If not configured, log and return (for development)
    if (!phoneNumberId || !accessToken) {
        functions.logger.info('📱 WhatsApp (DEV MODE - not configured):', {
            to: phone,
            template: payload.templateName,
            params: payload.templateParams,
        });
        console.log(`\n📱 WHATSAPP MESSAGE (would be sent):`);
        console.log(`   To: +${phone}`);
        console.log(`   Template: ${payload.templateName}`);
        console.log(`   Params: ${JSON.stringify(payload.templateParams)}`);
        console.log(`\n   To enable: firebase functions:config:set whatsapp.phone_number_id="..." whatsapp.access_token="..."\n`);
        return true; // Return true in dev mode so flow continues
    }
    try {
        const url = `https://graph.facebook.com/v18.0/${phoneNumberId}/messages`;
        const body = {
            messaging_product: 'whatsapp',
            to: phone,
            type: 'template',
            template: {
                name: payload.templateName,
                language: {
                    code: payload.languageCode || 'en',
                },
            },
        };
        // Add parameters if provided
        if (payload.templateParams && payload.templateParams.length > 0) {
            body.template.components = [{
                    type: 'body',
                    parameters: payload.templateParams.map(param => ({
                        type: 'text',
                        text: param,
                    })),
                }];
        }
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(body),
        });
        const result = await response.json();
        if (!response.ok) {
            functions.logger.error('WhatsApp API error:', result);
            throw new Error(result.error?.message || 'WhatsApp API error');
        }
        functions.logger.info('✅ WhatsApp sent:', { to: phone, messageId: result.messages?.[0]?.id });
        return true;
    }
    catch (error) {
        functions.logger.error('❌ WhatsApp send failed:', error);
        throw error;
    }
}
/**
 * Send plain text WhatsApp message
 * Note: This only works for messages within 24-hour window of user-initiated conversation
 * For cold outreach, use templates
 */
async function sendWhatsAppText(payload) {
    const { phoneNumberId, accessToken } = getWhatsAppConfig();
    let phone = payload.to.replace(/\D/g, '');
    if (phone.length === 10) {
        phone = '91' + phone;
    }
    if (!phoneNumberId || !accessToken) {
        functions.logger.info('📱 WhatsApp Text (DEV MODE):', {
            to: phone,
            message: payload.message,
        });
        console.log(`\n📱 WHATSAPP TEXT (would be sent):`);
        console.log(`   To: +${phone}`);
        console.log(`   Message: ${payload.message}\n`);
        return true;
    }
    try {
        const url = `https://graph.facebook.com/v18.0/${phoneNumberId}/messages`;
        const response = await fetch(url, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                messaging_product: 'whatsapp',
                to: phone,
                type: 'text',
                text: {
                    body: payload.message,
                },
            }),
        });
        const result = await response.json();
        if (!response.ok) {
            throw new Error(result.error?.message || 'WhatsApp API error');
        }
        functions.logger.info('✅ WhatsApp text sent:', { to: phone });
        return true;
    }
    catch (error) {
        functions.logger.error('❌ WhatsApp text failed:', error);
        throw error;
    }
}
/**
 * Template names to create in Meta Business Manager:
 *
 * 1. tenant_invitation
 *    Body: "Hello {{1}}! You have been added as a tenant at {{2}}.
 *           Room: {{3}}, Bed: {{4}}.
 *           Download the app to view details and pay rent: {{5}}"
 *    Params: [tenantName, propertyName, roomNumber, bedNumber, appLink]
 *
 * 2. enrollment_approved
 *    Body: "Good news {{1}}! Your enrollment request for {{2}} has been approved.
 *           Room: {{3}}, Bed: {{4}}. Move-in: {{5}}.
 *           Download the app: {{6}}"
 *    Params: [tenantName, propertyName, roomNumber, bedNumber, moveInDate, appLink]
 *
 * 3. enrollment_rejected
 *    Body: "Hi {{1}}, unfortunately your enrollment request for {{2}} was not approved.
 *           Reason: {{3}}. You can browse other PGs in our app."
 *    Params: [tenantName, propertyName, reason]
 *
 * 4. rent_reminder
 *    Body: "Hi {{1}}, your rent of ₹{{2}} for {{3}} is due on {{4}}.
 *           Pay now to avoid late fees: {{5}}"
 *    Params: [tenantName, amount, propertyName, dueDate, paymentLink]
 */
//# sourceMappingURL=sendWhatsApp.js.map