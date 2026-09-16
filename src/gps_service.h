#pragma once

#include <HardwareSerial.h>
#include <TinyGPSPlus.h>

#include "telemetry.h"

class GpsService {
 public:
  static constexpr int kRxPin = 16;
  static constexpr int kTxPin = -1;
  static constexpr uint32_t kBaud = 38400;
  // Drop fixes older than this (ms).
  static constexpr uint32_t kMaxFixAgeMs = 2000;

  explicit GpsService(HardwareSerial& serial);

  void begin();
  // Drain UART into the parser. Call frequently from loop().
  void update();
  // Fill out from the latest parsed values. Returns true if fix_ok.
  bool fillTelemetry(Telemetry& out);
  bool locationUpdated() const { return location_updated_; }
  void clearLocationUpdated() { location_updated_ = false; }

 private:
  HardwareSerial& serial_;
  TinyGPSPlus gps_;
  bool location_updated_ = false;
};
