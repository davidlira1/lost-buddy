#include "gps_service.h"

GpsService::GpsService(HardwareSerial& serial) : serial_(serial) {}

void GpsService::begin() {
  serial_.begin(kBaud, SERIAL_8N1, kRxPin, kTxPin);
}

void GpsService::update() {
  while (serial_.available() > 0) {
    const char c = static_cast<char>(serial_.read());
    if (gps_.encode(c)) {
      if (gps_.location.isUpdated()) {
        location_updated_ = true;
      }
    }
  }
}

bool GpsService::fillTelemetry(Telemetry& out) {
  out.id = kDeviceId;
  out.bat = kBatteryUnknown;

  const bool loc_ok =
      gps_.location.isValid() && gps_.location.age() <= kMaxFixAgeMs;
  out.fix_ok = loc_ok;

  if (gps_.time.isValid()) {
    // HHMMSS as integer (centiseconds dropped for a shorter field).
    out.time_hhmmss = static_cast<uint32_t>(gps_.time.hour()) * 10000U +
                      static_cast<uint32_t>(gps_.time.minute()) * 100U +
                      static_cast<uint32_t>(gps_.time.second());
  } else {
    out.time_hhmmss = 0;
  }

  if (loc_ok) {
    out.lat = gps_.location.lat();
    out.lon = gps_.location.lng();
  } else {
    out.lat = 0.0;
    out.lon = 0.0;
  }

  out.alt_m = gps_.altitude.isValid() ? static_cast<float>(gps_.altitude.meters())
                                      : 0.0f;
  out.speed_kmh =
      gps_.speed.isValid() ? static_cast<float>(gps_.speed.kmph()) : 0.0f;
  out.course_deg =
      gps_.course.isValid() ? static_cast<float>(gps_.course.deg()) : 0.0f;
  out.hdop = gps_.hdop.isValid() ? static_cast<float>(gps_.hdop.hdop()) : 0.0f;

  return out.fix_ok;
}
