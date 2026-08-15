// /*
//  * Smart Cabinet Finder — Dual Door Firmware v4.3 (Production Ready)
//  * ================================================================
//  * Servo Sequence:
//  * - UNLOCK: 0° → 90° → 180° → 0° (return to original)
//  * - LOCK:   0° → 90° → 180° → 0° (return to original)
//  * 
//  * LED Logic:
//  * - GPIO15 (Upper LED): ON if (Upper door is OPEN) OR (User turned ON via BLE)
//  * - GPIO2  (Lower LED): ON if (Lower door is OPEN) OR (User turned ON via BLE)
//  * 
//  * BLE Disconnection Handling:
//  * - Auto-restart advertising
//  * - Reset LED states
//  * - Ready for reconnection
//  * ================================================================
//  */

// #include <BLEDevice.h>
// #include <BLEServer.h>
// #include <BLEUtils.h>
// #include <BLE2902.h>
// #include <ESP32Servo.h>

// // ─────────────────────────────────────────
// // BLE CONFIGURATION
// // ─────────────────────────────────────────
// #define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"

// #define UPPER_DOOR_SENSOR   "beb5483e-36e1-4688-b7f5-ea07361b26a8"
// #define UPPER_SERVO         "beb5483e-36e1-4688-b7f5-ea07361b26a9"
// #define UPPER_LED           "beb5483e-36e1-4688-b7f5-ea07361b26aa"

// #define LOWER_DOOR_SENSOR   "beb5483e-36e1-4688-b7f5-ea07361b26ab"
// #define LOWER_SERVO         "beb5483e-36e1-4688-b7f5-ea07361b26ac"
// #define LOWER_LED           "beb5483e-36e1-4688-b7f5-ea07361b26ad"

// #define DEVICE_NAME         "SmartCabinet_01"

// // ─────────────────────────────────────────
// // PIN DEFINITIONS
// // ─────────────────────────────────────────
// #define PIN_SERVO_UPPER     18    // Upper servo control
// #define PIN_SERVO_LOWER     21    // Lower servo control
// #define PIN_DOOR_UPPER      4     // Upper door sensor (reed switch)
// #define PIN_DOOR_LOWER      5     // Lower door sensor (reed switch)

// // LEDs with user control + door status
// #define PIN_LED_UPPER       15    // Upper LED (User control OR door open)
// #define PIN_LED_LOWER       2     // Lower LED (User control OR door open)

// // ─────────────────────────────────────────
// // SERVO CONFIGURATION
// // ─────────────────────────────────────────
// #define SERVO_ORIGINAL      0     // Original/resting position
// #define SERVO_STAGE_1       90    // First stage (partial open)
// #define SERVO_UNLOCKED      180   // Fully unlocked position
// #define SERVO_HOLD_TIME     300   // Time to hold each position (ms)
// #define SERVO_PULSE_MIN     500   // Minimum pulse width (µs)
// #define SERVO_PULSE_MAX     2400  // Maximum pulse width (µs)

// // ─────────────────────────────────────────
// // DEBOUNCE CONFIGURATION
// // ─────────────────────────────────────────
// #define DEBOUNCE_DELAY      50    // Debounce delay in ms

// // ─────────────────────────────────────────
// // GLOBAL STATE
// // ─────────────────────────────────────────
// Servo servoServoUpper;
// Servo servoServoLower;

// bool phoneConnected = false;
// bool doorUpperOpen  = false;
// bool doorLowerOpen  = false;
// bool isLockedUpper  = true;
// bool isLockedLower  = true;

// // User controlled LED states
// bool userLedUpper   = false;   // User controlled upper LED
// bool userLedLower   = false;   // User controlled lower LED

// // BLE Objects
// BLEServer*         pServer      = nullptr;
// BLECharacteristic* pUpperSensor = nullptr;
// BLECharacteristic* pUpperServo  = nullptr;
// BLECharacteristic* pUpperLed    = nullptr;
// BLECharacteristic* pLowerSensor = nullptr;
// BLECharacteristic* pLowerServo  = nullptr;
// BLECharacteristic* pLowerLed    = nullptr;

