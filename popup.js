"use strict";

const { defaults, validate } = globalThis.WorkReminder;
const status = document.getElementById("status");
const save = document.getElementById("save");
const resume = document.getElementById("resume");

function reportError(message, error) {
  status.textContent = message;
  console.error(message, error);
}

async function load() {
  try {
    const settings = validate(await chrome.storage.local.get(defaults));
    document.getElementById("enabled").checked = settings.enabled;
    document.getElementById("start").value = settings.start;
    document.getElementById("end").value = settings.end;
    document.getElementById("three-minutes").checked = settings.warnAfterThreeMinutes;
    document.getElementById("exclusions").value = settings.exclusions.join("\n");
    document.querySelectorAll('[name="day"]').forEach(input => {
      input.checked = settings.days.includes(Number(input.value));
    });
    status.textContent = settings.snoozeUntil > Date.now()
      ? `${new Date(settings.snoozeUntil).toLocaleTimeString("ja-JP")}まで一時停止中です。`
      : "";
    save.disabled = false;
    resume.disabled = false;
  } catch (error) {
    reportError("設定を読み込めませんでした。アプリを再起動してください。", error);
  }
}

document.getElementById("settings").addEventListener("submit", async event => {
  event.preventDefault();
  save.disabled = true;
  try {
    const settings = validate({
      enabled: document.getElementById("enabled").checked,
      start: document.getElementById("start").value,
      end: document.getElementById("end").value,
      warnAfterThreeMinutes: document.getElementById("three-minutes").checked,
      exclusions: document.getElementById("exclusions").value.split("\n").map(value => value.trim()).filter(Boolean),
      days: [...document.querySelectorAll('[name="day"]:checked')].map(input => Number(input.value)),
      snoozeUntil: 0
    });
    await chrome.storage.local.set(settings);
    status.textContent = "保存しました。一時停止を解除して反映します。";
  } catch (error) {
    reportError("設定を保存できませんでした。", error);
  } finally {
    save.disabled = false;
  }
});

resume.addEventListener("click", async () => {
  resume.disabled = true;
  try {
    await chrome.storage.local.set({ snoozeUntil: 0 });
    status.textContent = "一時停止を解除しました。";
  } catch (error) {
    reportError("一時停止を解除できませんでした。", error);
  } finally {
    resume.disabled = false;
  }
});

load();
