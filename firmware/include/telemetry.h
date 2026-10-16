#pragma once

#include <stdint.h>

// Sentinel: battery not measured yet (no ADC wired).
static constexpr uint8_t kBatteryUnknown = 255;

// Change per board when you flash multiple trackers.
static constexpr uint8_t kDeviceId = 1;

struct Telemetry {
  uint8_t id = kDeviceId;
  uint32_t seq = 0;
  // GPS time-of-day as HHMMSS (0 if unknown).
  uint32_t time_hhmmss = 0;
  bool fix_ok = false;
  double lat = 0.0;
  double lon = 0.0;
  float alt_m = 0.0f;
  float speed_kmh = 0.0f;
  float course_deg = 0.0f;
  float hdop = 0.0f;
  uint8_t bat = kBatteryUnknown;
};
