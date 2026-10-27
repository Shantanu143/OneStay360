"use strict";
// Pure helpers for updateMemberPropertyAccess (no Firebase imports, so they can be unit tested).
Object.defineProperty(exports, "__esModule", { value: true });
exports.uniqueIds = uniqueIds;
exports.diffAccess = diffAccess;
/** Distinct, non-empty string ids from whatever the client sent, in order. */
function uniqueIds(input) {
    if (!Array.isArray(input))
        return [];
    return Array.from(new Set(input.filter((p) => typeof p === 'string' && p.length > 0)));
}
/** What changes when a member's property access goes from [existing] to [requested]. */
function diffAccess(existing, requested) {
    const have = new Set(existing);
    const want = new Set(requested);
    return {
        toAdd: requested.filter((p) => !have.has(p)),
        toKeep: requested.filter((p) => have.has(p)),
        toRemove: existing.filter((p) => !want.has(p)),
    };
}
//# sourceMappingURL=memberAccessLogic.js.map