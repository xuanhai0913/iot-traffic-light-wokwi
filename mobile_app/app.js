const DEFAULT_API_BASE = "http://127.0.0.1:8000";
const INTERSECTION_ID = 1;
const REQUEST_TIMEOUT_MS = 1500;
let apiBase = loadApiBase();

const modeLabels = {
  AUTO: "AUTO",
  NIGHT: "NIGHT",
  PRIORITY_NS: "PRIORITY NS",
  PRIORITY_EW: "PRIORITY EW",
  EMERGENCY: "EMERGENCY",
};

const defaultConfig = {
  greenSeconds: 8,
  yellowSeconds: 3,
};

const state = {
  online: false,
  busy: false,
  activePhasePlanId: null,
  status: {
    modeCode: "AUTO",
    phaseCode: "NS_GREEN",
    remainingSeconds: 8,
    signals: [],
  },
  config: { ...defaultConfig },
  history: [],
  roads: [],
  phasePlans: [],
  logs: [],
  modes: [],
};

const elements = {
  connectionState: document.querySelector("#connectionState"),
  connectionText: document.querySelector("#connectionText"),
  apiBaseLabel: document.querySelector("#apiBaseLabel"),
  apiBaseInput: document.querySelector("#apiBaseInput"),
  refreshData: document.querySelector("#refreshData"),
  apiMessage: document.querySelector("#apiMessage"),
  modeLabel: document.querySelector("#modeLabel"),
  phaseLabel: document.querySelector("#phaseLabel"),
  countdownLabel: document.querySelector("#countdownLabel"),
  countdownSuffix: document.querySelector("#countdownSuffix"),
  buttons: [...document.querySelectorAll(".mode-button")],
  historyList: document.querySelector("#historyList"),
  greenSeconds: document.querySelector("#greenSeconds"),
  yellowSeconds: document.querySelector("#yellowSeconds"),
  greenValue: document.querySelector("#greenValue"),
  yellowValue: document.querySelector("#yellowValue"),
  resetConfig: document.querySelector("#resetConfig"),
  clearHistory: document.querySelector("#clearHistory"),
  refreshLogs: document.querySelector("#refreshLogs"),
  roadCode: document.querySelector("#roadCode"),
  roadName: document.querySelector("#roadName"),
  addRoad: document.querySelector("#addRoad"),
  roadList: document.querySelector("#roadList"),
  roadCount: document.querySelector("#roadCount"),
  approachMetric: document.querySelector("#approachMetric"),
  planMetric: document.querySelector("#planMetric"),
  commandMetric: document.querySelector("#commandMetric"),
  logMetric: document.querySelector("#logMetric"),
  signalCount: document.querySelector("#signalCount"),
  signalGrid: document.querySelector("#signalGrid"),
  phasePlanName: document.querySelector("#phasePlanName"),
  phaseStepList: document.querySelector("#phaseStepList"),
  modeList: document.querySelector("#modeList"),
  logList: document.querySelector("#logList"),
  approachSignals: {
    NORTH: document.querySelector("#northSignal"),
    SOUTH: document.querySelector("#southSignal"),
    EAST: document.querySelector("#eastSignal"),
    WEST: document.querySelector("#westSignal"),
  },
  lamps: {
    ns: {
      red: document.querySelector("#nsRed"),
      yellow: document.querySelector("#nsYellow"),
      green: document.querySelector("#nsGreen"),
    },
    ew: {
      red: document.querySelector("#ewRed"),
      yellow: document.querySelector("#ewYellow"),
      green: document.querySelector("#ewGreen"),
    },
  },
};

setup();

function setup() {
  elements.apiBaseLabel.textContent = apiBase;
  elements.apiBaseInput.value = apiBase;
  bindEvents();
  syncConfigInputs();
  setOnline(false);
  render();
  loadAll();
  window.setInterval(loadStatus, 1000);
}

function bindEvents() {
  elements.refreshData.addEventListener("click", loadAll);
  elements.apiBaseInput.addEventListener("change", () => {
    apiBase = normalizeApiBase(elements.apiBaseInput.value);
    localStorage.setItem("traffic-api-base", apiBase);
    elements.apiBaseLabel.textContent = apiBase;
    setOnline(false);
    loadAll();
  });
  elements.clearHistory.addEventListener("click", loadHistory);
  elements.refreshLogs.addEventListener("click", loadLogs);
  elements.buttons.forEach((button) => {
    button.addEventListener("click", () => sendCommand(button.dataset.mode));
  });

  elements.greenSeconds.addEventListener("input", () => {
    state.config.greenSeconds = Number(elements.greenSeconds.value);
    syncConfigLabels();
  });

  elements.yellowSeconds.addEventListener("input", () => {
    state.config.yellowSeconds = Number(elements.yellowSeconds.value);
    syncConfigLabels();
  });

  elements.greenSeconds.addEventListener("change", savePhaseConfig);
  elements.yellowSeconds.addEventListener("change", savePhaseConfig);

  elements.resetConfig.addEventListener("click", async () => {
    state.config = { ...defaultConfig };
    syncConfigInputs();
    await savePhaseConfig();
  });

  elements.addRoad.addEventListener("click", createRoad);
}

