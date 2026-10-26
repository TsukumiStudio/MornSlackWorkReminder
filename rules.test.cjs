"use strict";

const test = require("node:test");
const assert = require("node:assert");
require("./settings.js");
const { titleChannel, check } = require("./rules.js");

test("ウィンドウタイトルからチャンネル名を取り出す", () => {
  assert.strictEqual(titleChannel("_times-foo (Channel) - Workspace - Slack"), "_times-foo");
  assert.strictEqual(titleChannel("* _times-foo (チャンネル) - Workspace - Slack"), "_times-foo");
  assert.strictEqual(titleChannel("Slack | #_foo | Workspace"), "_foo");
  assert.strictEqual(titleChannel("general - Workspace - Slack"), "general");
  assert.strictEqual(titleChannel("Slack"), "");
});

test("設定に従って対象・警告を判定する", () => {
  const always = JSON.stringify({ start: "00:00", end: "00:00", days: [0, 1, 2, 3, 4, 5, 6] });
  assert.deepStrictEqual(check(always, "_foo", 0), { eligible: true, warn: true });
  assert.strictEqual(check(always, "general", 0).eligible, false);
  const excluded = JSON.stringify({ ...JSON.parse(always), exclusions: ["#_foo"] });
  assert.strictEqual(check(excluded, "_foo", 0).eligible, false);
  const never = JSON.stringify({ days: [] });
  assert.strictEqual(check(never, "_foo", 0).warn, false);
  assert.strictEqual(check(never, "_foo", 180_000).warn, true);
  assert.ok(check(JSON.stringify({ start: "bad" }), "_foo", 0).error);
});
