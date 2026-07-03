#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <ESP32Servo.h>

// ── CONFIGURE THESE ──────────────────────────────
const char* WIFI_SSID     = "Southern_M";
const char* WIFI_PASSWORD = "southern";
const char* MQTT_BROKER   = "a3b3619ff24943d394bbdf797f2d71bd.s1.eu.hivemq.cloud"; // your HiveMQ URL
const int   MQTT_PORT     = 8883;
const char* MQTT_USER     = "Admit_Chaq";
const char* MQTT_PASS     = "123456789aA";
const char* CABINET_ID    = "cabinet_01"; // must match cabinet ID in your app
// ─────────────────────────────────────────────────

// Pin assignments
#define PIN_DOOR_SENSOR  34   // reed switch (input, pulled HIGH)
#define PIN_SERVO        13   // servo signal
#define PIN_LED          12   // LED guide light

// MQTT topics (must match iot_service.dart)
String TOPIC_STATUS;    // ESP32 publishes door/lock status
String TOPIC_COMMAND;   // App publishes commands → ESP32 listens

WiFiClient   espClient;
PubSubClient mqtt(espClient);
Servo        lockServo;

bool doorWasOpen = false;

void connectWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500); Serial.print(".");
  }
  Serial.println("\nWiFi connected: " + WiFi.localIP().toString());
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  Serial.println("MQTT received: " + msg);

  // Parse JSON command
  StaticJsonDocument<256> doc;
  if (deserializeJson(doc, msg) != DeserializationError::Ok) return;

  String action = doc["action"] | "";

  if (action == "unlock") {
    lockServo.write(90);    // open position
    Serial.println("Servo: UNLOCKED");
  } else if (action == "lock") {
    lockServo.write(0);     // closed position
    Serial.println("Servo: LOCKED");
  } else if (action == "led_on") {
    digitalWrite(PIN_LED, HIGH);
    Serial.println("LED: ON");
  } else if (action == "led_off") {
    digitalWrite(PIN_LED, LOW);
    Serial.println("LED: OFF");
  }
}

void connectMQTT() {
  while (!mqtt.connected()) {
    Serial.print("Connecting MQTT...");
    String clientId = "esp32_" + String(CABINET_ID);
    if (mqtt.connect(clientId.c_str(), MQTT_USER, MQTT_PASS)) {
      Serial.println("connected");
      mqtt.subscribe(TOPIC_COMMAND.c_str());
      publishStatus(); // send initial status
    } else {
      Serial.print("failed rc="); Serial.println(mqtt.state());
      delay(3000);
    }
  }
}

void publishStatus() {
  bool doorOpen = digitalRead(PIN_DOOR_SENSOR) == LOW; // LOW = magnet away = door open
  StaticJsonDocument<128> doc;
  doc["cabinetId"] = CABINET_ID;
  doc["doorOpen"]  = doorOpen;
  doc["locked"]    = (lockServo.read() == 0);
  doc["ledOn"]     = (digitalRead(PIN_LED) == HIGH);

  char buf[128];
  serializeJson(doc, buf);
  mqtt.publish(TOPIC_STATUS.c_str(), buf, true); // retain=true
}

void setup() {
  Serial.begin(115200);

  TOPIC_STATUS  = "cabinet/" + String(CABINET_ID) + "/status";
  TOPIC_COMMAND = "cabinet/" + String(CABINET_ID) + "/command";

  pinMode(PIN_DOOR_SENSOR, INPUT_PULLUP);
  pinMode(PIN_LED,         OUTPUT);
  digitalWrite(PIN_LED,    LOW);

  lockServo.attach(PIN_SERVO);
  lockServo.write(0); // start locked

  connectWiFi();
  mqtt.setServer(MQTT_BROKER, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
}

void loop() {
  if (!mqtt.connected()) connectMQTT();
  mqtt.loop();

  // Detect door open/close changes and publish
  bool doorNowOpen = digitalRead(PIN_DOOR_SENSOR) == LOW;
  if (doorNowOpen != doorWasOpen) {
    doorWasOpen = doorNowOpen;
    publishStatus();
    Serial.println(doorNowOpen ? "Door OPENED" : "Door CLOSED");
  }

  delay(100);
}