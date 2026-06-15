#include <Wire.h>
#include <LiquidCrystal_I2C.h>

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

struct TrafficPhase {
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

private:
  TrafficMode mode = TrafficMode::Auto;
  bool priorityNextNS = false;
  bool lastAutoState = HIGH;
  bool lastNightState = HIGH;
  bool lastPriorityState = HIGH;
  bool lastEmergencyState = HIGH;
  unsigned long lastButtonMs = 0;
  static constexpr unsigned long debounceMs = 180;

  bool setMode(TrafficMode nextMode) {
    if (mode == nextMode) {
      return false;
    }

    mode = nextMode;
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

  bool readSerialCommand() {
    if (!Serial.available()) {
      return false;
    }

    String command = Serial.readStringUntil('\n');
    command.trim();
    command.toLowerCase();

    if (command == "a" || command == "auto") {
      return setMode(TrafficMode::Auto);
    }

    if (command == "n" || command == "night") {
      return setMode(TrafficMode::Night);
    }

    if (command == "p" || command == "priority" || command == "priority_ns" || command == "priority ns") {
      priorityNextNS = true;
      return setMode(TrafficMode::PriorityNS);
    }

    if (command == "pe" || command == "priority_ew" || command == "priority ew") {
      priorityNextNS = false;
      return setMode(TrafficMode::PriorityEW);
    }

    if (command == "e" || command == "emergency") {
      return setMode(TrafficMode::Emergency);
    }

    Serial.print("Unknown command: ");
    Serial.println(command);
    return false;
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
      {"NS GREEN", LightColor::Green, LightColor::Green, LightColor::Red, LightColor::Red, 8},
      {"NS YELLOW", LightColor::Yellow, LightColor::Yellow, LightColor::Red, LightColor::Red, 3},
      {"EW GREEN", LightColor::Red, LightColor::Red, LightColor::Green, LightColor::Green, 8},
      {"EW YELLOW", LightColor::Red, LightColor::Red, LightColor::Yellow, LightColor::Yellow, 3},
  };

  uint8_t currentPhase = 0;
  unsigned long phaseStartedMs = 0;
  unsigned long nightBlinkMs = 0;
  bool nightYellowOn = false;

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
    north.show(northColor);
    south.show(southColor);
    east.show(eastColor);
    west.show(westColor);
  }

  void applyAll(LightColor color) {
    applyColors(color, color, color, color);
  }

  void turnAllOff() {
    north.turnOff();
    south.turnOff();
    east.turnOff();
    west.turnOff();
  }
};

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

void setup() {
  modeManager.begin();
  display.begin();
  controller.begin();
}

void loop() {
  controller.update();
}
