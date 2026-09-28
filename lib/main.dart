#include <Wire.h>
#include <LiquidCrystal_I2C.h>

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#include <Preferences.h>
#include <WiFi.h>

// ============================================================
// LCD
// ============================================================
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ============================================================
// ?Ä ?§Ï†ï
// ============================================================
const int startPadPin    = 4;
const int finishButtonPin = 19;
const int resetButtonPin  = 23;
const int buzzerPin       = 18;

// ???®Îìú HC-05
HardwareSerial TopBT(2);
String topMessage = "";

// ============================================================
// BLE
// ============================================================
#define BLE_DEVICE_NAME "SC TIMER"

#define SERVICE_UUID \
  "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"

#define TX_CHARACTERISTIC_UUID \
  "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

BLEServer* bleServer = nullptr;
BLECharacteristic* timerCharacteristic = nullptr;

bool phoneConnected = false;

unsigned long lastBleTimeSend = 0;

const unsigned long bleTimeInterval = 100;

// ============================================================
// Í≥µÎèô ?∞Îèô ?àÎ†® Wi-Fi
// ESP32 ?êÏ≤¥ AP + TCP ?úÎ≤Ñ
// ??Í∏∞Î≥∏Í∞? 192.168.4.1 : 4210
// ============================================================
const char* GROUP_WIFI_SSID = "SC_TIMER_GROUP";
const char* GROUP_WIFI_PASSWORD = "speed4210";

WiFiServer groupServer(4210);

const int MAX_GROUP_CLIENTS = 4;
WiFiClient groupClients[MAX_GROUP_CLIENTS];
String groupRxBuffer[MAX_GROUP_CLIENTS];

String groupOwnerId = "";
String groupOwnerName = "";

void readGroupClientCommands();
void handleGroupCommand(int slot, const String& command);
void sendWifiToClient(int slot, const String& message);

unsigned long lastWifiTimeSend = 0;
const unsigned long wifiTimeInterval = 100;

void setupGroupWifi();
void acceptGroupClients();
void cleanupGroupClients();
void sendWifiMessage(const String& message);
void sendCurrentStateToWifi();
void sendTop10ToWifi();
void updateWifiTimer();


// ============================================================
// TOP 10 ?Ä??
// ============================================================
Preferences preferences;

const int TOP_COUNT = 10;

// Î∞ÄÎ¶¨Ï¥à ?®ÏúÑÎ°??Ä??
unsigned long topTimes[TOP_COUNT];

// Îπ?Í∏∞Î°ù ?úÏãú??
const unsigned long EMPTY_TIME = 0xFFFFFFFF;

// ============================================================
// Î≤ÑÌäº Debounce
// ============================================================
const unsigned long debounceTime = 5;

// ============================================================
// ?Ä?¥Î®∏ ?ÅÌÉú
// ============================================================
enum TimerState {
  READY_STATE,
  HOLD_STATE,
  COUNTDOWN_STATE,
  RUNNING_STATE,
  FINISHED_STATE,
  FALSE_START_STATE
};

TimerState currentState = READY_STATE;

// ============================================================
// Î∞úÌåê ?ÅÌÉú
// ============================================================
bool footPressed = false;

bool lastRawFootState = HIGH;
bool stableFootState = HIGH;

unsigned long footDebounceTime = 0;

// Finish
bool lastFinishState = HIGH;
unsigned long finishDebounceTime = 0;

// Reset
bool lastResetState = HIGH;
unsigned long resetDebounceTime = 0;

// ============================================================
// ?úÍ∞Ñ
// ============================================================
unsigned long stateStartTime = 0;
unsigned long raceStartTime = 0;
unsigned long raceStartMicros = 0;
unsigned long scheduledGoMicros = 0;
volatile unsigned long footReleaseEdgeUs = 0;
volatile bool footReleaseEdgePending = false;

unsigned long reactionTime = 0;
unsigned long finishTime = 0;
unsigned long lastLcdUpdate = 0;

bool reactionCaptured = false;
bool detailedFalseStartScreen = false;
int countdownStep = 0;

// ============================================================
// ?®Ïàò ?†Ïñ∏
// ============================================================
void setupBle();

void sendBleMessage(const String& message);
void sendCurrentStateToBle();

void loadTop10();
void saveTop10();
void addTop10Record(unsigned long newTime);
void sendTop10ToBle();
void printTop10Serial();

