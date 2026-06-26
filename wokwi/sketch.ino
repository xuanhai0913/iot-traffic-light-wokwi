#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <Preferences.h>

namespace Pins {
const uint8_t NS_RED = 16;
const uint8_t NS_YELLOW = 17;
const uint8_t NS_GREEN = 18;
const uint8_t EW_RED = 19;
const uint8_t EW_YELLOW = 23;
const uint8_t EW_GREEN = 25;

const uint8_t BTN_AUTO = 26;
const uint8_t BTN_NIGHT = 27;
const uint8_t BTN_PRIORITY = 32;
const uint8_t BTN_EMERGENCY = 33;
}

namespace MqttConfig {
const char *WIFI_SSID = "Wokwi-GUEST";
const char *WIFI_PASSWORD = "";
const char *BROKER_HOST = "broker.hivemq.com";
const uint16_t BROKER_PORT = 1883;
const char *CLIENT_ID_PREFIX = "wokwi-tl";
const char *DEVICE_ID = "wokwi-esp32-01";
const char *COMMAND_TOPIC = "traffic/hainx-iot-traffic-light/intersections/1/commands";
const char *STATUS_TOPIC = "traffic/hainx-iot-traffic-light/intersections/1/status";
const char *ACK_TOPIC = "traffic/hainx-iot-traffic-light/intersections/1/acks";
const unsigned long WIFI_RETRY_MS = 10000;
const unsigned long MQTT_RETRY_MS = 10000;
const uint32_t TCP_CONNECT_TIMEOUT_MS = 750;
const uint16_t MQTT_SOCKET_TIMEOUT_SECONDS = 1;
const uint16_t MQTT_BUFFER_SIZE = 768;
}

enum class LightColor {
  Off,
  Red,
  Yellow,
  Green
};

enum class TrafficMode {
  Auto,
  Night,
  PriorityNS,
  PriorityEW,
  Maintenance,
  Emergency
};

enum class CommandApplyResult {
  Applied,
  AlreadyActive,
  Unsupported
};

struct TrafficPhase {
  const char *code;
  const char *name;
  LightColor northColor;
  LightColor southColor;
  LightColor eastColor;
  LightColor westColor;
  uint8_t durationSeconds;
};

class TrafficLight {
public:
  TrafficLight(uint8_t redPin, uint8_t yellowPin, uint8_t greenPin)
      : redPin(redPin), yellowPin(yellowPin), greenPin(greenPin) {}

  void begin() {
    pinMode(redPin, OUTPUT);
    pinMode(yellowPin, OUTPUT);
    pinMode(greenPin, OUTPUT);
    turnOff();
  }

  void show(LightColor color) {
    digitalWrite(redPin, color == LightColor::Red ? HIGH : LOW);
    digitalWrite(yellowPin, color == LightColor::Yellow ? HIGH : LOW);
    digitalWrite(greenPin, color == LightColor::Green ? HIGH : LOW);
  }

  void turnOff() {
    digitalWrite(redPin, LOW);
    digitalWrite(yellowPin, LOW);
    digitalWrite(greenPin, LOW);
  }

private:
  uint8_t redPin;
  uint8_t yellowPin;
  uint8_t greenPin;
};

class RoadApproach {
public:
  RoadApproach(const char *code, const char *name, TrafficLight &light)
      : code(code), name(name), light(light) {}

  void begin() {
    light.begin();
  }

  void show(LightColor color) {
    light.show(color);
  }

  void turnOff() {
    light.turnOff();
  }

  const char *getCode() const {
    return code;
  }

  const char *getName() const {
    return name;
  }

private:
  const char *code;
  const char *name;
  TrafficLight &light;
};

class ModeManager {
public:
  void begin() {
    pinMode(Pins::BTN_AUTO, INPUT_PULLUP);
    pinMode(Pins::BTN_NIGHT, INPUT_PULLUP);
    pinMode(Pins::BTN_PRIORITY, INPUT_PULLUP);
    pinMode(Pins::BTN_EMERGENCY, INPUT_PULLUP);

    Serial.begin(115200);
    Serial.println();
    Serial.println("Traffic light controller ready.");
    Serial.println("Commands: a=auto, n=night, p=priority NS/EW, e=emergency");
  }

  bool update() {
    bool changed = false;

    if (pressed(Pins::BTN_AUTO, lastAutoState)) {
      changed = setMode(TrafficMode::Auto);
    }

    if (pressed(Pins::BTN_NIGHT, lastNightState)) {
      changed = setMode(TrafficMode::Night) || changed;
    }

    if (pressed(Pins::BTN_PRIORITY, lastPriorityState)) {
      priorityNextNS = !priorityNextNS;
      changed = setMode(priorityNextNS ? TrafficMode::PriorityNS : TrafficMode::PriorityEW) || changed;
    }

    if (pressed(Pins::BTN_EMERGENCY, lastEmergencyState)) {
      changed = setMode(TrafficMode::Emergency) || changed;
    }

    changed = readSerialCommand() || changed;

    if (pendingExternalChange) {
      pendingExternalChange = false;
      changed = true;
    }

    return changed;
  }

  TrafficMode getMode() const {
    return mode;
  }

