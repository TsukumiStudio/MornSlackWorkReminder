"use strict";

// 設定画面に、ネイティブ連携が要る部品（ログイン時起動・版表記・更新）を足す。
(() => {
  const call = async body => JSON.parse(await webkit.messageHandlers.mac.postMessage(body));
  const status = document.getElementById("status");

  const style = document.createElement("style");
  style.textContent = `
    body { width: 600px; }
    .note, small { white-space: nowrap; }
    .mac-footer { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-top: 14px; }
    .mac-footer .version { color: #6b7487; font-size: 11px; }
    .mac-footer .right { display: flex; flex-direction: column; align-items: flex-end; gap: 4px; }
    .mac-footer .buttons { display: flex; gap: 6px; }
    #update-status { color: #6b7487; font-size: 11px; }
    #update-status:empty { display: none; }
    .mac-footer button { flex: none; padding: 6px 10px; font-size: 11px; }
    .mac-footer button:disabled { opacity: .5; cursor: default; }
    #status + .card { margin: 12px 0 0; }
    #update:not(:disabled) { background: #7560db; border-color: #7560db; color: white; }
  `;
  document.head.append(style);

  const login = document.createElement("label");
  login.className = "toggle-row card";
  login.innerHTML = `<span><strong>ログイン時に起動</strong><small>Macにログインしたら自動で常駐</small></span><input id="login" class="switch" type="checkbox">`;

  const footer = document.createElement("footer");
  footer.className = "mac-footer";
  footer.innerHTML = `<span class="version"></span><span class="right"><span class="buttons"><button id="check" type="button">最新を確認</button><button id="update" type="button" disabled>最新へ更新</button></span><span id="update-status" role="status"></span></span>`;
  status.after(login);
  login.after(footer);

  const loginInput = login.querySelector("input");
  const check = footer.querySelector("#check");
  const update = footer.querySelector("#update");
  const updateStatus = footer.querySelector("#update-status");
  let version = "";

  call({ op: "info" }).then(info => {
    version = info.version;
    footer.querySelector(".version").textContent = `v${version}`;
    loginInput.checked = info.login;
  });

  loginInput.addEventListener("change", async () => {
    const result = await call({ op: "login", value: loginInput.checked });
    loginInput.checked = result.login;
    if (result.error) status.textContent = result.error;
  });

  // "1.0.10" > "1.0.9" になるよう数値で比べる。
  function isNewer(latest, current) {
    const a = latest.split(".").map(Number);
    const b = current.split(".").map(Number);
    for (let i = 0; i < Math.max(a.length, b.length); i++) {
      if ((a[i] || 0) !== (b[i] || 0)) return (a[i] || 0) > (b[i] || 0);
    }
    return false;
  }

  check.addEventListener("click", async () => {
    check.disabled = true;
    try {
      const response = await fetch("https://api.github.com/repos/TsukumiStudio/MornSlackWorkReminder/releases/latest");
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const latest = (await response.json()).tag_name.replace(/^v/, "");
      update.disabled = !isNewer(latest, version);
      updateStatus.textContent = update.disabled ? "最新版です。" : `v${latest} があります。`;
    } catch (error) {
      updateStatus.textContent = `確認できませんでした（${error.message}）。`;
    } finally {
      check.disabled = false;
    }
  });

  update.addEventListener("click", async () => {
    update.disabled = check.disabled = true;
    updateStatus.textContent = "更新しています。完了すると自動で再起動します…";
    const result = await call({ op: "update" });
    // 成功時はアプリが再起動するので、ここに戻るのは失敗時だけ。
    updateStatus.textContent = result.error;
    update.disabled = check.disabled = false;
  });
})();
