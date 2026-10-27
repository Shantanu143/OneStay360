// Pure helpers for updateMemberPropertyAccess (no Firebase imports, so they can be unit tested).

/** Distinct, non-empty string ids from whatever the client sent, in order. */
export function uniqueIds(input: unknown): string[] {
  if (!Array.isArray(input)) return [];
  return Array.from(new Set(input.filter((p): p is string => typeof p === 'string' && p.length > 0)));
}

/** What changes when a member's property access goes from [existing] to [requested]. */
export function diffAccess(existing: string[], requested: string[]) {
  const have = new Set(existing);
  const want = new Set(requested);
  return {
    toAdd: requested.filter((p) => !have.has(p)),
    toKeep: requested.filter((p) => have.has(p)),
    toRemove: existing.filter((p) => !want.has(p)),
  };
}