// // ─────────────────────────────────────────
// // FORWARD DECLARATIONS
// // ─────────────────────────────────────────
// void updateLEDs();
// void sendDoorStatus();
// void unlockDoor(bool upper);
// void lockDoor(bool upper);
// void moveServoSmooth(bool upper, int fromAngle, int toAngle);
// void moveSequence(bool upper, int pos1, int pos2, int pos3);
// void updateDoorState(bool upper, bool isOpen);
// void onBLEDisconnect();

// // ─────────────────────────────────────────
// // BLE CHARACTERISTIC CALLBACKS
// // ─────────────────────────────────────────
// class UpperServoCallback : public BLECharacteristicCallbacks {
//   void onWrite(BLECharacteristic* pChar) override {
//     if (!phoneConnected) {
//       Serial.println(F("[BLE] ⚠️ Phone not connected - ignoring command"));
//       return;
//     }
    
//     String cmd = String(pChar->getValue().c_str());
//     cmd.trim();
//     int angle = cmd.toInt();

//     Serial.print(F("[BLE] Upper Servo command: "));
//     Serial.println(angle);

//     if (angle > 90) {
//       unlockDoor(true);
//     } else {
//       lockDoor(true);
//     }
//   }
// };

// class LowerServoCallback : public BLECharacteristicCallbacks {
//   void onWrite(BLECharacteristic* pChar) override {
//     if (!phoneConnected) {
//       Serial.println(F("[BLE] ⚠️ Phone not connected - ignoring command"));
//       return;
//     }
    
//     String cmd = String(pChar->getValue().c_str());
//     cmd.trim();
//     int angle = cmd.toInt();

//     Serial.print(F("[BLE] Lower Servo command: "));
//     Serial.println(angle);

//     if (angle > 90) {
//       unlockDoor(false);
//     } else {
//       lockDoor(false);
//     }
//   }
// };

// class UpperLedCallback : public BLECharacteristicCallbacks {
//   void onWrite(BLECharacteristic* pChar) override {
//     if (!phoneConnected) {
//       Serial.println(F("[BLE] ⚠️ Phone not connected - ignoring command"));
//       return;
//     }
    
//     String cmd = String(pChar->getValue().c_str());
//     cmd.trim();
//     userLedUpper = (cmd == "1");
//     Serial.print(F("[BLE] Upper LED user control: "));
//     Serial.println(userLedUpper ? "ON" : "OFF");
//     updateLEDs();
//   }
// };

// class LowerLedCallback : public BLECharacteristicCallbacks {
//   void onWrite(BLECharacteristic* pChar) override {
//     if (!phoneConnected) {
//       Serial.println(F("[BLE] ⚠️ Phone not connected - ignoring command"));
//       return;
//     }
    
//     String cmd = String(pChar->getValue().c_str());
//     cmd.trim();
//     userLedLower = (cmd == "1");
//     Serial.print(F("[BLE] Lower LED user control: "));
//     Serial.println(userLedLower ? "ON" : "OFF");
//     updateLEDs();
//   }
// };

// // ─────────────────────────────────────────
// // BLE SERVER CALLBACKS
// // ─────────────────────────────────────────
// class ServerCallbacks : public BLEServerCallbacks {
//   void onConnect(BLEServer* pServer) override {
//     phoneConnected = true;
//     Serial.println(F("\n╔═══════════════════════════════════════════╗"));
//     Serial.println(F("║   📱 PHONE CONNECTED!                   ║"));
//     Serial.println(F("╚═══════════════════════════════════════════╝"));
//     Serial.println(F("[BLE] Device connected successfully!"));
//     updateLEDs();
//     sendDoorStatus();
//   }

