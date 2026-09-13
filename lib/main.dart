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
// 핀 설정
// ============================================================
const int startPadPin    = 4;
const int finishButtonPin = 19;
const int resetButtonPin  = 23;
const int buzzerPin       = 18;

// 탑 패드 HC-05
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
// 공동 연동 훈련 Wi-Fi
// ESP32 자체 AP + TCP 서버
// 앱 기본값: 192.168.4.1 : 4210
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
// TOP 10 저장
// ============================================================
Preferences preferences;

const int TOP_COUNT = 10;

// 밀리초 단위로 저장
unsigned long topTimes[TOP_COUNT];

// 빈 기록 표시용
const unsigned long EMPTY_TIME = 0xFFFFFFFF;

// ============================================================
// 버튼 Debounce
// ============================================================
const unsigned long debounceTime = 5;

// ============================================================
// 타이머 상태
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
// 발판 상태
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
// 시간
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
// 함수 선언
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
// BLE 연결 콜백
// ============================================================
class TimerServerCallbacks : public BLEServerCallbacks {

  void onConnect(BLEServer* server) override {

    phoneConnected = true;

    Serial.println("PHONE CONNECTED");

    sendBleMessage("CONNECTED");

    delay(30);

    sendCurrentStateToBle();

    delay(30);

    // 연결되면 현재 TOP10 전송
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

  // TOP10 저장공간 시작
  preferences.begin("sctimer", false);

  // 저장된 TOP10 불러오기
  loadTop10();

  // BLE - 기존 개인 연결 유지
  setupBle();

  // Wi-Fi - 공동 연동 훈련
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

  // 공동 연동 Wi-Fi 접속/해제 관리
  acceptGroupClients();
  readGroupClientCommands();
  cleanupGroupClients();

  updateRaceState();

  updateTimerDisplay();

  updateBleTimer();

  // 공동 연동 Wi-Fi 실시간 타이머
  updateWifiTimer();
}

// ============================================================
// 공동 연동 Wi-Fi 초기화
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
// 공동 연동 새 휴대폰 접속
// ============================================================
void acceptGroupClients() {

  WiFiClient candidate = groupServer.available();

  if (!candidate) {
    return;
  }

  // Arduino ESP32 WiFiServer.available()는 새 접속뿐 아니라
  // 기존 클라이언트에 수신 데이터가 있을 때도 그 클라이언트를 돌려줄 수 있다.
  // 같은 TCP 소켓을 다른 슬롯에 중복 등록하면 CLAIM 전송 순간 연결이 끊길 수 있으므로
  // remoteIP/remotePort로 이미 등록된 소켓인지 먼저 확인한다.
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
// 공동 연동 앱 -> ESP32 명령 수신
// CLAIM|사용자ID|이름
// RELEASE|사용자ID
// RUN_SAVED|사용자ID
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
    // 앱이 자기 계정 저장을 완료했다는 알림.
    // 계측 상태에는 영향을 주지 않고 로그만 남긴다.
    Serial.println("GROUP RUN SAVED ACK");
    return;
  }
}

// 특정 공동연동 휴대폰 한 대에만 전송
void sendWifiToClient(int slot, const String& message) {

  if (slot < 0 || slot >= MAX_GROUP_CLIENTS) {
    return;
  }

  if (groupClients[slot] && groupClients[slot].connected()) {
    groupClients[slot].println(message);
  }
}

// ============================================================
// 끊어진 공동연동 폰 정리
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
// 공동연동 앱 전체에 메시지 전송
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
// 현재 상태 Wi-Fi 전송
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
// 공동연동 Wi-Fi 실시간 TIME
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
// TOP10 Wi-Fi 전송
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
// BLE 초기화
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
// BLE 메시지
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
// 현재 상태 BLE
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
// 실시간 TIME BLE
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
// TOP10 불러오기
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
// TOP10 저장
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
// 새 기록 TOP10 추가 + 자동 정렬
// ============================================================
void addTop10Record(
  unsigned long newTime
) {

  // 비정상적인 0 기록 방지
  if (newTime == 0) {
    return;
  }

  // 들어갈 위치 찾기
  int insertIndex = -1;

  for (
    int i = 0;
    i < TOP_COUNT;
    i++
  ) {

    if (
      topTimes[i] == EMPTY_TIME ||
      newTime < topTimes[i]
    ) {

      insertIndex = i;
      break;
    }
  }

  // TOP10에 못 들어가는 기록
  if (insertIndex == -1) {

    Serial.println(
      "RECORD NOT IN TOP10"
    );

    return;
  }

  // 뒤 기록 한 칸씩 밀기
  for (
    int i = TOP_COUNT - 1;
    i > insertIndex;
    i--
  ) {

    topTimes[i] =
      topTimes[i - 1];
  }

  // 새 기록 삽입
  topTimes[insertIndex] =
    newTime;

  // 플래시 저장
  saveTop10();

  Serial.print(
    "NEW TOP10 RECORD: "
  );

  Serial.print(
    newTime / 1000.0,
    3
  );

  Serial.print(
    " sec / RANK "
  );

  Serial.println(
    insertIndex + 1
  );

  printTop10Serial();
}

