#include <Arduino.h>

#include "bluetooth_payload_output.h"
#include "lora_config.h"
#include "rylr998_receiver.h"

namespace {
HardwareSerial radio_serial(1);
Rylr998Receiver module(radio_serial);
RadioReceiver& radio = module;

BluetoothPayloadOutput bluetooth;
PayloadOutput& output = bluetooth;
}  // namespace

void setup() {
  Serial.begin(115200);
  radio.begin();
  output.begin();
  Serial.println("receiver ready");
}

void loop() {
  radio.update();

  char payload[LoraConfig::kMaxPayload + 1];
  size_t length = 0;
  if (!radio.takePayload(payload, sizeof(payload), &length)) {
    return;
  }
  Serial.println(payload);
  output.publish(payload, length);
}
