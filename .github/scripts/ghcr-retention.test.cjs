// Run: node --test .github/scripts/ghcr-retention.test.cjs
const test = require("node:test");
const assert = require("node:assert/strict");
const { planRetention } = require("./ghcr-retention.cjs");

const d = (c) => `sha256:${c.repeat(64)}`;
const sig = (c) => `sha256-${c.repeat(64)}.sig`;
const v = (id, name, tags, day) => ({
  id,
  name,
  created_at: `2026-10-${String(day).padStart(2, "0")}T00:00:00Z`,
  metadata: { container: { tags } },
});

test("keeps N images plus their signatures, not N raw versions", () => {
  const versions = [
    v(1, d("a"), ["v1"], 1),
    v(2, d("1"), [sig("a")], 1),
    v(3, d("b"), ["v2"], 8),
    v(4, d("2"), [sig("b")], 8),
    v(5, d("c"), ["v3"], 15),
    v(6, d("3"), [sig("c")], 15),
    v(7, d("e"), ["v4", "latest"], 22),
    v(8, d("4"), [sig("e")], 22),
  ];
  const { keep, remove } = planRetention(versions, 3);
  assert.deepEqual(keep.map((x) => x.id).sort(), [3, 4, 5, 6, 7, 8]);
  assert.deepEqual(remove.map((x) => x.id).sort(), [1, 2]);
});

test("removes orphaned signatures whose image is gone", () => {
  const versions = [
    v(1, d("9"), [sig("f")], 1),
    v(2, d("e"), ["v4", "latest"], 22),
    v(3, d("4"), [sig("e")], 22),
  ];
  const { remove } = planRetention(versions, 3);
  assert.deepEqual(remove.map((x) => x.id), [1]);
});

test("never deletes untagged versions (may be manifest-list children)", () => {
  const versions = [
    v(1, d("a"), [], 1),
    v(2, d("b"), ["v1"], 2),
    v(3, d("c"), ["v2"], 3),
    v(4, d("e"), ["v3"], 4),
    v(5, d("f"), ["v4"], 5),
  ];
  const { keep, remove } = planRetention(versions, 3);
  assert.ok(keep.some((x) => x.id === 1));
  assert.deepEqual(remove.map((x) => x.id), [2]);
});

test("keeps the version tagged latest in addition to the newest N", () => {
  const versions = [
    v(1, d("a"), ["v1", "latest"], 1),
    v(2, d("b"), ["v2"], 2),
    v(3, d("c"), ["v3"], 3),
    v(4, d("e"), ["v4"], 4),
    v(5, d("f"), ["v5"], 5),
  ];
  const { keep, remove } = planRetention(versions, 3);
  assert.ok(keep.some((x) => x.id === 1));
  assert.deepEqual(remove.map((x) => x.id), [2]);
});