  const char *modeName() const {
    switch (mode) {
    case TrafficMode::Auto:
      return "AUTO";
    case TrafficMode::Night:
      return "NIGHT";
    case TrafficMode::PriorityNS:
      return "PRIORITY NS";
    case TrafficMode::PriorityEW:
      return "PRIORITY EW";
    case TrafficMode::Emergency:
      return "EMERGENCY";
    case TrafficMode::Maintenance:
      return "MAINTENANCE";
    }
    return "UNKNOWN";
  }

  CommandApplyResult applyExternalCommand(String command, String &canonicalCommand) {
    TrafficMode nextMode;
    if (!parseCommand(command, nextMode, canonicalCommand)) {
      printUnknownCommand(command);
      return CommandApplyResult::Unsupported;
    }

    bool changed = setMode(nextMode);
    if (changed) {
      pendingExternalChange = true;
      return CommandApplyResult::Applied;
    }

    return CommandApplyResult::AlreadyActive;
  }

  uint32_t revision() const {
    return modeRevision;
  }

private:
  TrafficMode mode = TrafficMode::Auto;
  bool pendingExternalChange = false;
  bool priorityNextNS = false;
  bool lastAutoState = HIGH;
  bool lastNightState = HIGH;
  bool lastPriorityState = HIGH;
  bool lastEmergencyState = HIGH;
  unsigned long lastButtonMs = 0;
  unsigned long lastSerialByteMs = 0;
  uint32_t modeRevision = 0;
  String serialBuffer;
  static constexpr unsigned long debounceMs = 180;
  static constexpr unsigned long serialIdleMs = 50;
  static constexpr size_t maxSerialCommandLength = 64;

  bool setMode(TrafficMode nextMode) {
    if (nextMode == TrafficMode::PriorityNS) {
      priorityNextNS = true;
    } else if (nextMode == TrafficMode::PriorityEW) {
      priorityNextNS = false;
    }

    if (mode == nextMode) {
      return false;
    }

    mode = nextMode;
    modeRevision++;
    Serial.print("Mode changed to ");
    Serial.println(modeName());
    return true;
  }

  bool pressed(uint8_t pin, bool &lastState) {
    bool currentState = digitalRead(pin);
    bool isPressed = false;

    if (lastState == HIGH && currentState == LOW && millis() - lastButtonMs > debounceMs) {
      isPressed = true;
      lastButtonMs = millis();
    }

    lastState = currentState;
    return isPressed;
  }

  bool applyCommand(String command) {
    String canonicalCommand;
    TrafficMode nextMode;
    if (!parseCommand(command, nextMode, canonicalCommand)) {
      printUnknownCommand(command);
      return false;
    }

    return setMode(nextMode);
  }

  bool parseCommand(String command, TrafficMode &nextMode, String &canonicalCommand) const {
    command.trim();
    command.toUpperCase();
    command.replace("-", "_");
    command.replace(" ", "_");

    if (command == "A" || command == "AUTO" || command == "SET_AUTO") {
      nextMode = TrafficMode::Auto;
      canonicalCommand = "SET_AUTO";
      return true;
    }

    if (command == "N" || command == "NIGHT" || command == "SET_NIGHT") {
      nextMode = TrafficMode::Night;
      canonicalCommand = "SET_NIGHT";
      return true;
    }

    if (command == "P" || command == "PRIORITY" || command == "PRIORITY_NS" || command == "SET_PRIORITY_NS") {
      nextMode = TrafficMode::PriorityNS;
      canonicalCommand = "SET_PRIORITY_NS";
      return true;
    }

    if (command == "PE" || command == "PRIORITY_EW" || command == "SET_PRIORITY_EW") {
      nextMode = TrafficMode::PriorityEW;
      canonicalCommand = "SET_PRIORITY_EW";
      return true;
    }

    if (command == "E" || command == "EMERGENCY" || command == "SET_EMERGENCY") {
      nextMode = TrafficMode::Emergency;
      canonicalCommand = "SET_EMERGENCY";
      return true;
    }

    if (command == "M" || command == "MAINTENANCE" || command == "MAINT" || command == "SET_MAINTENANCE") {
      nextMode = TrafficMode::Maintenance;
      canonicalCommand = "SET_MAINTENANCE";
      return true;
    }

    canonicalCommand = "";
    return false;
  }

  void printUnknownCommand(const String &command) const {
    Serial.print("Unknown command: ");
    Serial.println(command);
  }

  bool readSerialCommand() {
    while (Serial.available()) {
      char value = static_cast<char>(Serial.read());
      lastSerialByteMs = millis();

      if (value == '\r') {
        continue;
      }

      if (value == '\n') {
        return runBufferedSerialCommand();
      }

      if (serialBuffer.length() >= maxSerialCommandLength) {
        Serial.println("Serial command too long; discarded");
        serialBuffer = "";
        continue;
      }

      serialBuffer += value;
    }

    if (serialBuffer.length() > 0 && millis() - lastSerialByteMs >= serialIdleMs) {
      return runBufferedSerialCommand();
    }

    return false;
  }

  bool runBufferedSerialCommand() {
    String command = serialBuffer;
    serialBuffer = "";
    command.trim();
    return command.length() > 0 && applyCommand(command);
  }
};

// --- State pattern: each TrafficMode is an IModeStrategy instance ---
// IntersectionController holds 5 strategies and dispatches update() to the
// current one. Adding a new mode = add a strategy class + add to the
// strategies[] array in the controller constructor.