void checkStartPad();
void IRAM_ATTR onStartPadChange();
void handleFootPress();
void handleFootRelease();

void updateRaceState();
void beginCountdown();
void runCountdown(unsigned long now);
void startRaceTimer();
void triggerFalseStart();

void checkFinishButton();
void stopRaceTimer();

void checkResetButton();
void resetTimer();

void updateTimerDisplay();
void updateBleTimer();

void printTimeValue(unsigned long milliseconds);

void showReadyScreen();
void showHoldScreen();

void receiveTopBluetooth();

// ============================================================
// BLE ?∞Í≤∞ ÏΩúÎ∞±
// ============================================================
class TimerServerCallbacks : public BLEServerCallbacks {

  void onConnect(BLEServer* server) override {

    phoneConnected = true;

    Serial.println("PHONE CONNECTED");

    sendBleMessage("CONNECTED");

    delay(30);

    sendCurrentStateToBle();

    delay(30);

    // ?∞Í≤∞?òÎ©¥ ?ÑÏû¨ TOP10 ?ÑÏÜ°
    sendTop10ToBle();
  }

  void onDisconnect(BLEServer* server) override {

    phoneConnected = false;

    Serial.println("PHONE DISCONNECTED");

    delay(200);

    server->getAdvertising()->start();

    Serial.println("BLE ADVERTISING RESTARTED");
  }
};

// ============================================================
// SETUP
// ============================================================
void setup() {

  Serial.begin(115200);

  pinMode(startPadPin, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(startPadPin), onStartPadChange, CHANGE);
  pinMode(finishButtonPin, INPUT_PULLUP);
  pinMode(resetButtonPin, INPUT_PULLUP);
  pinMode(buzzerPin, OUTPUT);

  // LCD
  Wire.begin(21, 22);

  lcd.init();
  lcd.backlight();

  // HC-05
  // RX = 16
  // TX = 17
  TopBT.begin(
    9600,
    SERIAL_8N1,
    16,
    17
  );

  // TOP10 ?Ä?•Í≥µÍ∞??úÏûë
  preferences.begin("sctimer", false);

  // ?Ä?•Îêú TOP10 Î∂àÎü¨?§Í∏∞
  loadTop10();

  // BLE - Í∏∞Ï°¥ Í∞úÏù∏ ?∞Í≤∞ ?†Ï?
  setupBle();

  // Wi-Fi - Í≥µÎèô ?∞Îèô ?àÎ†®
  setupGroupWifi();

  showReadyScreen();

  Serial.println();
  Serial.println("==============================");
  Serial.println("SC TIMER ESP32 V3.4 RESET OWNER KEEP READY");
  Serial.println("BLE READY");
  Serial.println("TOP HC-05 READY");
  Serial.println("TOP10 SYSTEM READY");
  Serial.println("GROUP WIFI SSID: SC_TIMER_GROUP");
  Serial.println("GROUP WIFI IP: 192.168.4.1");
  Serial.println("GROUP TCP PORT: 4210");
  Serial.println("==============================");

  printTop10Serial();
}

// ============================================================
// LOOP
// ============================================================
void loop() {

  checkStartPad();

  checkFinishButton();

  checkResetButton();

  receiveTopBluetooth();

  // Í≥µÎèô ?∞Îèô Wi-Fi ?ëÏÜç/?¥Ï†ú Í¥ÄÎ¶?
  acceptGroupClients();
  readGroupClientCommands();
  cleanupGroupClients();

  updateRaceState();

  updateTimerDisplay();

  updateBleTimer();

  // Í≥µÎèô ?∞Îèô Wi-Fi ?§ÏãúÍ∞??Ä?¥Î®∏
  updateWifiTimer();
}

// ============================================================
// Í≥µÎèô ?∞Îèô Wi-Fi Ï¥àÍ∏∞??
// ============================================================
void setupGroupWifi() {

  WiFi.mode(WIFI_AP);

  bool ok = WiFi.softAP(
    GROUP_WIFI_SSID,
    GROUP_WIFI_PASSWORD
  );

  if (!ok) {
    Serial.println("GROUP WIFI AP START FAILED");
    return;
  }

  groupServer.begin();
  groupServer.setNoDelay(true);

  Serial.println("GROUP WIFI AP STARTED");
  Serial.print("GROUP WIFI SSID: ");
  Serial.println(GROUP_WIFI_SSID);
  Serial.print("GROUP WIFI IP: ");
  Serial.println(WiFi.softAPIP());
  Serial.println("GROUP TCP PORT: 4210");
}