// ============================================================
// TOP10 BLE 전송
// ============================================================
void sendTop10ToBle() {

  if (!phoneConnected) {
    return;
  }

  Serial.println(
    "SEND TOP10 TO APP"
  );

  for (
    int i = 0;
    i < TOP_COUNT;
    i++
  ) {

    String message =
      "TOP" +
      String(i + 1) +
      ":";

    if (
      topTimes[i] ==
      EMPTY_TIME
    ) {

      message += "--";

    } else {

      message +=
        String(
          topTimes[i] /
          1000.0,
          3
        );
    }

    sendBleMessage(
      message
    );

    // BLE Notify 연속 전송 안정화
    delay(30);
  }
}

// ============================================================
// Serial TOP10 출력
// ============================================================
void printTop10Serial() {

  Serial.println();
  Serial.println(
    "========== TOP 10 =========="
  );

  for (
    int i = 0;
    i < TOP_COUNT;
    i++
  ) {

    Serial.print(
      i + 1
    );

    Serial.print(
      ". "
    );

    if (
      topTimes[i] ==
      EMPTY_TIME
    ) {

      Serial.println(
        "---"
      );

    } else {

      Serial.print(
        topTimes[i] /
        1000.0,
        3
      );

      Serial.println(
        " s"
      );
    }
  }

  Serial.println(
    "============================"
  );

  Serial.println();
}

// ============================================================
// START PAD edge capture - LCD/BLE/Wi-Fi와 무관하게 실제 핀 변화 순간 저장
// ============================================================
void IRAM_ATTR onStartPadChange() {
  if (digitalRead(startPadPin) == HIGH) {
    footReleaseEdgeUs = micros();
    footReleaseEdgePending = true;
  }
}

// ============================================================
// 스타트 발판
// ============================================================
void checkStartPad() {

  // ISR이 잡은 실제 발판 해제 시각을 먼저 처리
  if (footReleaseEdgePending) {
    noInterrupts();
    unsigned long releaseUs = footReleaseEdgeUs;
    footReleaseEdgePending = false;
    interrupts();

    if (currentState == RUNNING_STATE && !reactionCaptured) {
      long rtUs = (long)(releaseUs - raceStartMicros);
      if (rtUs >= 0) {
        reactionTime = (unsigned long)rtUs / 1000UL;
        reactionCaptured = true;
        float rtSec = rtUs / 1000000.0f;

        Serial.print("REACTION EDGE: ");
        Serial.print(rtSec, 3);
        Serial.println(" s");

        if (rtUs < 100000L) {
          lcd.clear();
          lcd.setCursor(0,0); lcd.print("FALSE START");
          lcd.setCursor(0,1); lcd.print("RT +"); lcd.print(rtSec,3);
          sendBleMessage("RT " + String(rtSec,3));
          sendWifiMessage("RT " + String(rtSec,3));
          sendBleMessage("FALSE_RT +" + String(rtSec,3));
          sendWifiMessage("FALSE_RT +" + String(rtSec,3));
          detailedFalseStartScreen = true;
          triggerFalseStart();
          return;
        }

        sendBleMessage("RT " + String(rtSec,3));
        sendWifiMessage("RT " + String(rtSec,3));
      }
    }
    else if ((currentState == COUNTDOWN_STATE || currentState == HOLD_STATE) &&
             scheduledGoMicros != 0) {
      long earlyUs = (long)(releaseUs - scheduledGoMicros);
      float earlySec = earlyUs / 1000000.0f;

      Serial.print("FALSE START EDGE: ");
      Serial.print(earlySec,3);
      Serial.println(" s");

      lcd.clear();
      lcd.setCursor(0,0); lcd.print("FALSE START");
      lcd.setCursor(0,1); lcd.print("RT "); lcd.print(earlySec,3);
      sendBleMessage("FALSE_RT " + String(earlySec,3));
      sendWifiMessage("FALSE_RT " + String(earlySec,3));
      detailedFalseStartScreen = true;
      triggerFalseStart();
      return;
    }
  }

  bool rawState =
    digitalRead(
      startPadPin
    );

  if (
    rawState !=
    lastRawFootState
  ) {

    footDebounceTime =
      millis();

    lastRawFootState =
      rawState;

  }

  if (
    millis() -
    footDebounceTime >=
    debounceTime &&

    rawState !=
    stableFootState
  ) {

    stableFootState =
      rawState;

    if (
      stableFootState ==
      LOW
    ) {

      handleFootPress();

    } else {

      handleFootRelease();
    }
  }
}