// Persistent phase duration storage. Backed by ESP32 NVS via Preferences.
// First boot seeds defaults {8,3,8,3}; later boots reload from NVS. Mutated
// at runtime via MQTT SET_PHASE_CONFIG.
class PhaseConfig {
public:
  static constexpr uint8_t NS_GREEN_IDX  = 0;
  static constexpr uint8_t NS_YELLOW_IDX = 1;
  static constexpr uint8_t EW_GREEN_IDX  = 2;
  static constexpr uint8_t EW_YELLOW_IDX = 3;
  static constexpr uint8_t PHASE_COUNT   = 4;
  static constexpr uint8_t MIN_SECONDS   = 2;
  static constexpr uint8_t MAX_SECONDS   = 60;
  static const uint8_t DEFAULT_DURATIONS[PHASE_COUNT];

  void begin() {
    prefs.begin("traffic", false);
    if (!prefs.isKey("init")) {
      for (uint8_t i = 0; i < PHASE_COUNT; i++) {
        prefs.putUChar(keyFor(i), DEFAULT_DURATIONS[i]);
      }
      prefs.putBool("init", true);
      Serial.println("PhaseConfig: first boot, defaults saved");
    }
    for (uint8_t i = 0; i < PHASE_COUNT; i++) {
      durations[i] = prefs.getUChar(keyFor(i), DEFAULT_DURATIONS[i]);
    }
    prefs.end();
    printCurrent();
  }

  uint8_t getDuration(uint8_t idx) const {
    return (idx < PHASE_COUNT) ? durations[idx] : DEFAULT_DURATIONS[0];
  }

  // Returns true if applied and persisted; false if out of bounds.
  bool setDuration(uint8_t idx, uint8_t secs) {
    if (idx >= PHASE_COUNT) return false;
    if (secs < MIN_SECONDS || secs > MAX_SECONDS) return false;
    durations[idx] = secs;
    prefs.begin("traffic", false);
    prefs.putUChar(keyFor(idx), secs);
    prefs.end();
    Serial.print("PhaseConfig: idx=");
    Serial.print(idx);
    Serial.print(" -> ");
    Serial.print(secs);
    Serial.println("s (saved)");
    return true;
  }

private:
  uint8_t durations[PHASE_COUNT];
  Preferences prefs;

  static const char *keyFor(uint8_t idx) {
    switch (idx) {
    case NS_GREEN_IDX:  return "d_ns_green";
    case NS_YELLOW_IDX: return "d_ns_yellow";
    case EW_GREEN_IDX:  return "d_ew_green";
    case EW_YELLOW_IDX: return "d_ew_yellow";
    }
    return "d_unknown";
  }

  void printCurrent() const {
    Serial.print("PhaseConfig: NS ");
    Serial.print(durations[NS_GREEN_IDX]);
    Serial.print("s/");
    Serial.print(durations[NS_YELLOW_IDX]);
    Serial.print("s, EW ");
    Serial.print(durations[EW_GREEN_IDX]);
    Serial.print("s/");
    Serial.print(durations[EW_YELLOW_IDX]);
    Serial.println("s");
  }
};

const uint8_t PhaseConfig::DEFAULT_DURATIONS[PhaseConfig::PHASE_COUNT] = {8, 3, 8, 3};

class IModeStrategy {
public:
  virtual ~IModeStrategy() = default;

  // Called once when this strategy becomes active (after a mode change).
  // Implementations should reset their internal timers and apply initial
  // light colors.
  virtual void enter() = 0;

  // Called every loop() while this strategy is active.
  // Implementations should update lights and the LCD.
  virtual void tick() = 0;

  // Status payload helpers (used by MqttClientManager::publishStatus).
  virtual const char *phaseCode() const = 0;
  virtual int remainingSeconds() const = 0;       // -1 = no countdown
  virtual void getLightColors(LightColor &n, LightColor &s,
                              LightColor &e, LightColor &w) const = 0;

  // LCD line 2 text (without mode name; DisplayManager adds modeName + remaining).
  virtual const char *displayLine() const = 0;
};

class AutoMode : public IModeStrategy {
public:
  AutoMode(RoadApproach &n, RoadApproach &s, RoadApproach &e, RoadApproach &w,
           DisplayManager &display, PhaseConfig &phaseConfig, const char *modeName)
      : north(n), south(s), east(e), west(w),
        display(display), phaseConfig(phaseConfig), modeName(modeName) {}

  void enter() override {
    currentPhase = 0;
    phaseStartedMs = millis();
    applyCurrent();
  }

  void tick() override {
    unsigned long nowMs = millis();
    unsigned long elapsedMs = nowMs - phaseStartedMs;
    uint8_t durationSec = phaseConfig.getDuration(currentPhase);
    unsigned long durationMs = static_cast<unsigned long>(durationSec) * 1000UL;

    if (elapsedMs >= durationMs) {
      currentPhase = (currentPhase + 1) % PhaseConfig::PHASE_COUNT;
      phaseStartedMs = nowMs;
      applyCurrent();
      return;
    }

    int remaining = static_cast<int>((durationMs - elapsedMs + 999UL) / 1000UL);
    display.showStatus(modeName, META[currentPhase].name, remaining);
  }

  const char *phaseCode() const override {
    return META[currentPhase].code;
  }

  int remainingSeconds() const override {
    uint8_t durationSec = phaseConfig.getDuration(currentPhase);
    unsigned long elapsedMs = millis() - phaseStartedMs;
    unsigned long durationMs = static_cast<unsigned long>(durationSec) * 1000UL;
    if (elapsedMs >= durationMs) {
      return 0;
    }
    return static_cast<int>((durationMs - elapsedMs + 999UL) / 1000UL);
  }