// ============================================================
// Í≥µÎèô ?∞Îèô ???¥Î????ëÏÜç
// ============================================================
void acceptGroupClients() {

  WiFiClient candidate = groupServer.available();

  if (!candidate) {
    return;
  }

  // Arduino ESP32 WiFiServer.available()?????ëÏÜçÎø??ÑÎãà??
  // Í∏∞Ï°¥ ?¥Îùº?¥Ïñ∏?∏Ïóê ?òÏã† ?∞Ïù¥?∞Í? ?àÏùÑ ?åÎèÑ Í∑??¥Îùº?¥Ïñ∏?∏Î? ?åÎ†§Ï§????àÎã§.
  // Í∞ôÏ? TCP ?åÏºì???§Î•∏ ?¨Î°Ø??Ï§ëÎ≥µ ?±Î°ù?òÎ©¥ CLAIM ?ÑÏÜ° ?úÍ∞Ñ ?∞Í≤∞???äÍ∏∏ ???àÏúºÎØÄÎ°?
  // remoteIP/remotePortÎ°??¥Î? ?±Î°ù???åÏºì?∏Ï? Î®ºÏ? ?ïÏù∏?úÎã§.
  for (int i = 0; i < MAX_GROUP_CLIENTS; i++) {
    if (groupClients[i] && groupClients[i].connected()) {
      if (groupClients[i].remoteIP() == candidate.remoteIP() &&
          groupClients[i].remotePort() == candidate.remotePort()) {
        return;
      }
    }
  }

  candidate.setNoDelay(true);

  for (int i = 0; i < MAX_GROUP_CLIENTS; i++) {

    if (!groupClients[i] || !groupClients[i].connected()) {

      if (groupClients[i]) {
        groupClients[i].stop();
      }

      groupClients[i] = candidate;
      groupRxBuffer[i] = "";

      Serial.print("GROUP WIFI PHONE CONNECTED SLOT ");
      Serial.println(i + 1);

      sendWifiToClient(i, "CONNECTED");
      sendWifiToClient(i, "STATE:READY");

      if (groupOwnerId.length() > 0) {
        sendWifiToClient(i, "OWNER|" + groupOwnerId + "|" + groupOwnerName);
      } else {
        sendWifiToClient(i, "RELEASED");
      }

      for (int rank = 0; rank < TOP_COUNT; rank++) {
        String message = "TOP" + String(rank + 1) + ":";
        if (topTimes[rank] == EMPTY_TIME) message += "--";
        else message += String(topTimes[rank] / 1000.0, 3);
        sendWifiToClient(i, message);
      }

      return;
    }
  }

  Serial.println("GROUP WIFI FULL");
  candidate.println("ERROR:GROUP_FULL");
  candidate.stop();
}

// ============================================================
// Í≥µÎèô ?∞Îèô ??-> ESP32 Î™ÖÎ†π ?òÏã†
// CLAIM|?¨Ïö©?êID|?¥Î¶Ñ
// RELEASE|?¨Ïö©?êID
// RUN_SAVED|?¨Ïö©?êID
// ============================================================
void readGroupClientCommands() {

  for (int i = 0; i < MAX_GROUP_CLIENTS; i++) {

    if (!groupClients[i] || !groupClients[i].connected()) {
      continue;
    }

    while (groupClients[i].available()) {

      char c = (char)groupClients[i].read();

      if (c == '\r') {
        continue;
      }

      if (c == '\n') {

        String command = groupRxBuffer[i];
        groupRxBuffer[i] = "";
        command.trim();

        if (command.length() > 0) {
          Serial.print("WIFI RX SLOT ");
          Serial.print(i + 1);
          Serial.print(": ");
          Serial.println(command);

          handleGroupCommand(i, command);
        }

      } else {

        if (groupRxBuffer[i].length() < 180) {
          groupRxBuffer[i] += c;
        } else {
          groupRxBuffer[i] = "";
        }
      }
    }
  }
}

