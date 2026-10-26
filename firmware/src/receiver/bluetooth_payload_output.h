#pragma once

#include <stdint.h>

#include "payload_output.h"

class BLECharacteristic;
class BLEServer;

// Notifies the raw tracker payload. A future phone client copies these UUIDs.
class BluetoothPayloadOutput : public PayloadOutput {
 public:
  static constexpr const char* kDeviceName = "LostBuddy";
  static constexpr const char* kServiceUUID = "6f4c0001-8b3a-4c1e-9d77-2a1b0c4e5f10";
  static constexpr const char* kPayloadUUID = "6f4c0002-8b3a-4c1e-9d77-2a1b0c4e5f10";
  static constexpr uint16_t kLocalMtu = 185;

  void begin() override;
  void publish(const char* payload, size_t length) override;

 private:
  BLEServer* server_ = nullptr;
  BLECharacteristic* payload_ = nullptr;
};