  void getLightColors(LightColor &n, LightColor &s,
                      LightColor &e, LightColor &w) const override {
    n = META[currentPhase].n;
    s = META[currentPhase].s;
    e = META[currentPhase].e;
    w = META[currentPhase].w;
  }

  const char *displayLine() const override {
    return META[currentPhase].name;
  }

private:
  RoadApproach &north;
  RoadApproach &south;
  RoadApproach &east;
  RoadApproach &west;
  DisplayManager &display;
  PhaseConfig &phaseConfig;
  const char *modeName;

  // Static metadata: code/name + light colors per phase. Durations come
  // from PhaseConfig at runtime (W2). Constants are intentionally separate
  // from TrafficPhase because duration is now mutable.
  struct PhaseMeta {
    const char *code;
    const char *name;
    LightColor n;
    LightColor s;
    LightColor e;
    LightColor w;
  };
  static const PhaseMeta META[PhaseConfig::PHASE_COUNT];

  uint8_t currentPhase = 0;
  unsigned long phaseStartedMs = 0;

  void applyCurrent() {
    applyColors(META[currentPhase].n, META[currentPhase].s,
                META[currentPhase].e, META[currentPhase].w);
  }

  void applyColors(LightColor n, LightColor s, LightColor e, LightColor w) {
    north.show(n);
    south.show(s);
    east.show(e);
    west.show(w);
  }
};

const AutoMode::PhaseMeta AutoMode::META[PhaseConfig::PHASE_COUNT] = {
    {"NS_GREEN",  "NS GREEN",  LightColor::Green,  LightColor::Green,  LightColor::Red,    LightColor::Red},
    {"NS_YELLOW", "NS YELLOW", LightColor::Yellow, LightColor::Yellow, LightColor::Red,    LightColor::Red},
    {"EW_GREEN",  "EW GREEN",  LightColor::Red,    LightColor::Red,    LightColor::Green,  LightColor::Green},
    {"EW_YELLOW", "EW YELLOW", LightColor::Red,    LightColor::Red,    LightColor::Yellow, LightColor::Yellow},
};

class NightMode : public IModeStrategy {
public:
  NightMode(RoadApproach &n, RoadApproach &s, RoadApproach &e, RoadApproach &w,
            DisplayManager &display, const char *modeName)
      : north(n), south(s), east(e), west(w), display(display), modeName(modeName) {}

  void enter() override {
    blinkMs = millis();
    yellowOn = false;
    applyAll(LightColor::Off);
  }

  void tick() override {
    if (millis() - blinkMs >= 500) {
      blinkMs = millis();
      yellowOn = !yellowOn;
      applyAll(yellowOn ? LightColor::Yellow : LightColor::Off);
    }
    display.showStatus(modeName, yellowOn ? "YELLOW ON" : "YELLOW OFF", -1);
  }

  const char *phaseCode() const override { return "YELLOW_BLINK"; }
  int remainingSeconds() const override { return -1; }

  void getLightColors(LightColor &n, LightColor &s,
                      LightColor &e, LightColor &w) const override {
    n = yellowOn ? LightColor::Yellow : LightColor::Off;
    s = n; e = n; w = n;
  }

  const char *displayLine() const override {
    return yellowOn ? "YELLOW ON" : "YELLOW OFF";
  }

private:
  RoadApproach &north, &south, &east, &west;
  DisplayManager &display;
  const char *modeName;
  unsigned long blinkMs = 0;
  bool yellowOn = false;

  void applyAll(LightColor c) {
    north.show(c); south.show(c); east.show(c); west.show(c);
  }
};

class PriorityNSMode : public IModeStrategy {
public:
  PriorityNSMode(RoadApproach &n, RoadApproach &s, RoadApproach &e, RoadApproach &w,
                 DisplayManager &display, const char *modeName)
      : north(n), south(s), east(e), west(w), display(display), modeName(modeName) {}

  void enter() override {
    north.show(LightColor::Green);
    south.show(LightColor::Green);
    east.show(LightColor::Red);
    west.show(LightColor::Red);
  }
  void tick() override {
    display.showStatus(modeName, "NS GO", -1);
  }
  const char *phaseCode() const override { return "NS_PRIORITY"; }
  int remainingSeconds() const override { return -1; }
  void getLightColors(LightColor &n, LightColor &s, LightColor &e, LightColor &w) const override {
    n = LightColor::Green; s = LightColor::Green;
    e = LightColor::Red;   w = LightColor::Red;
  }
  const char *displayLine() const override { return "NS GO"; }

private:
  RoadApproach &north, &south, &east, &west;
  DisplayManager &display;
  const char *modeName;
};

class PriorityEWMode : public IModeStrategy {
public:
  PriorityEWMode(RoadApproach &n, RoadApproach &s, RoadApproach &e, RoadApproach &w,
                 DisplayManager &display, const char *modeName)
      : north(n), south(s), east(e), west(w), display(display), modeName(modeName) {}