async function loadAll() {
  await checkHealth();
  await loadDashboard();
}

async function checkHealth() {
  try {
    await apiGet("/api/health");
    setOnline(true);
  } catch (error) {
    setOnline(false);
    showMessage("Chưa kết nối được backend C#. Hãy chạy backend ở cổng 8000.");
  }
}

async function loadStatus() {
  if (!state.online) {
    return;
  }

  try {
    const response = await apiGet(`/api/intersections/${INTERSECTION_ID}/status`);
    state.status = response.data;
    render();
  } catch (error) {
    setOnline(false);
    showMessage(error.message);
  }
}

async function loadDashboard() {
  if (!state.online) {
    render();
    return;
  }

  try {
    const response = await apiGet(`/api/intersections/${INTERSECTION_ID}/dashboard`);
    const data = response.data;
    state.status = normalizeStatus(data.status);
    state.roads = data.approaches ?? [];
    state.phasePlans = data.phasePlans ?? [];
    state.history = data.commands ?? [];
    state.logs = data.logs ?? [];
    state.modes = data.modes ?? [];
    applyActivePlanConfig();
    render();
  } catch (error) {
    showMessage(error.message);
  }
}

async function loadHistory() {
  if (!state.online) {
    renderHistory();
    return;
  }

  try {
    const response = await apiGet(`/api/intersections/${INTERSECTION_ID}/commands?limit=10`);
    state.history = response.data;
    renderHistory();
  } catch (error) {
    showMessage(error.message);
  }
}

async function loadLogs() {
  if (!state.online) {
    renderLogs();
    return;
  }

  try {
    const response = await apiGet(`/api/intersections/${INTERSECTION_ID}/logs`);
    state.logs = response.data;
    renderLogs();
    renderMetrics();
  } catch (error) {
    showMessage(error.message);
  }
}

async function loadRoads() {
  if (!state.online) {
    renderRoads();
    return;
  }

  try {
    const response = await apiGet(`/api/intersections/${INTERSECTION_ID}/approaches`);
    state.roads = response.data;
    renderRoads();
  } catch (error) {
    showMessage(error.message);
  }
}

async function loadPhasePlans() {
  if (!state.online) {
    return;
  }

  try {
    const response = await apiGet(`/api/intersections/${INTERSECTION_ID}/phase-plans`);
    state.phasePlans = response.data;
    applyActivePlanConfig();
    renderPhasePlan();
  } catch (error) {
    showMessage(error.message);
  }
}

async function sendCommand(modeCode) {
  if (state.busy || !modeLabels[modeCode]) {
    return;
  }

  state.busy = true;
  renderButtons();

  try {
    const response = await apiPost(`/api/intersections/${INTERSECTION_ID}/commands`, {
      command: `SET_${modeCode}`,
      modeCode,
      source: "mobile",
      createdBy: "operator",
    });
    state.status = response.data.trafficStatus;
    showMessage(`Đã gửi ${response.data.command}`);
    await loadDashboard();
  } catch (error) {
    showMessage(error.message);
  } finally {
    state.busy = false;
    renderButtons();
  }
}

async function savePhaseConfig() {
  if (!state.activePhasePlanId) {
    showMessage("Chưa có phase plan active.");
    return;
  }

  try {
    await apiPut(`/api/phase-plans/${state.activePhasePlanId}`, state.config);
    showMessage("Đã lưu cấu hình pha vào SQLite.");
    await loadPhasePlans();
    await loadDashboard();
  } catch (error) {
    showMessage(error.message);
  }
}

async function createRoad() {
  const code = elements.roadCode.value.trim();
  const name = elements.roadName.value.trim();

  if (!code) {
    showMessage("Nhập mã tuyến trước khi thêm.");
    return;
  }

  try {
    await apiPost(`/api/intersections/${INTERSECTION_ID}/approaches`, {
      code,
      name: name || code,
      displayOrder: state.roads.length + 1,
      isActive: true,
    });
    elements.roadCode.value = "";
    elements.roadName.value = "";
    showMessage("Đã thêm tuyến đường vào database.");
    await loadDashboard();
  } catch (error) {
    showMessage(error.message);
  }
}

async function toggleRoad(road) {
  try {
    await apiPut(`/api/approaches/${road.id}`, {
      isActive: Number(road.is_active) === 0,
    });
    await loadDashboard();
  } catch (error) {
    showMessage(error.message);
  }
}

