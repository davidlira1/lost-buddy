#include <Arduino.h>

#include "gps_service.h"
#include "lora_radio.h"
#include "packet_codec.h"
#include "telemetry.h"

namespace {
HardwareSerial gps_serial(2);
GpsService gps(gps_serial);

HardwareSerial lora_serial(1);
LoraRadio lora(lora_serial);

Telemetry telemetry;
uint32_t seq = 0;
uint32_t last_publish_ms = 0;
constexpr uint32_t kPublishIntervalMs = 1000;
}  // namespace

void setup() {
  Serial.begin(115200);
  gps.begin();
  lora.begin();
  Serial.println("GPS parse + packet ready");
}

void loop() {
  gps.update();
  lora.update();

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
  const size_t n = PacketCodec::encode(telemetry, line, sizeof(line));
  if (n == 0) {
    return;
  }

  Serial.println(line);
  if (!lora.send(line, n)) {
    Serial.println("lora: send skipped");
  }
}