  void enter() override {
    north.show(LightColor::Red);
    south.show(LightColor::Red);
    east.show(LightColor::Green);
    west.show(LightColor::Green);
  }
  void tick() override {
    display.showStatus(modeName, "EW GO", -1);
  }
  const char *phaseCode() const override { return "EW_PRIORITY"; }
  int remainingSeconds() const override { return -1; }
  void getLightColors(LightColor &n, LightColor &s, LightColor &e, LightColor &w) const override {
    n = LightColor::Red;    s = LightColor::Red;
    e = LightColor::Green;  w = LightColor::Green;
  }
  const char *displayLine() const override { return "EW GO"; }

private:
  RoadApproach &north, &south, &east, &west;
  DisplayManager &display;
  const char *modeName;
};

class EmergencyMode : public IModeStrategy {
public:
  EmergencyMode(RoadApproach &n, RoadApproach &s, RoadApproach &e, RoadApproach &w,
                DisplayManager &display, const char *modeName)
      : north(n), south(s), east(e), west(w), display(display), modeName(modeName) {}

  void enter() override {
    north.show(LightColor::Red);
    south.show(LightColor::Red);
    east.show(LightColor::Red);
    west.show(LightColor::Red);
  }
  void tick() override {
    display.showStatus(modeName, "ALL RED", -1);
  }
  const char *phaseCode() const override { return "ALL_RED"; }
  int remainingSeconds() const override { return -1; }
  void getLightColors(LightColor &n, LightColor &s, LightColor &e, LightColor &w) const override {
    n = LightColor::Red; s = LightColor::Red;
    e = LightColor::Red; w = LightColor::Red;
  }
  const char *displayLine() const override { return "ALL RED"; }

private:
  RoadApproach &north, &south, &east, &west;
  DisplayManager &display;
  const char *modeName;
};

// MAINTENANCE mode: all LEDs off, LCD shows "MAINTENANCE". Operators use it
// to safely service the hardware. W3 — MQTT-only (no physical button).
// Exits only when another mode command arrives (auto/night/priority/emergency).
class MaintenanceMode : public IModeStrategy {
public:
  MaintenanceMode(RoadApproach &n, RoadApproach &s, RoadApproach &e, RoadApproach &w,
                  DisplayManager &display, const char *modeName)
      : north(n), south(s), east(e), west(w), display(display), modeName(modeName) {}

  void enter() override {
    north.turnOff();
    south.turnOff();
    east.turnOff();
    west.turnOff();
  }
  void tick() override {
    display.showStatus(modeName, "ALL OFF", -1);
  }
  const char *phaseCode() const override { return "MAINTENANCE"; }
  int remainingSeconds() const override { return -1; }
  void getLightColors(LightColor &n, LightColor &s, LightColor &e, LightColor &w) const override {
    n = LightColor::Off; s = LightColor::Off;
    e = LightColor::Off; w = LightColor::Off;
  }
  const char *displayLine() const override { return "ALL OFF"; }

private:
  RoadApproach &north, &south, &east, &west;
  DisplayManager &display;
  const char *modeName;
};

class DisplayManager {
public:
  void begin() {
    lcd.init();
    lcd.backlight();
    showMessage("TRAFFIC SYSTEM", "Starting...");
  }

  void showStatus(const char *mode, const char *line2, int remainingSeconds) {
    if (millis() - lastUpdateMs < 300 && remainingSeconds == lastRemainingSeconds) {
      return;
    }

    lastUpdateMs = millis();
    lastRemainingSeconds = remainingSeconds;

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(fit(mode));
    lcd.setCursor(0, 1);

    if (remainingSeconds >= 0) {
      String value = String(line2) + " " + String(remainingSeconds) + "s";
      lcd.print(fit(value));
      Serial.print(mode);
      Serial.print(" | ");
      Serial.print(line2);
      Serial.print(" | remaining ");
      Serial.print(remainingSeconds);
      Serial.println("s");
      return;
    }

    lcd.print(fit(line2));
    Serial.print(mode);
    Serial.print(" | ");
    Serial.println(line2);
  }

private:
  LiquidCrystal_I2C lcd = LiquidCrystal_I2C(0x27, 16, 2);
  unsigned long lastUpdateMs = 0;
  int lastRemainingSeconds = -99;

  void showMessage(const char *line1, const char *line2) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(fit(line1));
    lcd.setCursor(0, 1);
    lcd.print(fit(line2));
  }

  String fit(String value) {
    if (value.length() > 16) {
      return value.substring(0, 16);
    }

    while (value.length() < 16) {
      value += ' ';
    }
    return value;
  }
};

class IntersectionController {
public:
  IntersectionController(RoadApproach &north, RoadApproach &south, RoadApproach &east, RoadApproach &west,
                         ModeManager &modeManager,
                         DisplayManager &display,
                         PhaseConfig &phaseConfig)
      : north(north), south(south), east(east), west(west),
        modeManager(modeManager), display(display), phaseConfig(phaseConfig),
        autoMode(north, south, east, west, display, phaseConfig, modeNameFor(TrafficMode::Auto)),
        nightMode(north, south, east, west, display, modeNameFor(TrafficMode::Night)),
        priorityNSMode(north, south, east, west, display, modeNameFor(TrafficMode::PriorityNS)),
        priorityEWMode(north, south, east, west, display, modeNameFor(TrafficMode::PriorityEW)),
        emergencyMode(north, south, east, west, display, modeNameFor(TrafficMode::Emergency)),
        maintenanceMode(north, south, east, west, display, modeNameFor(TrafficMode::Maintenance)),
        strategies{&autoMode, &nightMode, &priorityNSMode, &priorityEWMode, &emergencyMode, &maintenanceMode},
        _current(&autoMode) {}

