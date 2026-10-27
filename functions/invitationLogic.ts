// Pure helpers for business invitations (no Firebase imports, so they can be unit tested).

/** The last ten digits of a phone number, however it was written. */
export function normalizePhone(phone: string | undefined | null): string {
  if (!phone) return '';
  const digits = phone.replace(/\D/g, '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

/** True when both numbers are present and are the same number. */
export function phonesMatch(a: string | undefined | null, b: string | undefined | null): boolean {
  const x = normalizePhone(a);
  const y = normalizePhone(b);
  return x !== '' && x === y;
}