// ============================================================
// 발판 누름
// ============================================================
void handleFootPress() {

  footPressed = true;

  Serial.println(
    "FOOT PRESS"
  );

  if (
    currentState ==
    READY_STATE
  ) {

    currentState =
      HOLD_STATE;

    stateStartTime =
      millis();
    scheduledGoMicros = micros() + 4000000UL;

    showHoldScreen();

    sendBleMessage(
      "STATE:HOLD"
    );
    sendWifiMessage("STATE:HOLD");
  }
}

// ============================================================
// 발판 뗌
// ============================================================
void handleFootRelease() {
  footPressed = false;
  Serial.println("FOOT RELEASE STABLE");
  // 반응속도/부정출발 판정은 ISR edge timestamp에서 이미 처리한다.
}

// ============================================================
// 경기 상태
// ============================================================
void updateRaceState() {

  unsigned long now =
    millis();

  if (
    currentState ==
    HOLD_STATE &&

    now -
    stateStartTime >=
    1000
  ) {

    beginCountdown();
  }

  if (
    currentState ==
    COUNTDOWN_STATE
  ) {

    runCountdown(now);
  }

  if (
    currentState ==
    FALSE_START_STATE &&

    now -
    stateStartTime >=
    2000
  ) {

    resetTimer();
  }
}

// ============================================================
// 카운트다운 시작
// ============================================================
void beginCountdown() {

  currentState =
    COUNTDOWN_STATE;

  countdownStep = 0;

  stateStartTime =
    millis();
  scheduledGoMicros = micros() + 3000000UL;

  lcd.clear();

  lcd.setCursor(
    0,
    0
  );

  lcd.print(
    "GET READY"
  );

  lcd.setCursor(
    0,
    1
  );

  lcd.print(
    "HOLD FOOT"
  );

  Serial.println(
    "COUNTDOWN"
  );

  sendBleMessage(
    "STATE:COUNTDOWN"
  );
  sendWifiMessage("STATE:COUNTDOWN");
}

// ============================================================
// 카운트다운
// ============================================================
void runCountdown(
  unsigned long now
) {

  unsigned long elapsed =
    now -
    stateStartTime;

  if (countdownStep == 0 && elapsed >= 1000) {
    lcd.clear();
    lcd.setCursor(7, 0);
    lcd.print("3");
    tone(buzzerPin, 1000, 180);
    countdownStep = 1;
    sendBleMessage("BEEP:1");
    sendWifiMessage("BEEP:1");
  }

  if (countdownStep == 1 && elapsed >= 2000) {
    lcd.clear();
    lcd.setCursor(7, 0);
    lcd.print("2");
    tone(buzzerPin, 1000, 180);
    countdownStep = 2;
    sendBleMessage("BEEP:2");
    sendWifiMessage("BEEP:2");
  }

  if (countdownStep == 2 && elapsed >= 3000) {
    lcd.clear();
    lcd.setCursor(7, 0);
    lcd.print("1");

    // GO 기준시각을 먼저 확정하고 바로 부저를 시작한다.
    // 네트워크/LCD 작업은 그 뒤에 실행한다.
    raceStartMicros = micros();
    raceStartTime = millis();
    footReleaseEdgePending = false;
    tone(buzzerPin, 2000, 700);
    startRaceTimer();

    // 계측 기준을 잡은 뒤 앱에 알림
    sendBleMessage("BEEP:START");
    sendWifiMessage("BEEP:START");
  }
}