//   void onDisconnect(BLEServer* pServer) override {
//     onBLEDisconnect();
//   }
// };

// // ─────────────────────────────────────────
// // BLE DISCONNECTION HANDLER
// // ─────────────────────────────────────────
// void onBLEDisconnect() {
//   phoneConnected = false;
  
//   Serial.println(F("\n╔═══════════════════════════════════════════╗"));
//   Serial.println(F("║   📱 PHONE DISCONNECTED!                ║"));
//   Serial.println(F("╚═══════════════════════════════════════════╝"));
  
//   // Reset user-controlled LED states on disconnect
//   userLedUpper = false;
//   userLedLower = false;
//   Serial.println(F("[BLE] Reset user LED states"));
  
//   // Update LEDs to show disconnected state
//   updateLEDs();
  
//   // Send status update (if someone is listening)
//   sendDoorStatus();
  
//   // Restart advertising after delay
//   Serial.println(F("[BLE] Restarting advertising in 500ms..."));
//   delay(500);
  
//   if (pServer != nullptr) {
//     pServer->startAdvertising();
//     Serial.println(F("[BLE] ✅ Advertising restarted!"));
//     Serial.println(F("[BLE] Waiting for phone to connect..."));
//   } else {
//     Serial.println(F("[BLE] ❌ Error: Server object is null!"));
//   }
  
//   Serial.println(F("\n╔═══════════════════════════════════════════╗"));
//   Serial.println(F("║   🔄 READY FOR RECONNECTION             ║"));
//   Serial.println(F("╚═══════════════════════════════════════════╝\n"));
// }

// // ─────────────────────────────────────────
// // SERVO HELPER - Smooth movement between angles
// // ─────────────────────────────────────────
// void moveServoSmooth(bool upper, int fromAngle, int toAngle) {
//   if (upper) {
//     // Re-attach if detached
//     if (!servoServoUpper.attached()) {
//       servoServoUpper.attach(PIN_SERVO_UPPER, SERVO_PULSE_MIN, SERVO_PULSE_MAX);
//       delay(50);
//     }
    
//     // Move gradually
//     if (fromAngle < toAngle) {
//       for (int angle = fromAngle; angle <= toAngle; angle += 5) {
//         servoServoUpper.write(angle);
//         delay(15);
//       }
//     } else {
//       for (int angle = fromAngle; angle >= toAngle; angle -= 5) {
//         servoServoUpper.write(angle);
//         delay(15);
//       }
//     }
//     servoServoUpper.write(toAngle);
//     delay(SERVO_HOLD_TIME);
    
//   } else {
//     // Re-attach if detached
//     if (!servoServoLower.attached()) {
//       servoServoLower.attach(PIN_SERVO_LOWER, SERVO_PULSE_MIN, SERVO_PULSE_MAX);
//       delay(50);
//     }
    
//     // Move gradually
//     if (fromAngle < toAngle) {
//       for (int angle = fromAngle; angle <= toAngle; angle += 5) {
//         servoServoLower.write(angle);
//         delay(15);
//       }
//     } else {
//       for (int angle = fromAngle; angle >= toAngle; angle -= 5) {
//         servoServoLower.write(angle);
//         delay(15);
//       }
//     }
//     servoServoLower.write(toAngle);
//     delay(SERVO_HOLD_TIME);
//   }
// }

// // ─────────────────────────────────────────
// // SERVO SEQUENCE - Move through 3 positions
// // ─────────────────────────────────────────
// void moveSequence(bool upper, int pos1, int pos2, int pos3) {
//   Serial.print(F("[SERVO] Sequence: "));
//   Serial.print(pos1);
//   Serial.print(F("° → "));
//   Serial.print(pos2);
//   Serial.print(F("° → "));
//   Serial.print(pos3);
//   Serial.println(F("°"));
  
//   moveServoSmooth(upper, pos1, pos2);
//   delay(100);
//   moveServoSmooth(upper, pos2, pos3);
//   delay(100);
  