  void begin() {
    north.begin();
    south.begin();
    east.begin();
    west.begin();
    _current->enter();
  }

  const char *phaseCode() const {
    return _current->phaseCode();
  }

  int remainingSeconds() const {
    return _current->remainingSeconds();
  }

  LightColor northLightColor() const {
    return cachedNorth;
  }

  LightColor southLightColor() const {
    return cachedSouth;
  }

  LightColor eastLightColor() const {
    return cachedEast;
  }

  LightColor westLightColor() const {
    return cachedWest;
  }

  void update() {
    if (modeManager.update()) {
      IModeStrategy *next = strategies[static_cast<int>(modeManager.getMode())];
      if (next != _current) {
        _current = next;
        _current->enter();
      }
    }
    _current->getLightColors(cachedNorth, cachedSouth, cachedEast, cachedWest);
    _current->tick();
  }

private:
  // References must be declared BEFORE the strategy instances that bind them,
  // because C++ initializes members in declaration order.
  RoadApproach &north;
  RoadApproach &south;
  RoadApproach &east;
  RoadApproach &west;
  ModeManager &modeManager;
  DisplayManager &display;
  PhaseConfig &phaseConfig;

  // Owned strategy instances (value members — no heap).
  AutoMode autoMode;
  NightMode nightMode;
  PriorityNSMode priorityNSMode;
  PriorityEWMode priorityEWMode;
  EmergencyMode emergencyMode;
  MaintenanceMode maintenanceMode;

  IModeStrategy *strategies[6];  // Auto, Night, PriorityNS, PriorityEW, Emergency, Maintenance
  IModeStrategy *_current;

  // Cached colors queried by MqttClientManager::publishStatus.
  LightColor cachedNorth = LightColor::Off;
  LightColor cachedSouth = LightColor::Off;
  LightColor cachedEast = LightColor::Off;
  LightColor cachedWest = LightColor::Off;

  const char *modeNameFor(TrafficMode mode) {
    switch (mode) {
    case TrafficMode::Auto:        return "AUTO";
    case TrafficMode::Night:       return "NIGHT";
    case TrafficMode::PriorityNS:  return "PRIORITY NS";
    case TrafficMode::PriorityEW:  return "PRIORITY EW";
    case TrafficMode::Emergency:   return "EMERGENCY";
    case TrafficMode::Maintenance: return "MAINTENANCE";
    }
    return "UNKNOWN";
  }
};

const char *colorName(LightColor color) {
  switch (color) {
  case LightColor::Red:
    return "RED";
  case LightColor::Yellow:
    return "YELLOW";
  case LightColor::Green:
    return "GREEN";
  case LightColor::Off:
    return "OFF";
  }

  return "OFF";
}

class BoundedWiFiClient : public WiFiClient {
public:
  using WiFiClient::connect;

  int connect(IPAddress ip, uint16_t port) override {
    return WiFiClient::connect(ip, port, MqttConfig::TCP_CONNECT_TIMEOUT_MS);
  }

  int connect(const char *host, uint16_t port) override {
    return WiFiClient::connect(host, port, MqttConfig::TCP_CONNECT_TIMEOUT_MS);
  }
};

class MqttClientManager {
public:
  MqttClientManager(ModeManager &modeManager, IntersectionController &controller, PhaseConfig &phaseConfig)
      : modeManager(modeManager), controller(controller), phaseConfig(phaseConfig), mqtt(wifiClient) {}

  void begin() {
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    mqtt.setServer(MqttConfig::BROKER_HOST, MqttConfig::BROKER_PORT);
    mqtt.setCallback(onMessageStatic);
    mqtt.setSocketTimeout(MqttConfig::MQTT_SOCKET_TIMEOUT_SECONDS);
    if (!mqtt.setBufferSize(MqttConfig::MQTT_BUFFER_SIZE)) {
      Serial.println("MQTT buffer allocation failed");
    }

    buildClientId();
    instance = this;
    connectWiFi();
  }

  void update() {
    if (WiFi.status() != WL_CONNECTED) {
      connectWiFi();
      return;
    }

    if (!mqtt.connected()) {
      connectMqtt();
    }

    if (!mqtt.connected()) {
      return;
    }

    mqtt.loop();

    if (deferStatusUntilNextUpdate) {
      deferStatusUntilNextUpdate = false;
      return;
    }

    if (modeManager.revision() != lastPublishedModeRevision || millis() - lastStatusMs >= 2000) {
      publishStatus();
    }
  }

private:
  ModeManager &modeManager;
  IntersectionController &controller;
  PhaseConfig &phaseConfig;
  BoundedWiFiClient wifiClient;
  PubSubClient mqtt;
  String clientId;
  unsigned long lastWiFiAttemptMs = 0;
  unsigned long lastMqttAttemptMs = 0;
  unsigned long lastStatusMs = 0;
  uint32_t lastPublishedModeRevision = 0;
  bool hasAttemptedWiFi = false;
  bool hasAttemptedMqtt = false;
  bool deferStatusUntilNextUpdate = false;
  static MqttClientManager *instance;

  void connectWiFi() {
    if (WiFi.status() == WL_CONNECTED) {
      return;
    }

    if (hasAttemptedWiFi && millis() - lastWiFiAttemptMs < MqttConfig::WIFI_RETRY_MS) {
      return;
    }

    hasAttemptedWiFi = true;
    lastWiFiAttemptMs = millis();
    Serial.print("Connecting WiFi ");
    Serial.println(MqttConfig::WIFI_SSID);
    WiFi.begin(MqttConfig::WIFI_SSID, MqttConfig::WIFI_PASSWORD, 6);
  }

