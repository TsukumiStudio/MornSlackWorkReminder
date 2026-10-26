"use strict";

// Slackデスクトップのウィンドウタイトル（例: "_foo (Channel) - Workspace - Slack"）から
// 表示中のチャンネル名を取り出す。チャンネル名は空白や括弧を含まないので末尾の括弧書きは種別表記。
function titleChannel(title) {
  const segment = String(title).replace(/^[*!]\s*/, "")
    .split(/\s+[-|–]\s+/).map(part => part.trim()).find(part => part && part !== "Slack") || "";
  return segment.replace(/\s*[(（][^()（）]*[)）]$/, "").replace(/^#\s*/, "");
}

// Swiftから毎tick呼ぶ。設定が不正なら error を返し、警告しない。
function check(stored, name, elapsed) {
  const { defaults, validate, isPersonalChannel, isExcluded, shouldWarn } = globalThis.WorkReminder;
  try {
    const settings = validate({ ...defaults, ...JSON.parse(stored || "{}") });
    return {
      eligible: isPersonalChannel(name) && !isExcluded(settings, name, ""),
      warn: shouldWarn(settings, new Date(), elapsed)
    };
  } catch (error) {
    return { eligible: false, warn: false, error: String(error.message || error) };
  }
}

if (typeof module !== "undefined") module.exports = { titleChannel, check };