//   // Detach after sequence
//   if (upper) {
//     servoServoUpper.detach();
//     Serial.println(F("[SERVO] Upper detached (no torque)."));
//   } else {
//     servoServoLower.detach();
//     Serial.println(F("[SERVO] Lower detached (no torque)."));
//   }
// }

// // ─────────────────────────────────────────
// // DOOR CONTROL FUNCTIONS
// // ─────────────────────────────────────────
// void unlockDoor(bool upper) {
//   if (!phoneConnected) {
//     Serial.println(F("[SERVO] ⚠️ Phone not connected - cannot unlock"));
//     return;
//   }
  
//   if (upper) {
//     Serial.println(F("[SERVO] Unlocking UPPER door..."));
//     // 0° → 90° → 180° → 0° (return to original)
//     moveSequence(true, SERVO_ORIGINAL, SERVO_STAGE_1, SERVO_UNLOCKED);
//     delay(200);
//     moveServoSmooth(true, SERVO_UNLOCKED, SERVO_ORIGINAL);
//     servoServoUpper.detach();
//     isLockedUpper = false;
//   } else {
//     Serial.println(F("[SERVO] Unlocking LOWER door..."));
//     // 0° → 90° → 180° → 0° (return to original)
//     moveSequence(false, SERVO_ORIGINAL, SERVO_STAGE_1, SERVO_UNLOCKED);
//     delay(200);
//     moveServoSmooth(false, SERVO_UNLOCKED, SERVO_ORIGINAL);
//     servoServoLower.detach();
//     isLockedLower = false;
//   }

//   updateLEDs();
//   sendDoorStatus();
//   Serial.println(F("[SERVO] ✅ Door unlocked (returned to original position)."));
// }

// void lockDoor(bool upper) {
//   if (!phoneConnected) {
//     Serial.println(F("[SERVO] ⚠️ Phone not connected - cannot lock"));
//     return;
//   }
  
//   if (upper) {
//     Serial.println(F("[SERVO] Locking UPPER door..."));
//     // 0° → 90° → 180° → 0° (return to original)
//     moveSequence(true, SERVO_ORIGINAL, SERVO_STAGE_1, SERVO_UNLOCKED);
//     delay(200);
//     moveServoSmooth(true, SERVO_UNLOCKED, SERVO_ORIGINAL);
//     servoServoUpper.detach();
//     isLockedUpper = true;
//   } else {
//     Serial.println(F("[SERVO] Locking LOWER door..."));
//     // 0° → 90° → 180° → 0° (return to original)
//     moveSequence(false, SERVO_ORIGINAL, SERVO_STAGE_1, SERVO_UNLOCKED);
//     delay(200);
//     moveServoSmooth(false, SERVO_UNLOCKED, SERVO_ORIGINAL);
//     servoServoLower.detach();
//     isLockedLower = true;
//   }

//   updateLEDs();
//   sendDoorStatus();
//   Serial.println(F("[SERVO] ✅ Door locked (returned to original position)."));
// }

// // ─────────────────────────────────────────
// // DOOR SENSOR UPDATE
// // ─────────────────────────────────────────
// void updateDoorState(bool upper, bool isOpen) {
//   if (upper) {
//     doorUpperOpen = isOpen;
//     Serial.print(F("[DOOR] UPPER: "));
//     Serial.println(isOpen ? "OPENED" : "CLOSED");
//   } else {
//     doorLowerOpen = isOpen;
//     Serial.print(F("[DOOR] LOWER: "));
//     Serial.println(isOpen ? "OPENED" : "CLOSED");
//   }
//   updateLEDs();
//   sendDoorStatus();
// }

// // ─────────────────────────────────────────
// // LED HELPER - User Control OR Door Status
// // ─────────────────────────────────────────
// void updateLEDs() {
//   // Upper LED: ON if (User turned ON) OR (Upper door is OPEN)
//   bool upperLedState = userLedUpper || doorUpperOpen;
  