  void connectMqtt() {
    if (hasAttemptedMqtt && millis() - lastMqttAttemptMs < MqttConfig::MQTT_RETRY_MS) {
      return;
    }

    hasAttemptedMqtt = true;
    lastMqttAttemptMs = millis();
    Serial.print("Connecting MQTT ");
    Serial.println(MqttConfig::BROKER_HOST);

    unsigned long startedMs = millis();
    if (mqtt.connect(clientId.c_str())) {
      hasAttemptedMqtt = false;
      Serial.println("MQTT connected");
      if (!mqtt.subscribe(MqttConfig::COMMAND_TOPIC, 1)) {
        Serial.println("MQTT command subscription failed");
      }
      publishStatus();
      return;
    }

    Serial.print("MQTT failed rc=");
    Serial.print(mqtt.state());
    Serial.print(" after ");
    Serial.print(millis() - startedMs);
    Serial.println("ms");
  }

  static void onMessageStatic(char *topic, byte *payload, unsigned int length) {
    if (instance != nullptr) {
      instance->onMessage(topic, payload, length);
    }
  }

  void onMessage(char *topic, byte *payload, unsigned int length) {
    String body;
    body.reserve(length);
    for (unsigned int index = 0; index < length; index++) {
      body += static_cast<char>(payload[index]);
    }
    body.trim();

    // SET_PHASE_CONFIG: { "phase": "NS_GREEN", "durationSeconds": 12 }
    // Recognized BEFORE mode parsing because the payload shape overlaps
    // (also has a "command" field in some clients).
    String phaseName = extractJsonString(body, "phase");
    String durStr = extractJsonString(body, "durationSeconds");
    if (phaseName.length() > 0 && durStr.length() > 0) {
      uint8_t idx = phaseToIndex(phaseName);
      uint8_t secs = static_cast<uint8_t>(durStr.toInt());
      int commandId = extractJsonInt(body, "commandId");
      if (phaseConfig.setDuration(idx, secs)) {
        publishAck(commandId, "SET_PHASE_CONFIG", "acknowledged", "Phase duration updated");
      } else {
        publishAck(commandId, "SET_PHASE_CONFIG", "rejected", "Invalid phase or duration");
      }
      Serial.print("MQTT command on ");
      Serial.print(topic);
      Serial.print(": SET_PHASE_CONFIG phase=");
      Serial.print(phaseName);
      Serial.print(" duration=");
      Serial.println(secs);
      return;
    }

    String command = extractJsonString(body, "command");
    if (command.length() == 0) {
      command = extractJsonString(body, "modeCode");
      if (command.length() > 0 && !command.startsWith("SET_")) {
        command = "SET_" + command;
      }
    }

    int commandId = extractJsonInt(body, "commandId");
    if (command.length() == 0 && !body.startsWith("{")) {
      int separator = body.indexOf('|');
      command = separator >= 0 ? body.substring(separator + 1) : body;
      commandId = separator >= 0 ? body.substring(0, separator).toInt() : 0;
    }

    String canonicalCommand;
    CommandApplyResult result = modeManager.applyExternalCommand(command, canonicalCommand);
    if (result == CommandApplyResult::Applied) {
      deferStatusUntilNextUpdate = true;
      publishAck(commandId, canonicalCommand, "acknowledged", "Mode changed");
    } else if (result == CommandApplyResult::AlreadyActive) {
      publishAck(commandId, canonicalCommand, "acknowledged", "Mode already active");
    } else {
      publishAck(commandId, "UNKNOWN", "rejected", "Unsupported command");
    }

    Serial.print("MQTT command on ");
    Serial.print(topic);
    Serial.print(": ");
    Serial.println(command);
  }

  void publishAck(int commandId, const String &command, const char *status, const char *message) {
    if (!mqtt.connected()) {
      return;
    }

    String payload = "{";
    payload += "\"intersectionId\":1,";
    payload += "\"deviceId\":\"";
    payload += MqttConfig::DEVICE_ID;
    payload += "\",";
    payload += "\"commandId\":";
    payload += String(commandId);
    payload += ",";
    payload += "\"command\":\"";
    payload += command;
    payload += "\",";
    payload += "\"status\":\"";
    payload += status;
    payload += "\",";
    payload += "\"message\":\"";
    payload += message;
    payload += "\",";
    appendUptimeMs(payload);
    payload += "}";
    if (!mqtt.publish(MqttConfig::ACK_TOPIC, payload.c_str())) {
      Serial.println("MQTT ACK publish failed");
    }
  }

