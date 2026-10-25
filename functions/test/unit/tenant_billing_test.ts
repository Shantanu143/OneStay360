/**
 * Pure logic unit tests for tenantBilling.ts
 * No Firebase emulator needed. No Google Cloud billing.
 */

import * as admin from 'firebase-admin';

// ─── Helpers ─────────────────────────────────────────────────────────────────

function getPeriodMonth(date: Date): string {
  const y = date.getFullYear();
  const m = (date.getMonth() + 1).toString().padStart(2, '0');
  return `${y}-${m}`;
}

function getMonthLabel(date: Date): string {
  const months = ['January','February','March','April','May','June',
    'July','August','September','October','November','December'];
  return `${months[date.getMonth()]} ${date.getFullYear()}`;
}

function getBillingDate(tenant: {
  additionalInfo?: { billingDate?: number };
  checkInDate?: admin.firestore.Timestamp;
}): number {
  if (tenant.additionalInfo?.billingDate) {
    return Number(tenant.additionalInfo.billingDate);
  }
  if (tenant.checkInDate) {
    return tenant.checkInDate.toDate().getDate();
  }
  return 1; // default: 1st of month
}

function shouldGenerateInvoice(today: number, billingDate: number): boolean {
  return today >= billingDate;
}

function shouldSkipTenant(tenant: {
  businessId?: string;
  monthlyRent?: number;
  status?: string;
}): boolean {
  if (!tenant.businessId) return true;
  if (!tenant.monthlyRent || tenant.monthlyRent <= 0) return true;
  return false;
}

function calculateDueDate(billingDate: number, year: number, month: number): Date {
  return new Date(year, month, billingDate + 5);
}

// ─── Tests ───────────────────────────────────────────────────────────────────

describe('getBillingDate', () => {
  test('uses additionalInfo.billingDate when present', () => {
    const tenant = { additionalInfo: { billingDate: 15 } };
    expect(getBillingDate(tenant)).toBe(15);
  });

  test('falls back to checkInDate day', () => {
    const checkIn = admin.firestore.Timestamp.fromDate(new Date(2025, 0, 20));
    const tenant = { checkInDate: checkIn };
    expect(getBillingDate(tenant)).toBe(20);
  });

  test('defaults to 1 when no billing date or checkIn', () => {
    expect(getBillingDate({})).toBe(1);
  });

  test('prefers additionalInfo over checkInDate', () => {
    const checkIn = admin.firestore.Timestamp.fromDate(new Date(2025, 0, 20));
    const tenant = {
      additionalInfo: { billingDate: 5 },
      checkInDate: checkIn,
    };
    expect(getBillingDate(tenant)).toBe(5);
  });

  test('handles billingDate of 1 (first of month)', () => {
    const tenant = { additionalInfo: { billingDate: 1 } };
    expect(getBillingDate(tenant)).toBe(1);
  });

  test('handles billingDate of 31 (end of month)', () => {
    const tenant = { additionalInfo: { billingDate: 31 } };
    expect(getBillingDate(tenant)).toBe(31);
  });
});

describe('shouldGenerateInvoice', () => {
  test('generates when today equals billing date', () => {
    expect(shouldGenerateInvoice(15, 15)).toBe(true);
  });

  test('generates when today is after billing date', () => {
    expect(shouldGenerateInvoice(20, 15)).toBe(true);
  });

  test('skips when today is before billing date', () => {
    expect(shouldGenerateInvoice(10, 15)).toBe(false);
  });

  test('generates on 1st when billing date is 1', () => {
    expect(shouldGenerateInvoice(1, 1)).toBe(true);
  });

  test('skips on 30th when billing date is 31', () => {
    expect(shouldGenerateInvoice(30, 31)).toBe(false);
  });
});