void handleGroupCommand(int slot, const String& command) {

  if (command.startsWith("CLAIM|")) {

    int p1 = command.indexOf('|');
    int p2 = command.indexOf('|', p1 + 1);

    if (p2 < 0) {
      sendWifiToClient(slot, "ERROR:BAD_CLAIM");
      return;
    }

    String ownerId = command.substring(p1 + 1, p2);
    String ownerName = command.substring(p2 + 1);
    ownerId.trim();
    ownerName.trim();

    if (ownerId.length() == 0) {
      sendWifiToClient(slot, "ERROR:BAD_OWNER");
      return;
    }

    if (groupOwnerId.length() == 0 || groupOwnerId == ownerId) {

      groupOwnerId = ownerId;
      groupOwnerName = ownerName.length() > 0 ? ownerName : "PLAYER";

      sendWifiMessage(
        "CLAIMED|" +
        groupOwnerId +
        "|" +
        groupOwnerName
      );

      Serial.print("GROUP OWNER: ");
      Serial.println(groupOwnerName);

    } else {

      sendWifiToClient(
        slot,
        "BUSY|" +
        groupOwnerId +
        "|" +
        groupOwnerName
      );
    }

    return;
  }

  if (command.startsWith("RELEASE|")) {

    String ownerId = command.substring(8);
    ownerId.trim();

    if (groupOwnerId.length() == 0 || groupOwnerId == ownerId) {

      groupOwnerId = "";
      groupOwnerName = "";

      sendWifiMessage("RELEASED");

      Serial.println("GROUP OWNER RELEASED");
    }

    return;
  }

  if (command.startsWith("RUN_SAVED|")) {
    // ?±Ïù¥ ?êÍ∏∞ Í≥ÑÏ†ï ?Ä?•ÏùÑ ?ÑÎ£å?àÎã§???åÎ¶º.
    // Í≥ÑÏ∏° ?ÅÌÉú?êÎäî ?ÅÌñ•??Ï£ºÏ? ?äÍ≥† Î°úÍ∑∏Îß??®Í∏¥??
    Serial.println("GROUP RUN SAVED ACK");
    return;
  }
}

// ?πÏ†ï Í≥µÎèô?∞Îèô ?¥Î??????Ä?êÎßå ?ÑÏÜ°
void sendWifiToClient(int slot, const String& message) {

  if (slot < 0 || slot >= MAX_GROUP_CLIENTS) {
    return;
  }

  if (groupClients[slot] && groupClients[slot].connected()) {
    groupClients[slot].println(message);
  }
}

// ============================================================
// ?äÏñ¥Ïß?Í≥µÎèô?∞Îèô ???ïÎ¶¨
// ============================================================
void cleanupGroupClients() {

  for (int i = 0; i < MAX_GROUP_CLIENTS; i++) {

    if (groupClients[i] && !groupClients[i].connected()) {

      groupClients[i].stop();

      Serial.print("GROUP WIFI PHONE DISCONNECTED SLOT ");
      Serial.println(i + 1);
    }
  }
}

// ============================================================
// Í≥µÎèô?∞Îèô ???ÑÏ≤¥??Î©îÏãúÏßÄ ?ÑÏÜ°
// ============================================================
void sendWifiMessage(const String& message) {

  for (int i = 0; i < MAX_GROUP_CLIENTS; i++) {

    if (groupClients[i] && groupClients[i].connected()) {

      groupClients[i].println(message);
    }
  }

  Serial.print("WIFI SEND: ");
  Serial.println(message);
}

// ============================================================
// ?ÑÏû¨ ?ÅÌÉú Wi-Fi ?ÑÏÜ°
// ============================================================
void sendCurrentStateToWifi() {

  switch (currentState) {

    case READY_STATE:
      sendWifiMessage("STATE:READY");
      break;

    case HOLD_STATE:
      sendWifiMessage("STATE:HOLD");
      break;

    case COUNTDOWN_STATE:
      sendWifiMessage("STATE:COUNTDOWN");
      break;

    case RUNNING_STATE:
      sendWifiMessage("STATE:RUNNING");
      break;

    case FINISHED_STATE:
      sendWifiMessage("STATE:FINISHED");
      break;

    case FALSE_START_STATE:
      sendWifiMessage("STATE:FALSE_START");
      break;
  }
}

// ============================================================
// Í≥µÎèô?∞Îèô Wi-Fi ?§ÏãúÍ∞?TIME
// ============================================================
void updateWifiTimer() {

  if (currentState != RUNNING_STATE) {
    return;
  }

  unsigned long now = millis();

  if (now - lastWifiTimeSend < wifiTimeInterval) {
    return;
  }

  lastWifiTimeSend = now;

  unsigned long elapsed =
    now - raceStartTime;

  sendWifiMessage(
    "TIME " +
    String(
      elapsed / 1000.0,
      3
    )
  );
}

