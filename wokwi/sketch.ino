#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <WiFi.h>
#include <PubSubClient.h>

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
                         DisplayManager &display)
      : north(north), south(south), east(east), west(west), modeManager(modeManager), display(display) {}

  void begin() {
    north.begin();
    south.begin();
    east.begin();
    west.begin();
    phaseStartedMs = millis();
    setAutoPhase(0);
  }

  const char *phaseCode() const {
    switch (modeManager.getMode()) {
    case TrafficMode::Auto:
      return phases[currentPhase].code;
    case TrafficMode::Night:
      return "YELLOW_BLINK";
    case TrafficMode::PriorityNS:
      return "NS_PRIORITY";
    case TrafficMode::PriorityEW:
      return "EW_PRIORITY";
    case TrafficMode::Emergency:
      return "ALL_RED";
    }

    return "UNKNOWN";
  }

  int remainingSeconds() const {
    if (modeManager.getMode() != TrafficMode::Auto) {
      return -1;
    }

    const TrafficPhase &phase = phases[currentPhase];
    unsigned long elapsedMs = millis() - phaseStartedMs;
    unsigned long durationMs = static_cast<unsigned long>(phase.durationSeconds) * 1000UL;
    if (elapsedMs >= durationMs) {
      return 0;
    }

    return static_cast<int>((durationMs - elapsedMs + 999UL) / 1000UL);
  }

  LightColor northLightColor() const {
    return northState;
  }

  LightColor southLightColor() const {
    return southState;
  }

  LightColor eastLightColor() const {
    return eastState;
  }

  LightColor westLightColor() const {
    return westState;
  }

  void update() {
    if (modeManager.update()) {
      resetForMode();
    }

    switch (modeManager.getMode()) {
    case TrafficMode::Auto:
      runAuto();
      break;
    case TrafficMode::Night:
      runNight();
      break;
    case TrafficMode::PriorityNS:
      runPriority(true);
      break;
    case TrafficMode::PriorityEW:
      runPriority(false);
      break;
    case TrafficMode::Emergency:
      runEmergency();
      break;
    }
  }

private:
  RoadApproach &north;
  RoadApproach &south;
  RoadApproach &east;
  RoadApproach &west;
  ModeManager &modeManager;
  DisplayManager &display;

  const TrafficPhase phases[4] = {
      {"NS_GREEN", "NS GREEN", LightColor::Green, LightColor::Green, LightColor::Red, LightColor::Red, 8},
      {"NS_YELLOW", "NS YELLOW", LightColor::Yellow, LightColor::Yellow, LightColor::Red, LightColor::Red, 3},
      {"EW_GREEN", "EW GREEN", LightColor::Red, LightColor::Red, LightColor::Green, LightColor::Green, 8},
      {"EW_YELLOW", "EW YELLOW", LightColor::Red, LightColor::Red, LightColor::Yellow, LightColor::Yellow, 3},
  };

  uint8_t currentPhase = 0;
  unsigned long phaseStartedMs = 0;
  unsigned long nightBlinkMs = 0;
  bool nightYellowOn = false;
  LightColor northState = LightColor::Off;
  LightColor southState = LightColor::Off;
  LightColor eastState = LightColor::Off;
  LightColor westState = LightColor::Off;

  void resetForMode() {
    turnAllOff();
    phaseStartedMs = millis();
    nightBlinkMs = millis();
    nightYellowOn = false;

    if (modeManager.getMode() == TrafficMode::Auto) {
      setAutoPhase(0);
    }
  }

  void runAuto() {
    const TrafficPhase &phase = phases[currentPhase];
    unsigned long elapsedMs = millis() - phaseStartedMs;
    unsigned long durationMs = static_cast<unsigned long>(phase.durationSeconds) * 1000UL;

    if (elapsedMs >= durationMs) {
      setAutoPhase((currentPhase + 1) % 4);
      return;
    }

    int remainingSeconds = static_cast<int>((durationMs - elapsedMs + 999UL) / 1000UL);
    display.showStatus(modeManager.modeName(), phase.name, remainingSeconds);
  }

  void runNight() {
    if (millis() - nightBlinkMs >= 500) {
      nightBlinkMs = millis();
      nightYellowOn = !nightYellowOn;
      applyAll(nightYellowOn ? LightColor::Yellow : LightColor::Off);
    }

    display.showStatus(modeManager.modeName(), nightYellowOn ? "YELLOW ON" : "YELLOW OFF", -1);
  }

  void runPriority(bool northSouthPriority) {
    applyColors(
        northSouthPriority ? LightColor::Green : LightColor::Red,
        northSouthPriority ? LightColor::Green : LightColor::Red,
        northSouthPriority ? LightColor::Red : LightColor::Green,
        northSouthPriority ? LightColor::Red : LightColor::Green);
    display.showStatus(modeManager.modeName(), northSouthPriority ? "NS GO" : "EW GO", -1);
  }

  void runEmergency() {
    applyAll(LightColor::Red);
    display.showStatus(modeManager.modeName(), "ALL RED", -1);
  }

  void setAutoPhase(uint8_t nextPhase) {
    currentPhase = nextPhase;
    phaseStartedMs = millis();
    const TrafficPhase &phase = phases[currentPhase];
    applyColors(phase.northColor, phase.southColor, phase.eastColor, phase.westColor);
  }

  void applyColors(LightColor northColor, LightColor southColor, LightColor eastColor, LightColor westColor) {
    northState = northColor;
    southState = southColor;
    eastState = eastColor;
    westState = westColor;
    north.show(northColor);
    south.show(southColor);
    east.show(eastColor);
    west.show(westColor);
  }

  void applyAll(LightColor color) {
    applyColors(color, color, color, color);
  }

  void turnAllOff() {
    northState = LightColor::Off;
    southState = LightColor::Off;
    eastState = LightColor::Off;
    westState = LightColor::Off;
    north.turnOff();
    south.turnOff();
    east.turnOff();
    west.turnOff();
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
  MqttClientManager(ModeManager &modeManager, IntersectionController &controller)
      : modeManager(modeManager), controller(controller), mqtt(wifiClient) {}

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
IntersectionController controller(northApproach, southApproach, eastApproach, westApproach, modeManager, display);
MqttClientManager mqttManager(modeManager, controller);

void setup() {
  modeManager.begin();
  display.begin();
  controller.begin();
  mqttManager.begin();
}

void loop() {
  controller.update();
  mqttManager.update();
}
