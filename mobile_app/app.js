const modes = {
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

const autoPhases = [
  { name: "NS GREEN", ns: "green", ew: "red", durationKey: "greenSeconds" },
  { name: "NS YELLOW", ns: "yellow", ew: "red", durationKey: "yellowSeconds" },
  { name: "EW GREEN", ns: "red", ew: "green", durationKey: "greenSeconds" },
  { name: "EW YELLOW", ns: "red", ew: "yellow", durationKey: "yellowSeconds" },
];

const state = {
  mode: "AUTO",
  phaseIndex: 0,
  remaining: defaultConfig.greenSeconds,
  blinkOn: true,
  config: loadConfig(),
  history: loadHistory(),
};

const elements = {
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
  elements.greenSeconds.value = state.config.greenSeconds;
  elements.yellowSeconds.value = state.config.yellowSeconds;
  syncConfigLabels();
  bindEvents();
  pushCommand("AUTO");
  render();

  window.setInterval(tick, 1000);
}

function bindEvents() {
  elements.buttons.forEach((button) => {
    button.addEventListener("click", () => setMode(button.dataset.mode));
  });

  elements.greenSeconds.addEventListener("input", () => updateConfig("greenSeconds", elements.greenSeconds.value));
  elements.yellowSeconds.addEventListener("input", () => updateConfig("yellowSeconds", elements.yellowSeconds.value));

  elements.resetConfig.addEventListener("click", () => {
    state.config = { ...defaultConfig };
    elements.greenSeconds.value = state.config.greenSeconds;
    elements.yellowSeconds.value = state.config.yellowSeconds;
    saveConfig();
    syncConfigLabels();
    resetPhase();
    pushCommand("RESET_CONFIG");
    render();
  });

  elements.clearHistory.addEventListener("click", () => {
    state.history = [];
    saveHistory();
    renderHistory();
  });
}

function setMode(nextMode) {
  if (!modes[nextMode]) {
    return;
  }

  state.mode = nextMode;
  if (nextMode === "AUTO") {
    resetPhase();
  } else {
    state.phaseIndex = 0;
    state.blinkOn = true;
    state.remaining = -1;
  }
  pushCommand(`SET_${nextMode}`);
  render();
}

function resetPhase() {
  state.phaseIndex = 0;
  state.blinkOn = true;
  state.remaining = currentDuration();
}

function tick() {
  if (state.mode === "AUTO") {
    state.remaining -= 1;

    if (state.remaining <= 0) {
      state.phaseIndex = (state.phaseIndex + 1) % autoPhases.length;
      state.remaining = currentDuration();
    }
  } else if (state.mode === "NIGHT") {
    state.blinkOn = !state.blinkOn;
    state.remaining = -1;
  } else {
    state.remaining = -1;
  }

  render();
}

function currentDuration() {
  const phase = autoPhases[state.phaseIndex];
  return Number(state.config[phase.durationKey]);
}

function updateConfig(key, value) {
  state.config[key] = Number(value);
  saveConfig();
  syncConfigLabels();

  if (state.mode === "AUTO") {
    state.remaining = Math.min(state.remaining, currentDuration());
  }

  render();
}

function syncConfigLabels() {
  elements.greenValue.textContent = state.config.greenSeconds;
  elements.yellowValue.textContent = state.config.yellowSeconds;
}

function render() {
  const view = computeLightState();
  elements.modeLabel.textContent = modes[state.mode];
  elements.phaseLabel.textContent = view.phase;
  elements.countdownLabel.textContent = state.remaining >= 0 ? state.remaining : "--";
  elements.countdownSuffix.textContent = state.remaining >= 0 ? "s" : "";

  setCluster("ns", view.ns);
  setCluster("ew", view.ew);

  elements.buttons.forEach((button) => {
    button.classList.toggle("active", button.dataset.mode === state.mode);
  });

  renderHistory();
}

function computeLightState() {
  if (state.mode === "NIGHT") {
    return {
      phase: state.blinkOn ? "YELLOW ON" : "YELLOW OFF",
      ns: state.blinkOn ? "yellow" : "off",
      ew: state.blinkOn ? "yellow" : "off",
    };
  }

  if (state.mode === "PRIORITY_NS") {
    return { phase: "NS PRIORITY", ns: "green", ew: "red" };
  }

  if (state.mode === "PRIORITY_EW") {
    return { phase: "EW PRIORITY", ns: "red", ew: "green" };
  }

  if (state.mode === "EMERGENCY") {
    return { phase: "ALL RED", ns: "red", ew: "red" };
  }

  const phase = autoPhases[state.phaseIndex];
  return { phase: phase.name, ns: phase.ns, ew: phase.ew };
}

function setCluster(direction, color) {
  Object.entries(elements.lamps[direction]).forEach(([lampColor, element]) => {
    element.classList.toggle("on", color === lampColor);
  });
}

function pushCommand(command) {
  const entry = {
    command,
    mode: modes[state.mode],
    time: new Date().toLocaleTimeString("vi-VN", { hour: "2-digit", minute: "2-digit", second: "2-digit" }),
  };

  state.history = [entry, ...state.history].slice(0, 8);
  saveHistory();
}

function renderHistory() {
  if (state.history.length === 0) {
    elements.historyList.innerHTML = '<li class="empty-state">Chưa có lệnh</li>';
    return;
  }

  elements.historyList.innerHTML = state.history.map((item) => `
    <li>
      <div>
        <strong>${item.command}</strong>
        <span>${item.mode}</span>
      </div>
      <span>${item.time}</span>
    </li>
  `).join("");
}

function loadConfig() {
  const raw = localStorage.getItem("traffic-control-config");
  if (!raw) {
    return { ...defaultConfig };
  }

  try {
    return { ...defaultConfig, ...JSON.parse(raw) };
  } catch {
    return { ...defaultConfig };
  }
}

function saveConfig() {
  localStorage.setItem("traffic-control-config", JSON.stringify(state.config));
}

function loadHistory() {
  const raw = localStorage.getItem("traffic-control-history");
  if (!raw) {
    return [];
  }

  try {
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

function saveHistory() {
  localStorage.setItem("traffic-control-history", JSON.stringify(state.history));
}
