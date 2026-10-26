"use strict";

globalThis.WorkReminder = (() => {
  const defaults = {
    enabled: true,
    start: "09:40",
    end: "18:30",
    days: [1, 2, 3, 4, 5],
    warnAfterThreeMinutes: true,
    exclusions: [],
    snoozeUntil: 0
  };

  function isTime(value) {
    return typeof value === "string" && /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(value);
  }

  function validate(settings) {
    if (typeof settings.enabled !== "boolean" ||
        typeof settings.warnAfterThreeMinutes !== "boolean" ||
        !Array.isArray(settings.exclusions) ||
        !settings.exclusions.every(value => typeof value === "string" && exclusionKey(value) !== "") ||
        !isTime(settings.start) || !isTime(settings.end) ||
        !Array.isArray(settings.days) ||
        !settings.days.every(day => Number.isInteger(day) && day >= 0 && day <= 6) ||
        !Number.isFinite(settings.snoozeUntil) || settings.snoozeUntil < 0) {
      throw new Error("保存された設定が不正です。設定を保存し直してください。");
    }
    return settings;
  }

  function minutes(time) {
    const [hours, mins] = time.split(":").map(Number);
    return hours * 60 + mins;
  }

  function inSchedule(settings, now = new Date()) {
    if (!settings.enabled || settings.snoozeUntil > now.getTime()) return false;
    const start = minutes(settings.start);
    const end = minutes(settings.end);
    const current = now.getHours() * 60 + now.getMinutes();
    const day = now.getDay();
    if (start === end) return settings.days.includes(day);
    if (start < end) {
      return settings.days.includes(day) && current >= start && current < end;
    }
    // 日をまたぐ時間帯は、開始した曜日に属するものとして扱う。
    return (current >= start && settings.days.includes(day)) ||
      (current < end && settings.days.includes((day + 6) % 7));
  }

  function isPersonalChannel(name) {
    return typeof name === "string" && name.trim().replace(/^#\s*/, "").startsWith("_");
  }

  function channelId(url) {
    try {
      const parsed = new URL(url);
      if (parsed.protocol !== "https:" ||
          !(parsed.hostname === "slack.com" || parsed.hostname.endsWith(".slack.com"))) return "";
      const match = parsed.pathname.match(/^\/(?:client\/[^/]+\/|archives\/)([CG][A-Z0-9]+)(?:\/|$)/);
      return match?.[1] || "";
    } catch {
      return "";
    }
  }

  function exclusionKey(value) {
    const trimmed = value.trim();
    if (/^https?:\/\//i.test(trimmed)) return channelId(trimmed);
    return trimmed.replace(/^#\s*/, "");
  }

  function isExcluded(settings, name, url) {
    const normalizedName = name.trim().replace(/^#\s*/, "");
    const id = channelId(url);
    return settings.exclusions.some(value => {
      const key = exclusionKey(value);
      return key === normalizedName || (id !== "" && key === id);
    });
  }

  function shouldWarn(settings, now, elapsed) {
    if (!settings.enabled || settings.snoozeUntil > now.getTime()) return false;
    return inSchedule(settings, now) ||
      (settings.warnAfterThreeMinutes && elapsed >= 3 * 60 * 1000);
  }

  return { defaults, validate, inSchedule, isPersonalChannel, channelId, isExcluded, shouldWarn };
})();

if (typeof module !== "undefined") module.exports = globalThis.WorkReminder;