function render() {
  state.status = normalizeStatus(state.status);
  const modeCode = state.status.modeCode ?? "AUTO";
  const view = computeClusterState(state.status.signals ?? []);

  elements.modeLabel.textContent = modeLabels[modeCode] ?? modeCode;
  elements.phaseLabel.textContent = state.status.phaseCode ?? "--";
  elements.countdownLabel.textContent = state.status.remainingSeconds >= 0 ? state.status.remainingSeconds : "--";
  elements.countdownSuffix.textContent = state.status.remainingSeconds >= 0 ? "s" : "";

  setCluster("ns", view.ns);
  setCluster("ew", view.ew);
  renderApproachSignals();
  renderSignals();
  renderButtons();
  renderMetrics();
  renderHistory();
  renderRoads();
  renderPhasePlan();
  renderModes();
  renderLogs();
}

function renderButtons() {
  const modeCode = state.status.modeCode ?? "AUTO";
  elements.buttons.forEach((button) => {
    button.classList.toggle("active", button.dataset.mode === modeCode);
    button.disabled = state.busy || !state.online;
  });
}

function renderHistory() {
  if (state.history.length === 0) {
    elements.historyList.innerHTML = '<li class="empty-state">Chưa có lệnh</li>';
    return;
  }

  elements.historyList.innerHTML = state.history.map((item) => `
    <li>
      <div>
        <strong>${escapeHtml(item.command)}</strong>
        <span>${escapeHtml(item.mode_code ?? item.modeCode ?? "")} · ${escapeHtml(item.source ?? "")}</span>
      </div>
      <span>${formatTime(item.created_at)}</span>
    </li>
  `).join("");
}

function renderRoads() {
  elements.roadCount.textContent = String(state.roads.length);

  if (state.roads.length === 0) {
    elements.roadList.innerHTML = '<li class="empty-state">Chưa có tuyến đường</li>';
    return;
  }

  elements.roadList.innerHTML = state.roads.map((road) => `
    <li>
      <div>
        <strong>${escapeHtml(road.code)}</strong>
        <span>${escapeHtml(road.name)} · GPIO ${formatPins(road)}</span>
      </div>
      <button class="road-toggle ${Number(road.is_active) === 1 ? "on" : ""}" data-road-id="${road.id}" type="button">
        ${Number(road.is_active) === 1 ? "ON" : "OFF"}
      </button>
    </li>
  `).join("");

  elements.roadList.querySelectorAll(".road-toggle").forEach((button) => {
    const road = state.roads.find((item) => String(item.id) === button.dataset.roadId);
    button.addEventListener("click", () => toggleRoad(road));
  });
}

function renderMetrics() {
  elements.approachMetric.textContent = String(state.roads.length);
  elements.planMetric.textContent = String(state.phasePlans.length);
  elements.commandMetric.textContent = String(state.history.length);
  elements.logMetric.textContent = String(state.logs.length);
}

function renderApproachSignals() {
  const signalsByApproach = Object.fromEntries((state.status.signals ?? []).map((signal) => [signal.approach, signal.color]));
  Object.entries(elements.approachSignals).forEach(([approach, element]) => {
    const color = signalsByApproach[approach] ?? "OFF";
    element.textContent = color;
    element.dataset.color = String(color).toLowerCase();
  });
}

function renderSignals() {
  const signals = state.status.signals ?? [];
  elements.signalCount.textContent = String(signals.length);

  if (signals.length === 0) {
    elements.signalGrid.innerHTML = '<div class="empty-state">Chưa có tín hiệu</div>';
    return;
  }

  elements.signalGrid.innerHTML = signals.map((signal) => `
    <article class="signal-card ${escapeHtml(String(signal.color).toLowerCase())}">
      <span>${escapeHtml(signal.approach)}</span>
      <strong>${escapeHtml(signal.color)}</strong>
      <small>${escapeHtml(signal.signal)}</small>
    </article>
  `).join("");
}

function renderPhasePlan() {
  const activePlan = activePhasePlan();
  elements.phasePlanName.textContent = activePlan ? `#${activePlan.id}` : "--";

  if (!activePlan) {
    elements.phaseStepList.innerHTML = '<li class="empty-state">Chưa có phase plan</li>';
    return;
  }

  elements.phaseStepList.innerHTML = (activePlan.steps ?? []).map((step) => {
    const colors = (step.signals ?? []).map((signal) => `${signal.approach}:${signal.color}`).join(" · ");
    const conflicts = (step.conflictErrors ?? []).length;
    return `
      <li>
        <div>
          <strong>${escapeHtml(step.code)}</strong>
          <span>${escapeHtml(colors)}</span>
        </div>
        <span class="phase-duration">${Number(step.duration_seconds)}s${conflicts ? " !" : ""}</span>
      </li>
    `;
  }).join("");
}