// ============================================================
// 타이머 START
// ============================================================
void startRaceTimer() {

  // raceStartMicros/raceStartTime은 GO tone 직전에 이미 캡처됨
  Serial.print("GO US: ");
  Serial.println(raceStartMicros);

  lastLcdUpdate = 0;

  lastBleTimeSend = 0;

  reactionTime = 0;

  reactionCaptured = false;

  currentState =
    RUNNING_STATE;

  lcd.clear();

  lcd.setCursor(
    0,
    0
  );

  lcd.print(
    "RT ---.---"
  );

  lcd.setCursor(
    0,
    1
  );

  lcd.print(
    "00.000"
  );

  Serial.println(
    "TIMER STARTED"
  );

  sendBleMessage(
    "STATE:RUNNING"
  );
  sendWifiMessage("STATE:RUNNING");

  sendBleMessage(
    "TIME 0.000"
  );
  sendWifiMessage("TIME 0.000");
}

// ============================================================
// FALSE START
// ============================================================
void triggerFalseStart() {

  currentState =
    FALSE_START_STATE;

  stateStartTime =
    millis();

  noTone(
    buzzerPin
  );

  tone(
    buzzerPin,
    500,
    2000
  );

  if (!detailedFalseStartScreen) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("FALSE START");
    lcd.setCursor(0, 1);
    lcd.print("TRY AGAIN");
  }

  Serial.println(
    "FALSE START"
  );

  sendBleMessage(
    "STATE:FALSE_START"
  );
  sendWifiMessage("STATE:FALSE_START");
}

// ============================================================
// 중앙 Finish 백업버튼
// ============================================================
void checkFinishButton() {

  bool currentStateRead =
    digitalRead(
      finishButtonPin
    );

  if (
    currentStateRead !=
    lastFinishState &&

    millis() -
    finishDebounceTime >=
    debounceTime
  ) {

    finishDebounceTime =
      millis();

    lastFinishState =
      currentStateRead;

    if (
      currentStateRead ==
      LOW &&

      currentState ==
      RUNNING_STATE
    ) {

      stopRaceTimer();
    }
  }
}

// ============================================================
// 경기 종료
// ============================================================
void stopRaceTimer() {

  finishTime =
    millis() -
    raceStartTime;

  currentState =
    FINISHED_STATE;

  noTone(
    buzzerPin
  );

  lcd.clear();

  lcd.setCursor(
    0,
    0
  );

  if (
    reactionCaptured
  ) {

    lcd.print(
      "RT "
    );

    printTimeValue(
      reactionTime
    );

  } else {

    lcd.print(
      "RT ---.---"
    );
  }

  lcd.setCursor(
    0,
    1
  );

  lcd.print(
    "TIME "
  );

  printTimeValue(
    finishTime
  );

  Serial.print(
    "FINISH TIME: "
  );

  Serial.print(
    finishTime
  );

  Serial.println(
    " ms"
  );

  // ----------------------------------------------------------
  // ★ TOP10 등록
  // ----------------------------------------------------------
  addTop10Record(
    finishTime
  );

  // ----------------------------------------------------------
  // 기존 BLE 기록 전송
  // ----------------------------------------------------------
  sendBleMessage(
    "TIME " +
    String(
      finishTime /
      1000.0,
      3
    )
  );

  sendWifiMessage(
    "TIME " +
    String(
      finishTime / 1000.0,
      3
    )
  );

  if (
    reactionCaptured
  ) {

    sendBleMessage(
      "RT " +
      String(
        reactionTime /
        1000.0,
        3
      )
    );
  }

  sendBleMessage(
    "STATE:FINISHED"
  );
  sendWifiMessage("STATE:FINISHED");

  delay(50);

  // ----------------------------------------------------------
  // ★ TOP10 전체 BLE 전송
  // ----------------------------------------------------------
  sendTop10ToBle();
  sendTop10ToWifi();
}