  void publishStatus() {
    if (!mqtt.connected()) {
      return;
    }

    lastStatusMs = millis();
    lastPublishedModeRevision = modeManager.revision();
    String payload = "{";
    payload += "\"intersectionId\":1,";
    payload += "\"deviceId\":\"";
    payload += MqttConfig::DEVICE_ID;
    payload += "\",";
    payload += "\"modeCode\":\"";
    payload += modeCode();
    payload += "\",";
    payload += "\"phaseCode\":\"";
    payload += controller.phaseCode();
    payload += "\",";
    payload += "\"remainingSeconds\":";
    payload += String(controller.remainingSeconds());
    payload += ",";
    payload += "\"signals\":[";
    payload += signalJson("NORTH", "NORTH_MAIN", controller.northLightColor()) + ",";
    payload += signalJson("SOUTH", "SOUTH_MAIN", controller.southLightColor()) + ",";
    payload += signalJson("EAST", "EAST_MAIN", controller.eastLightColor()) + ",";
    payload += signalJson("WEST", "WEST_MAIN", controller.westLightColor());
    payload += "],";
    appendUptimeMs(payload);
    payload += "}";
    if (!mqtt.publish(MqttConfig::STATUS_TOPIC, payload.c_str())) {
      Serial.println("MQTT status publish failed");
    }
  }

  void buildClientId() {
    String suffix = String(static_cast<uint32_t>(ESP.getEfuseMac() & 0xFFFFFFULL), HEX);
    suffix.toUpperCase();
    while (suffix.length() < 6) {
      suffix = "0" + suffix;
    }

    clientId = String(MqttConfig::CLIENT_ID_PREFIX) + "-" + suffix;
  }

  const char *modeCode() const {
    switch (modeManager.getMode()) {
    case TrafficMode::Auto:
      return "AUTO";
    case TrafficMode::Night:
      return "NIGHT";
    case TrafficMode::PriorityNS:
      return "PRIORITY_NS";
    case TrafficMode::PriorityEW:
      return "PRIORITY_EW";
    case TrafficMode::Emergency:
      return "EMERGENCY";
    case TrafficMode::Maintenance:
      return "MAINTENANCE";
    }

    return "AUTO";
  }

  String signalJson(const char *approach, const char *signal, LightColor color) const {
    String value = "{\"approach\":\"";
    value += approach;
    value += "\",\"signal\":\"";
    value += signal;
    value += "\",\"color\":\"";
    value += colorName(color);
    value += "\"}";
    return value;
  }

  String extractJsonString(const String &json, const String &key) const {
    String pattern = "\"";
    pattern += key;
    pattern += "\"";
    int keyIndex = json.indexOf(pattern);
    if (keyIndex < 0) {
      return "";
    }

    int colonIndex = json.indexOf(':', keyIndex);
    if (colonIndex < 0) {
      return "";
    }

    int startQuote = json.indexOf('"', colonIndex + 1);
    if (startQuote < 0) {
      return "";
    }

    int endQuote = json.indexOf('"', startQuote + 1);
    if (endQuote < 0) {
      return "";
    }

    return json.substring(startQuote + 1, endQuote);
  }

  int extractJsonInt(const String &json, const String &key) const {
    String pattern = "\"";
    pattern += key;
    pattern += "\"";
    int keyIndex = json.indexOf(pattern);
    if (keyIndex < 0) {
      return 0;
    }

    int colonIndex = json.indexOf(':', keyIndex);
    if (colonIndex < 0) {
      return 0;
    }

    int valueStart = colonIndex + 1;
    while (valueStart < json.length() && isJsonWhitespace(json[valueStart])) {
      valueStart++;
    }

    int valueEnd = valueStart;
    while (valueEnd < json.length() && isDigit(json[valueEnd])) {
      valueEnd++;
    }

    return json.substring(valueStart, valueEnd).toInt();
  }

  bool isJsonWhitespace(char value) const {
    return value == ' ' || value == '\t' || value == '\r' || value == '\n';
  }

  void appendUptimeMs(String &payload) const {
    payload += "\"uptimeMs\":";
    payload += String(millis());
  }

  // Map phase code -> PhaseConfig index. Returns 255 (PHASE_COUNT) on miss.
  static uint8_t phaseToIndex(const String &phase) {
    if (phase == "NS_GREEN")  return PhaseConfig::NS_GREEN_IDX;
    if (phase == "NS_YELLOW") return PhaseConfig::NS_YELLOW_IDX;
    if (phase == "EW_GREEN")  return PhaseConfig::EW_GREEN_IDX;
    if (phase == "EW_YELLOW") return PhaseConfig::EW_YELLOW_IDX;
    return PhaseConfig::PHASE_COUNT;  // sentinel for "invalid"
  }
};

MqttClientManager *MqttClientManager::instance = nullptr;

TrafficLight northLight(Pins::NS_RED, Pins::NS_YELLOW, Pins::NS_GREEN);
TrafficLight southLight(Pins::NS_RED, Pins::NS_YELLOW, Pins::NS_GREEN);
TrafficLight eastLight(Pins::EW_RED, Pins::EW_YELLOW, Pins::EW_GREEN);
TrafficLight westLight(Pins::EW_RED, Pins::EW_YELLOW, Pins::EW_GREEN);
RoadApproach northApproach("NORTH", "North approach", northLight);
RoadApproach southApproach("SOUTH", "South approach", southLight);
RoadApproach eastApproach("EAST", "East approach", eastLight);
RoadApproach westApproach("WEST", "West approach", westLight);
ModeManager modeManager;
DisplayManager display;
PhaseConfig phaseConfig;
IntersectionController controller(northApproach, southApproach, eastApproach, westApproach, modeManager, display, phaseConfig);
MqttClientManager mqttManager(modeManager, controller, phaseConfig);

void setup() {
  modeManager.begin();
  display.begin();
  phaseConfig.begin();
  controller.begin();
  mqttManager.begin();
}

void loop() {
  controller.update();
  mqttManager.update();
}