//   // Lower LED: ON if (User turned ON) OR (Lower door is OPEN)
//   bool lowerLedState = userLedLower || doorLowerOpen;
  
//   // Apply to hardware
//   digitalWrite(PIN_LED_UPPER, upperLedState ? HIGH : LOW);
//   digitalWrite(PIN_LED_LOWER, lowerLedState ? HIGH : LOW);
  
//   // Debug output
//   Serial.print(F("[LED] Upper: "));
//   Serial.print(upperLedState ? "ON" : "OFF");
//   Serial.print(F(" (User:"));
//   Serial.print(userLedUpper ? "ON" : "OFF");
//   Serial.print(F(" Door:"));
//   Serial.print(doorUpperOpen ? "OPEN" : "CLOSED");
//   Serial.print(F(") | Lower: "));
//   Serial.print(lowerLedState ? "ON" : "OFF");
//   Serial.print(F(" (User:"));
//   Serial.print(userLedLower ? "ON" : "OFF");
//   Serial.print(F(" Door:"));
//   Serial.print(doorLowerOpen ? "OPEN" : "CLOSED");
//   Serial.println(F(")"));
// }

// // ─────────────────────────────────────────
// // SEND DOOR STATUS TO PHONE
// // ─────────────────────────────────────────
// void sendDoorStatus() {
//   if (!phoneConnected) {
//     // Still log status locally even if not connected
//     Serial.println(F("[STATUS] Phone disconnected - status not sent"));
//     return;
//   }

//   String upperStatus = doorUpperOpen ? "OPEN" : "CLOSED";
//   pUpperSensor->setValue(upperStatus.c_str());
//   pUpperSensor->notify();

//   String lowerStatus = doorLowerOpen ? "OPEN" : "CLOSED";
//   pLowerSensor->setValue(lowerStatus.c_str());
//   pLowerSensor->notify();

//   Serial.print(F("[STATUS] Sent - Upper: "));
//   Serial.print(upperStatus);
//   Serial.print(F(" | Lower: "));
//   Serial.println(lowerStatus);
// }

// // ─────────────────────────────────────────
// // BLE SETUP
// // ─────────────────────────────────────────
// void setupBLE() {
//   Serial.println(F("[BLE] Initializing..."));

//   BLEDevice::init(DEVICE_NAME);
//   BLEDevice::setMTU(256);

//   pServer = BLEDevice::createServer();
//   pServer->setCallbacks(new ServerCallbacks());

//   BLEService* pService = pServer->createService(SERVICE_UUID);

//   // Upper Door Sensor (Notify + Read)
//   pUpperSensor = pService->createCharacteristic(
//     UPPER_DOOR_SENSOR,
//     BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ
//   );
//   pUpperSensor->addDescriptor(new BLE2902());
//   pUpperSensor->setValue("CLOSED");

//   // Upper Servo (Write)
//   pUpperServo = pService->createCharacteristic(
//     UPPER_SERVO,
//     BLECharacteristic::PROPERTY_WRITE
//   );
//   pUpperServo->setCallbacks(new UpperServoCallback());

//   // Upper LED (Write) - User controlled
//   pUpperLed = pService->createCharacteristic(
//     UPPER_LED,
//     BLECharacteristic::PROPERTY_WRITE
//   );
//   pUpperLed->setCallbacks(new UpperLedCallback());

//   // Lower Door Sensor (Notify + Read)
//   pLowerSensor = pService->createCharacteristic(
//     LOWER_DOOR_SENSOR,
//     BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ
//   );
//   pLowerSensor->addDescriptor(new BLE2902());
//   pLowerSensor->setValue("CLOSED");

//   // Lower Servo (Write)
//   pLowerServo = pService->createCharacteristic(
//     LOWER_SERVO,
//     BLECharacteristic::PROPERTY_WRITE
//   );
//   pLowerServo->setCallbacks(new LowerServoCallback());

