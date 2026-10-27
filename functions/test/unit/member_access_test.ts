import { diffAccess, uniqueIds } from '../../memberAccessLogic';

describe('diffAccess', () => {
  it('adds access to properties the member does not have yet', () => {
    expect(diffAccess([], ['p1', 'p2'])).toEqual({ toAdd: ['p1', 'p2'], toKeep: [], toRemove: [] });
  });

  it('keeps what they already have', () => {
    expect(diffAccess(['p1'], ['p1'])).toEqual({ toAdd: [], toKeep: ['p1'], toRemove: [] });
  });

  it('removes access that is no longer wanted', () => {
    expect(diffAccess(['p1', 'p2'], ['p2'])).toEqual({ toAdd: [], toKeep: ['p2'], toRemove: ['p1'] });
  });

  it('handles adding, keeping and removing together', () => {
    const d = diffAccess(['a', 'b', 'c'], ['b', 'c', 'd']);
    expect(d.toAdd).toEqual(['d']);
    expect(d.toKeep.sort()).toEqual(['b', 'c']);
    expect(d.toRemove).toEqual(['a']);
  });

  it('removing everything is allowed', () => {
    expect(diffAccess(['p1', 'p2'], [])).toEqual({ toAdd: [], toKeep: [], toRemove: ['p1', 'p2'] });
  });

  it('does nothing when nothing changes', () => {
    expect(diffAccess([], [])).toEqual({ toAdd: [], toKeep: [], toRemove: [] });
  });
});

describe('uniqueIds', () => {
  it('drops duplicates, blanks and non-strings, keeping order', () => {
    expect(uniqueIds(['b', 'a', 'b', '', null, 7, 'a', 'c'])).toEqual(['b', 'a', 'c']);
  });

  it('is empty for anything that is not a list', () => {
    expect(uniqueIds(undefined)).toEqual([]);
    expect(uniqueIds('p1')).toEqual([]);
  });
});