function renderModes() {
  if (state.modes.length === 0) {
    elements.modeList.innerHTML = '<li class="empty-state">Chưa có mode</li>';
    return;
  }

  elements.modeList.innerHTML = state.modes.map((mode) => `
    <li>
      <div>
        <strong>${escapeHtml(mode.code)}</strong>
        <span>${escapeHtml(mode.name)}</span>
      </div>
      <span class="priority-badge">P${mode.priority_level}</span>
    </li>
  `).join("");
}

function renderLogs() {
  if (state.logs.length === 0) {
    elements.logList.innerHTML = '<li class="empty-state">Chưa có log</li>';
    return;
  }

  elements.logList.innerHTML = state.logs.map((item) => `
    <li>
      <div>
        <strong>${escapeHtml(item.phase_code)}</strong>
        <span>${escapeHtml(item.mode_code)} · remaining ${Number(item.remaining_seconds)}s</span>
      </div>
      <span>${formatTime(item.created_at)}</span>
    </li>
  `).join("");
}

function computeClusterState(signals) {
  const byApproach = Object.fromEntries(signals.map((signal) => [signal.approach, String(signal.color).toLowerCase()]));
  const ns = strongestColor([byApproach.NORTH, byApproach.SOUTH]);
  const ew = strongestColor([byApproach.EAST, byApproach.WEST]);
  return { ns, ew };
}

function strongestColor(colors) {
  if (colors.includes("green")) return "green";
  if (colors.includes("yellow")) return "yellow";
  if (colors.includes("red")) return "red";
  return "off";
}

function setCluster(direction, color) {
  Object.entries(elements.lamps[direction]).forEach(([lampColor, element]) => {
    element.classList.toggle("on", color === lampColor);
  });
}

function syncConfigInputs() {
  elements.greenSeconds.value = state.config.greenSeconds;
  elements.yellowSeconds.value = state.config.yellowSeconds;
  syncConfigLabels();
}

function syncConfigLabels() {
  elements.greenValue.textContent = state.config.greenSeconds;
  elements.yellowValue.textContent = state.config.yellowSeconds;
}

function applyActivePlanConfig() {
  const activePlan = activePhasePlan();
  if (!activePlan) {
    return;
  }

  state.activePhasePlanId = activePlan.id;
  const greenStep = activePlan.steps.find((step) => String(step.code).includes("GREEN"));
  const yellowStep = activePlan.steps.find((step) => String(step.code).includes("YELLOW"));
  state.config.greenSeconds = Number(greenStep?.duration_seconds ?? defaultConfig.greenSeconds);
  state.config.yellowSeconds = Number(yellowStep?.duration_seconds ?? defaultConfig.yellowSeconds);
  syncConfigInputs();
}

function activePhasePlan() {
  return state.phasePlans.find((plan) => Number(plan.is_active) === 1) ?? state.phasePlans[0] ?? null;
}

function normalizeStatus(status) {
  return {
    modeCode: status?.modeCode ?? status?.mode_code ?? "AUTO",
    phaseCode: status?.phaseCode ?? status?.phase_code ?? "NS_GREEN",
    remainingSeconds: Number(status?.remainingSeconds ?? status?.remaining_seconds ?? -1),
    signals: status?.signals ?? [],
  };
}

function setOnline(online) {
  state.online = online;
  elements.connectionState.classList.toggle("offline", !online);
  elements.connectionText.textContent = online ? "C# API" : "Offline";
  renderButtons();
}

async function apiGet(path) {
  return api(path, { method: "GET" });
}

async function apiPost(path, body) {
  return api(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

async function apiPut(path, body) {
  return api(path, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

async function api(path, options) {
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    const response = await fetch(`${apiBase}${path}`, { ...options, signal: controller.signal });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(payload.error?.message ?? `HTTP ${response.status}`);
    }
    return payload;
  } catch (error) {
    if (error.name === "AbortError") {
      throw new Error("Không kết nối được backend C# trong thời gian chờ.");
    }
    throw error;
  } finally {
    window.clearTimeout(timeout);
  }
}

function showMessage(message) {
  elements.apiMessage.textContent = message;
}

function formatTime(value) {
  if (!value) {
    return "--";
  }
  return String(value).replace("T", " ").slice(0, 19);
}

function formatPins(road) {
  return [road.red_pin, road.yellow_pin, road.green_pin].map((pin) => pin ?? "-").join("/");
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function loadApiBase() {
  const stored = localStorage.getItem("traffic-api-base");
  return normalizeApiBase(stored || DEFAULT_API_BASE);
}

function normalizeApiBase(value) {
  const trimmed = String(value || DEFAULT_API_BASE).trim().replace(/\/+$/, "");
  return trimmed || DEFAULT_API_BASE;
}