//   // Lower LED (Write) - User controlled
//   pLowerLed = pService->createCharacteristic(
//     LOWER_LED,
//     BLECharacteristic::PROPERTY_WRITE
//   );
//   pLowerLed->setCallbacks(new LowerLedCallback());

//   pService->start();

//   // Start advertising
//   BLEAdvertising* pAdvert = BLEDevice::getAdvertising();
//   pAdvert->addServiceUUID(SERVICE_UUID);
//   pAdvert->setScanResponse(true);
//   pAdvert->setMinPreferred(0x06);
//   pAdvert->setMaxPreferred(0x12);
//   BLEDevice::startAdvertising();

//   Serial.println(F("[BLE] ✅ Advertising started!"));
//   Serial.print(F("[BLE] Device Name: "));
//   Serial.println(DEVICE_NAME);
//   Serial.print(F("[BLE] Service UUID: "));
//   Serial.println(SERVICE_UUID);
// }

// // ─────────────────────────────────────────
// // SETUP
// // ─────────────────────────────────────────
// void setup() {
//   Serial.begin(115200);
//   delay(1000);
  
//   Serial.println(F("\n╔═══════════════════════════════════════════╗"));
//   Serial.println(F("║   Smart Cabinet Finder v4.3             ║"));
//   Serial.println(F("║   Dual Door BLE-Only Firmware           ║"));
//   Serial.println(F("╚═══════════════════════════════════════════╝\n"));
  
//   Serial.println(F("[INFO] Pin Configuration:"));
//   Serial.println(F("  ┌─────────────────────────────────────────────┐"));
//   Serial.println(F("  │ Upper Servo        : GPIO18                │"));
//   Serial.println(F("  │ Lower Servo        : GPIO21                │"));
//   Serial.println(F("  │ Upper Door Sensor  : GPIO4                 │"));
//   Serial.println(F("  │ Lower Door Sensor  : GPIO5                 │"));
//   Serial.println(F("  │ Upper LED          : GPIO15 (User OR Door) │"));
//   Serial.println(F("  │ Lower LED          : GPIO2  (User OR Door) │"));
//   Serial.println(F("  └─────────────────────────────────────────────┘\n"));
  
//   Serial.println(F("[INFO] Servo Sequence:"));
//   Serial.println(F("  ┌─────────────────────────────────────────┐"));
//   Serial.println(F("  │ ORIGINAL  → 0°  (resting position)    │"));
//   Serial.println(F("  │ STAGE 1   → 90° (partial open)        │"));
//   Serial.println(F("  │ UNLOCKED  → 180° (fully open)         │"));
//   Serial.println(F("  │ FINAL     → 0°  (return to original)  │"));
//   Serial.println(F("  └─────────────────────────────────────────┘\n"));
  
//   Serial.println(F("[INFO] LED Logic:"));
//   Serial.println(F("  ┌─────────────────────────────────────────────┐"));
//   Serial.println(F("  │ LED ON if:                                 │"));
//   Serial.println(F("  │  1. User turned it ON via BLE              │"));
//   Serial.println(F("  │  OR                                        │"));
//   Serial.println(F("  │  2. Door is OPEN                          │"));
//   Serial.println(F("  │                                            │"));
//   Serial.println(F("  │ LED OFF ONLY when:                         │"));
//   Serial.println(F("  │  1. User turned it OFF via BLE             │"));
//   Serial.println(F("  │  AND                                       │"));
//   Serial.println(F("  │  2. Door is CLOSED                        │"));
//   Serial.println(F("  └─────────────────────────────────────────────┘\n"));

//   // Initialize pins
//   pinMode(PIN_DOOR_UPPER, INPUT_PULLUP);
//   pinMode(PIN_DOOR_LOWER, INPUT_PULLUP);
//   pinMode(PIN_LED_UPPER, OUTPUT);
//   pinMode(PIN_LED_LOWER, OUTPUT);

