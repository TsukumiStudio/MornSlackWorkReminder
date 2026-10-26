const test = require("node:test");
const assert = require("node:assert/strict");
const { defaults, validate, inSchedule, isPersonalChannel, isExcluded, shouldWarn } = require("./settings.js");

const at = (day, hour, minute = 0) => new Date(2026, 9, day, hour, minute);

test("先頭のアンダースコアだけで個人チャンネルを判定する", () => {
  assert.equal(isPersonalChannel("_kakeru-ch"), true);
  assert.equal(isPersonalChannel(" #_kakeru-ch "), true);
  assert.equal(isPersonalChannel("team_channel"), false);
  assert.equal(isPersonalChannel(""), false);
  assert.equal(isPersonalChannel(null), false);
});

test("平日の開始を含み終了を含まない", () => {
  assert.equal(inSchedule(defaults, at(23, 9, 39)), false);
  assert.equal(inSchedule(defaults, at(23, 9, 40)), true);
  assert.equal(inSchedule(defaults, at(23, 18, 29)), true);
  assert.equal(inSchedule(defaults, at(23, 18, 30)), false);
  assert.equal(inSchedule(defaults, at(24, 12)), false);
});

test("日をまたぐ設定は開始曜日に従う", () => {
  const settings = { ...defaults, days: [5], start: "22:00", end: "02:00" };
  assert.equal(inSchedule(settings, at(23, 1)), false);
  assert.equal(inSchedule(settings, at(23, 22)), true);
  assert.equal(inSchedule(settings, at(24, 1, 59)), true);
  assert.equal(inSchedule(settings, at(24, 2)), false);
  const sunday = { ...settings, days: [0] };
  assert.equal(inSchedule(sunday, at(26, 1)), true);
});

test("終日・無効・曜日なし・一時停止を扱う", () => {
  const now = at(23, 12);
  assert.equal(inSchedule({ ...defaults, start: "09:00", end: "09:00" }, at(23, 0)), true);
  assert.equal(inSchedule({ ...defaults, enabled: false }, now), false);
  assert.equal(inSchedule({ ...defaults, days: [] }, now), false);
  assert.equal(inSchedule({ ...defaults, snoozeUntil: now.getTime() + 1 }, now), false);
  assert.equal(inSchedule({ ...defaults, snoozeUntil: now.getTime() }, now), true);
});

test("不正な保存設定を明示的に拒否する", () => {
  assert.throws(() => validate({ ...defaults, start: "24:00" }));
  assert.throws(() => validate({ ...defaults, days: [7] }));
  assert.throws(() => validate({ ...defaults, snoozeUntil: -1 }));
  assert.deepEqual(validate({ ...defaults }), defaults);
});

test("時間外も3分ちょうどで警告しトグル・停止を優先する", () => {
  const now = at(24, 22);
  assert.equal(shouldWarn(defaults, now, 179999), false);
  assert.equal(shouldWarn(defaults, now, 180000), true);
  assert.equal(shouldWarn({ ...defaults, warnAfterThreeMinutes: false }, now, 180000), false);
  assert.equal(shouldWarn({ ...defaults, enabled: false }, now, 180000), false);
  assert.equal(shouldWarn({ ...defaults, snoozeUntil: now.getTime() + 60000 }, now, 180000), false);
  assert.equal(shouldWarn({ ...defaults, warnAfterThreeMinutes: false }, at(23, 12), 0), true);
});

test("チャンネル名と2種類のSlack URLから除外する", () => {
  const settings = { ...defaults, exclusions: ["#_example", "https://app.slack.com/client/T123/C456?thread=x", "https://team.slack.com/archives/C789/p123"] };
  assert.equal(isExcluded(settings, "_example", "https://app.slack.com/client/T123/C111"), true);
  assert.equal(isExcluded(settings, "_renamed", "https://app.slack.com/client/T123/C456"), true);
  assert.equal(isExcluded(settings, "_other", "https://app.slack.com/client/T123/C789/thread/C789-123"), true);
  assert.equal(isExcluded(settings, "_example2", "https://app.slack.com/client/T123/C111"), false);
  assert.throws(() => validate({ ...defaults, exclusions: ["https://example.com/archives/C456"] }));
});