// ============================================================
// RESET 버튼
// ============================================================
void checkResetButton() {

  bool currentStateRead =
    digitalRead(
      resetButtonPin
    );

  if (
    currentStateRead !=
    lastResetState &&

    millis() -
    resetDebounceTime >=
    debounceTime
  ) {

    resetDebounceTime =
      millis();

    lastResetState =
      currentStateRead;

    if (
      currentStateRead ==
      LOW
    ) {

      resetTimer();
    }
  }
}

// ============================================================
// RESET
// ============================================================
void resetTimer() {

  currentState =
    READY_STATE;

  footPressed = false;

  reactionCaptured = false;
  detailedFalseStartScreen = false;
  scheduledGoMicros = 0;
  noInterrupts();
  footReleaseEdgePending = false;
  footReleaseEdgeUs = 0;
  interrupts();

  reactionTime = 0;

  finishTime = 0;

  countdownStep = 0;

  noTone(
    buzzerPin
  );

  showReadyScreen();

  Serial.println(
    "RESET"
  );

  sendBleMessage(
    "STATE:READY"
  );
  sendWifiMessage("STATE:READY");

  sendBleMessage(
    "RESET"
  );
  sendWifiMessage("RESET");

  // V3.4 - RESET은 계측만 초기화하고 공동 연동 차례는 유지
  // groupOwnerId / groupOwnerName은 여기서 지우지 않는다.
  // 차례 해제는 RELEASE 명령에서만 처리한다.
  sendWifiMessage("RESET_KEEP_OWNER");

  if (groupOwnerId.length() > 0) {
    sendWifiMessage("OWNER|" + groupOwnerId + "|" + groupOwnerName);
    Serial.print("RESET - OWNER KEPT: ");
    Serial.println(groupOwnerName);
  } else {
    Serial.println("RESET - NO GROUP OWNER");
  }
}

// ============================================================
// LCD 실시간
// ============================================================
void updateTimerDisplay() {

  if (
    currentState !=
    RUNNING_STATE
  ) {

    return;
  }

  unsigned long now =
    millis();

  if (
    now -
    lastLcdUpdate <
    10
  ) {

    return;
  }

  lastLcdUpdate =
    now;

  unsigned long elapsedTime =
    now -
    raceStartTime;

  // 16x2: 1행=계측시간, 2행=반응속도
  lcd.setCursor(0, 0);
  lcd.print("TIME ");
  printTimeValue(elapsedTime);
  lcd.print("   ");

  lcd.setCursor(0, 1);
  if (reactionCaptured) {
    lcd.print("RT   ");
    printTimeValue(reactionTime);
    lcd.print("   ");
  } else {
    lcd.print("RT   --.---     ");
  }
}

// ============================================================
// 시간 출력
// ============================================================
void printTimeValue(
  unsigned long milliseconds
) {

  unsigned long seconds =
    milliseconds /
    1000;

  unsigned long millisPart =
    milliseconds %
    1000;

  char timeText[12];

  snprintf(
    timeText,
    sizeof(timeText),
    "%02lu.%03lu",
    seconds,
    millisPart
  );

  lcd.print(
    timeText
  );
}

// ============================================================
// READY 화면
// ============================================================
void showReadyScreen() {

  lcd.clear();

  lcd.setCursor(
    0,
    0
  );

  lcd.print(
    "SPEED TIMER"
  );

  lcd.setCursor(
    0,
    1
  );

  lcd.print(
    "READY"
  );
}

// ============================================================
// HOLD 화면
// ============================================================
void showHoldScreen() {

  lcd.clear();

  lcd.setCursor(
    0,
    0
  );

  lcd.print(
    "HOLD"
  );

  lcd.setCursor(
    0,
    1
  );

  lcd.print(
    "WAIT..."
  );
}

// ============================================================
// 탑 HC-05
// ============================================================
void receiveTopBluetooth() {

  while (
    TopBT.available()
  ) {

    char receivedChar =
      TopBT.read();

    if (
      receivedChar ==
      '\n'
    ) {

      topMessage.trim();

      if (
        topMessage ==
        "FINISH"
      ) {

        Serial.println(
          "TOP FINISH RECEIVED"
        );

        if (
          currentState ==
          RUNNING_STATE
        ) {

          stopRaceTimer();
        }
      }

      topMessage = "";

    } else if (
      receivedChar !=
      '\r'
    ) {

      topMessage +=
        receivedChar;
    }
  }
}