//   // LED startup sequence - test both LEDs
//   Serial.println(F("[LED] Testing LEDs..."));
//   digitalWrite(PIN_LED_UPPER, HIGH);
//   digitalWrite(PIN_LED_LOWER, HIGH);
//   delay(500);
//   digitalWrite(PIN_LED_UPPER, LOW);
//   digitalWrite(PIN_LED_LOWER, LOW);
//   delay(200);
//   digitalWrite(PIN_LED_UPPER, HIGH);
//   delay(300);
//   digitalWrite(PIN_LED_UPPER, LOW);
//   digitalWrite(PIN_LED_LOWER, HIGH);
//   delay(300);
//   digitalWrite(PIN_LED_LOWER, LOW);
//   Serial.println(F("[LED] ✅ All LEDs tested OK!"));

//   // Initialize servos at original position (0°)
//   Serial.println(F("[SERVO] Initializing servos at ORIGINAL position (0°)..."));
//   servoServoUpper.attach(PIN_SERVO_UPPER, SERVO_PULSE_MIN, SERVO_PULSE_MAX);
//   servoServoUpper.write(SERVO_ORIGINAL);
//   delay(300);
//   servoServoUpper.detach();
  
//   servoServoLower.attach(PIN_SERVO_LOWER, SERVO_PULSE_MIN, SERVO_PULSE_MAX);
//   servoServoLower.write(SERVO_ORIGINAL);
//   delay(300);
//   servoServoLower.detach();
  
//   Serial.println(F("[SERVO] ✅ Servos initialized at ORIGINAL (0°) (detached)."));

//   // Read initial door states
//   doorUpperOpen = (digitalRead(PIN_DOOR_UPPER) == HIGH);
//   doorLowerOpen = (digitalRead(PIN_DOOR_LOWER) == HIGH);
  
//   Serial.print(F("[DOOR] Initial state - Upper: "));
//   Serial.print(doorUpperOpen ? "OPEN" : "CLOSED");
//   Serial.print(F(", Lower: "));
//   Serial.println(doorLowerOpen ? "OPEN" : "CLOSED");

//   // Setup BLE
//   setupBLE();
  
//   // Update LEDs based on initial state
//   updateLEDs();

//   Serial.println(F("\n╔═══════════════════════════════════════════╗"));
//   Serial.println(F("║   🚀 SYSTEM READY!                     ║"));
//   Serial.println(F("║   Waiting for BLE connection...        ║"));
//   Serial.println(F("╚═══════════════════════════════════════════╝\n"));
// }

// // ─────────────────────────────────────────
// // LOOP
// // ─────────────────────────────────────────
// bool lastDoorUpperState = HIGH;
// bool lastDoorLowerState = HIGH;

// void loop() {
//   // ─── Read Upper Door Sensor with Debounce ───
//   bool currentDoorUpper = digitalRead(PIN_DOOR_UPPER);
//   if (currentDoorUpper != lastDoorUpperState) {
//     delay(DEBOUNCE_DELAY);
//     currentDoorUpper = digitalRead(PIN_DOOR_UPPER);
//     if (currentDoorUpper != lastDoorUpperState) {
//       lastDoorUpperState = currentDoorUpper;
//       updateDoorState(true, (currentDoorUpper == HIGH));
//     }
//   }

//   // ─── Read Lower Door Sensor with Debounce ───
//   bool currentDoorLower = digitalRead(PIN_DOOR_LOWER);
//   if (currentDoorLower != lastDoorLowerState) {
//     delay(DEBOUNCE_DELAY);
//     currentDoorLower = digitalRead(PIN_DOOR_LOWER);
//     if (currentDoorLower != lastDoorLowerState) {
//       lastDoorLowerState = currentDoorLower;
//       updateDoorState(false, (currentDoorLower == HIGH));
//     }
//   }

//   delay(50);  // Small delay to prevent excessive CPU usage
// }