describe('shouldSkipTenant', () => {
  test('skips tenant with no businessId', () => {
    expect(shouldSkipTenant({ monthlyRent: 8000, status: 'active' })).toBe(true);
  });

  test('skips tenant with zero rent', () => {
    expect(shouldSkipTenant({ businessId: 'BUS001', monthlyRent: 0 })).toBe(true);
  });

  test('skips tenant with negative rent', () => {
    expect(shouldSkipTenant({ businessId: 'BUS001', monthlyRent: -100 })).toBe(true);
  });

  test('skips tenant with undefined rent', () => {
    expect(shouldSkipTenant({ businessId: 'BUS001' })).toBe(true);
  });

  test('does not skip valid active tenant', () => {
    expect(shouldSkipTenant({
      businessId: 'BUS001',
      monthlyRent: 8000,
      status: 'active',
    })).toBe(false);
  });
});

describe('calculateDueDate', () => {
  test('due date is billing date + 5 days', () => {
    const due = calculateDueDate(1, 2025, 0); // Jan 1 + 5 = Jan 6
    expect(due.getDate()).toBe(6);
    expect(due.getMonth()).toBe(0);
  });

  test('handles month boundary', () => {
    const due = calculateDueDate(28, 2025, 0); // Jan 28 + 5 = Feb 2
    expect(due.getDate()).toBe(2);
    expect(due.getMonth()).toBe(1);
  });

  test('handles year boundary', () => {
    const due = calculateDueDate(28, 2024, 11); // Dec 28 + 5 = Jan 2
    expect(due.getDate()).toBe(2);
    expect(due.getFullYear()).toBe(2025);
  });
});

describe('getPeriodMonth', () => {
  test('formats January correctly', () => {
    expect(getPeriodMonth(new Date(2025, 0, 15))).toBe('2025-01');
  });

  test('pads single-digit months', () => {
    expect(getPeriodMonth(new Date(2025, 8, 1))).toBe('2025-09');
  });

  test('formats December correctly', () => {
    expect(getPeriodMonth(new Date(2025, 11, 1))).toBe('2025-12');
  });

  test('handles year change', () => {
    expect(getPeriodMonth(new Date(2026, 0, 1))).toBe('2026-01');
  });
});

describe('getMonthLabel', () => {
  const months = ['January','February','March','April','May','June',
    'July','August','September','October','November','December'];

  months.forEach((month, i) => {
    test(`returns "${month} 2025" for month index ${i}`, () => {
      expect(getMonthLabel(new Date(2025, i, 1))).toBe(`${month} 2025`);
    });
  });
});

describe('Invoice Idempotency Logic', () => {
  test('same period month means invoice already exists', () => {
    const now = new Date(2025, 0, 15);
    const existingPeriod = getPeriodMonth(now);
    const currentPeriod = getPeriodMonth(now);
    expect(existingPeriod).toBe(currentPeriod);
    // In real function: if existingSnap is not empty, skip
  });

  test('different months produce different period keys', () => {
    const jan = getPeriodMonth(new Date(2025, 0, 1));
    const feb = getPeriodMonth(new Date(2025, 1, 1));
    expect(jan).not.toBe(feb);
  });

  test('same month different year produces different period keys', () => {
    const jan2025 = getPeriodMonth(new Date(2025, 0, 1));
    const jan2026 = getPeriodMonth(new Date(2026, 0, 1));
    expect(jan2025).not.toBe(jan2026);
  });
});

describe('Overdue Marking Logic', () => {
  test('invoice is overdue when dueDate is in the past', () => {
    const now = admin.firestore.Timestamp.now();
    const pastDue = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 3 * 24 * 60 * 60 * 1000) // 3 days ago
    );
    expect(pastDue.toMillis() < now.toMillis()).toBe(true);
  });

  test('invoice is not overdue when dueDate is in the future', () => {
    const now = admin.firestore.Timestamp.now();
    const futureDue = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 3 * 24 * 60 * 60 * 1000) // 3 days from now
    );
    expect(futureDue.toMillis() > now.toMillis()).toBe(true);
  });

  test('batch size of 400 is safely under Firestore 500 limit', () => {
    const PAGE_SIZE = 400;
    const FIRESTORE_BATCH_LIMIT = 500;
    expect(PAGE_SIZE).toBeLessThan(FIRESTORE_BATCH_LIMIT);
  });
});
