"use strict";
// Pure helpers for business invitations (no Firebase imports, so they can be unit tested).
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizePhone = normalizePhone;
exports.phonesMatch = phonesMatch;
/** The last ten digits of a phone number, however it was written. */
function normalizePhone(phone) {
    if (!phone)
        return '';
    const digits = phone.replace(/\D/g, '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}
/** True when both numbers are present and are the same number. */
function phonesMatch(a, b) {
    const x = normalizePhone(a);
    const y = normalizePhone(b);
    return x !== '' && x === y;
}
//# sourceMappingURL=invitationLogic.js.map