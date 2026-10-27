import { normalizePhone, phonesMatch } from '../../invitationLogic';

describe('normalizePhone', () => {
  it('keeps the last ten digits, whatever the formatting', () => {
    expect(normalizePhone('+91 98111 00001')).toBe('9811100001');
    expect(normalizePhone('+919811100001')).toBe('9811100001');
    expect(normalizePhone('09811100001')).toBe('9811100001');
    expect(normalizePhone('9811100001')).toBe('9811100001');
  });

  it('is empty for nothing', () => {
    expect(normalizePhone(undefined)).toBe('');
    expect(normalizePhone(null)).toBe('');
    expect(normalizePhone('')).toBe('');
  });

  it('leaves a short number as it is', () => {
    expect(normalizePhone('12345')).toBe('12345');
  });
});

describe('phonesMatch', () => {
  it('matches the same number written differently', () => {
    expect(phonesMatch('+919811100001', '98111 00001')).toBe(true);
  });

  it('does not match a different number', () => {
    expect(phonesMatch('+919811100001', '+919811100002')).toBe(false);
  });

  it('never matches when either side has no number', () => {
    expect(phonesMatch('', '+919811100001')).toBe(false);
    expect(phonesMatch('+919811100001', undefined)).toBe(false);
    expect(phonesMatch(null, null)).toBe(false);
  });
});
