#include <Arduino.h>

#include "gps_service.h"
#include "packet_codec.h"
#include "telemetry.h"

namespace {
HardwareSerial gps_serial(2);
GpsService gps(gps_serial);

Telemetry telemetry;
uint32_t seq = 0;
uint32_t last_publish_ms = 0;
constexpr uint32_t kPublishIntervalMs = 1000;
}  // namespace

void setup() {
  Serial.begin(115200);
  gps.begin();
  Serial.println("GPS parse + packet ready");
}

void loop() {
  gps.update();

  const uint32_t now = millis();
  if ((now - last_publish_ms) < kPublishIntervalMs) {
    return;
  }

  if (!gps.fillTelemetry(telemetry)) {
    return;
  }

  last_publish_ms = now;
  gps.clearLocationUpdated();
  telemetry.seq = ++seq;

  char line[PacketCodec::kMaxEncodedLen];
  if (PacketCodec::encode(telemetry, line, sizeof(line)) == 0) {
    return;
  }

  Serial.println(line);
}
