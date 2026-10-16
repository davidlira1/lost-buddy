#include "lora_radio.h"

#include <Arduino.h>
#include <cstdio>
#include <cstring>

#include "lora_config.h"

LoraRadio::LoraRadio(HardwareSerial& serial) : serial_(serial) {
  rx_line_[0] = '\0';
  tx_cmd_[0] = '\0';
}

void LoraRadio::pulseReset() {
  pinMode(LoraConfig::kRstPin, OUTPUT);
  digitalWrite(LoraConfig::kRstPin, HIGH);
  delay(10);
  digitalWrite(LoraConfig::kRstPin, LOW);
  delay(LoraConfig::kResetPulseMs);
  digitalWrite(LoraConfig::kRstPin, HIGH);
  delay(LoraConfig::kResetSettleMs);
}

void LoraRadio::writeCommand(const char* cmd) {
  serial_.print(cmd);
  serial_.print("\r\n");
}

bool LoraRadio::awaitOk(uint32_t timeout_ms) {
  waiting_ok_ = true;
  wait_started_ms_ = millis();

  while (waiting_ok_) {
    pollRx();
    if (!waiting_ok_) {
      return true;
    }
    if ((millis() - wait_started_ms_) >= timeout_ms) {
      Serial.println("lora: AT timeout");
      waiting_ok_ = false;
      return false;
    }
  }
  return true;
}

void LoraRadio::begin() {
  pulseReset();
  serial_.begin(LoraConfig::kBaud, SERIAL_8N1, LoraConfig::kRxPin,
                LoraConfig::kTxPin);
  delay(50);

  Serial.println("lora: configuring RYLR998");

  writeCommand("AT");
  awaitOk(LoraConfig::kReplyTimeoutMs);

  snprintf(tx_cmd_, sizeof(tx_cmd_), "AT+ADDRESS=%u",
           static_cast<unsigned>(LoraConfig::kAddress));
  writeCommand(tx_cmd_);
  awaitOk(LoraConfig::kReplyTimeoutMs);

  snprintf(tx_cmd_, sizeof(tx_cmd_), "AT+NETWORKID=%u",
           static_cast<unsigned>(LoraConfig::kNetworkId));
  writeCommand(tx_cmd_);
  awaitOk(LoraConfig::kReplyTimeoutMs);

  snprintf(tx_cmd_, sizeof(tx_cmd_), "AT+BAND=%lu",
           static_cast<unsigned long>(LoraConfig::kBandHz));
  writeCommand(tx_cmd_);
  awaitOk(LoraConfig::kReplyTimeoutMs);

  Serial.println("lora: setup done");
}

void LoraRadio::pollRx() {
  while (serial_.available() > 0) {
    processRxByte(static_cast<char>(serial_.read()));
  }
}

void LoraRadio::update() {
  pollRx();

  if (waiting_ok_ &&
      (millis() - wait_started_ms_) >= LoraConfig::kReplyTimeoutMs) {
    Serial.println("lora: send timeout");
    waiting_ok_ = false;
  }
}

void LoraRadio::processRxByte(char c) {
  if (c == '\r') {
    return;
  }
  if (c == '\n') {
    if (rx_len_ == 0) {
      return;
    }
    rx_line_[rx_len_] = '\0';
    handleLine(rx_line_);
    rx_len_ = 0;
    return;
  }
  if (rx_len_ + 1 >= kRxLineLen) {
    rx_len_ = 0;
    return;
  }
  rx_line_[rx_len_++] = c;
}

void LoraRadio::handleLine(const char* line) {
  Serial.print("lora: ");
  Serial.println(line);

  if (strcmp(line, "+OK") == 0) {
    waiting_ok_ = false;
    return;
  }
  if (strncmp(line, "+ERR", 4) == 0) {
    waiting_ok_ = false;
    return;
  }
}

bool LoraRadio::send(const char* payload, size_t len) {
  if (payload == nullptr || len == 0 || len > LoraConfig::kMaxPayload) {
    return false;
  }
  if (waiting_ok_) {
    return false;
  }

  const int n =
      snprintf(tx_cmd_, sizeof(tx_cmd_), "AT+SEND=%u,%u,%s\r\n",
               static_cast<unsigned>(LoraConfig::kDestAddress),
               static_cast<unsigned>(len), payload);
  if (n < 0 || static_cast<size_t>(n) >= sizeof(tx_cmd_)) {
    return false;
  }

  serial_.print(tx_cmd_);
  waiting_ok_ = true;
  wait_started_ms_ = millis();
  return true;
}