// ============================================================
// TOP10 Wi-Fi ?ÑÏÜ°
// ============================================================
void sendTop10ToWifi() {

  for (int i = 0; i < TOP_COUNT; i++) {

    String message =
      "TOP" +
      String(i + 1) +
      ":";

    if (topTimes[i] == EMPTY_TIME) {
      message += "--";
    } else {
      message += String(
        topTimes[i] / 1000.0,
        3
      );
    }

    sendWifiMessage(message);
    delay(10);
  }
}

// ============================================================
// BLE Ï¥àÍ∏∞??
// ============================================================
void setupBle() {

  BLEDevice::init(BLE_DEVICE_NAME);

  bleServer =
    BLEDevice::createServer();

  bleServer->setCallbacks(
    new TimerServerCallbacks()
  );

  BLEService* timerService =
    bleServer->createService(
      SERVICE_UUID
    );

  timerCharacteristic =
    timerService->createCharacteristic(
      TX_CHARACTERISTIC_UUID,

      BLECharacteristic::PROPERTY_READ |
      BLECharacteristic::PROPERTY_NOTIFY
    );

  timerCharacteristic->addDescriptor(
    new BLE2902()
  );

  timerCharacteristic->setValue(
    "SC TIMER READY"
  );

  timerService->start();

  BLEAdvertising* advertising =
    bleServer->getAdvertising();

  advertising->addServiceUUID(
    SERVICE_UUID
  );

  advertising->setScanResponse(true);

  advertising->start();

  Serial.println(
    "BLE ADVERTISING STARTED"
  );
}

// ============================================================
// BLE Î©îÏãúÏßÄ
// ============================================================
void sendBleMessage(
  const String& message
) {

  if (
    !phoneConnected ||
    timerCharacteristic == nullptr
  ) {
    return;
  }

  timerCharacteristic->setValue(
    message.c_str()
  );

  timerCharacteristic->notify();

  Serial.print("BLE SEND: ");
  Serial.println(message);
}

// ============================================================
// ?ÑÏû¨ ?ÅÌÉú BLE
// ============================================================
void sendCurrentStateToBle() {

  switch (currentState) {

    case READY_STATE:
      sendBleMessage("STATE:READY");
      break;

    case HOLD_STATE:
      sendBleMessage("STATE:HOLD");
      break;

    case COUNTDOWN_STATE:
      sendBleMessage("STATE:COUNTDOWN");
      break;

    case RUNNING_STATE:
      sendBleMessage("STATE:RUNNING");
      break;

    case FINISHED_STATE:
      sendBleMessage("STATE:FINISHED");
      break;

    case FALSE_START_STATE:
      sendBleMessage("STATE:FALSE_START");
      break;
  }
}

// ============================================================
// ?§ÏãúÍ∞?TIME BLE
// ============================================================
void updateBleTimer() {

  if (
    !phoneConnected ||
    currentState != RUNNING_STATE
  ) {
    return;
  }

  unsigned long now = millis();

  if (
    now - lastBleTimeSend <
    bleTimeInterval
  ) {
    return;
  }

  lastBleTimeSend = now;

  unsigned long elapsed =
    now - raceStartTime;

  sendBleMessage(
    "TIME " +
    String(
      elapsed / 1000.0,
      3
    )
  );
}

// ============================================================
// TOP10 Î∂àÎü¨?§Í∏∞
// ============================================================
void loadTop10() {

  for (
    int i = 0;
    i < TOP_COUNT;
    i++
  ) {

    String key =
      "top" + String(i);

    topTimes[i] =
      preferences.getULong(
        key.c_str(),
        EMPTY_TIME
      );
  }
}

// ============================================================
// TOP10 ?Ä??
// ============================================================
void saveTop10() {

  for (
    int i = 0;
    i < TOP_COUNT;
    i++
  ) {

    String key =
      "top" + String(i);

    preferences.putULong(
      key.c_str(),
      topTimes[i]
    );
  }
}

// ============================================================
// ??Í∏∞Î°ù TOP10 Ï∂îÍ? + ?êÎèô ?ïÎ†¨
// ============================================================
void addTop10Record(
  unsigned long newTime
) {

