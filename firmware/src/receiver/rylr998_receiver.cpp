#include "rylr998_receiver.h"

#include <Arduino.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "lora_config.h"

Rylr998Receiver::Rylr998Receiver(HardwareSerial& serial) : serial_(serial) {
  rx_line_[0] = '\0';
  payload_[0] = '\0';
}

void Rylr998Receiver::pulseReset() {
  pinMode(LoraConfig::kRstPin, OUTPUT);
  digitalWrite(LoraConfig::kRstPin, HIGH);
  delay(10);
  digitalWrite(LoraConfig::kRstPin, LOW);
  delay(LoraConfig::kResetPulseMs);
  digitalWrite(LoraConfig::kRstPin, HIGH);
  delay(LoraConfig::kResetSettleMs);
}

void Rylr998Receiver::writeCommand(const char* cmd) {
  serial_.print(cmd);
  serial_.print("\r\n");
}

bool Rylr998Receiver::awaitOk(uint32_t timeout_ms) {
  waiting_ok_ = true;
  wait_started_ms_ = millis();

  while (waiting_ok_) {
    pollRx();
    if (!waiting_ok_) {
      return true;
    }
    if ((millis() - wait_started_ms_) >= timeout_ms) {
      Serial.println("rylr998: AT timeout");
      waiting_ok_ = false;
      return false;
    }
  }
  return true;
}

void Rylr998Receiver::begin() {
  pulseReset();
  serial_.begin(LoraConfig::kBaud, SERIAL_8N1, LoraConfig::kRxPin,
                LoraConfig::kTxPin);
  delay(50);

  Serial.println("rylr998: configuring");

  char cmd[48];
  writeCommand("AT");
  awaitOk(LoraConfig::kReplyTimeoutMs);

  snprintf(cmd, sizeof(cmd), "AT+ADDRESS=%u",
           static_cast<unsigned>(LoraConfig::kDestAddress));
  writeCommand(cmd);
  awaitOk(LoraConfig::kReplyTimeoutMs);

  snprintf(cmd, sizeof(cmd), "AT+NETWORKID=%u",
           static_cast<unsigned>(LoraConfig::kNetworkId));
  writeCommand(cmd);
  awaitOk(LoraConfig::kReplyTimeoutMs);

  snprintf(cmd, sizeof(cmd), "AT+BAND=%lu",
           static_cast<unsigned long>(LoraConfig::kBandHz));
  writeCommand(cmd);
  awaitOk(LoraConfig::kReplyTimeoutMs);

  Serial.println("rylr998: setup done");
}

void Rylr998Receiver::pollRx() {
  while (serial_.available() > 0) {
    processRxByte(static_cast<char>(serial_.read()));
  }
}

void Rylr998Receiver::update() { pollRx(); }

void Rylr998Receiver::processRxByte(char c) {
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

void Rylr998Receiver::handleLine(const char* line) {
  if (strcmp(line, "+OK") == 0) {
    waiting_ok_ = false;
    return;
  }
  if (strncmp(line, "+ERR", 4) == 0) {
    waiting_ok_ = false;
    Serial.print("rylr998: ");
    Serial.println(line);
    return;
  }
  storeRcvPayload(line);
}

bool Rylr998Receiver::storeRcvPayload(const char* line) {
  static constexpr char kPrefix[] = "+RCV=";
  if (strncmp(line, kPrefix, sizeof(kPrefix) - 1) != 0) {
    return false;
  }
  if (payload_ready_) {
    return false;
  }

  const char* address_end = strchr(line + (sizeof(kPrefix) - 1), ',');
  if (address_end == nullptr || address_end[1] == '\0') {
    return false;
  }

  char* length_end = nullptr;
  const unsigned long length = strtoul(address_end + 1, &length_end, 10);
  if (length_end == address_end + 1 || *length_end != ',') {
    return false;
  }
  if (length == 0 || length > LoraConfig::kMaxPayload) {
    return false;
  }

  const char* data = length_end + 1;
  if (strlen(data) < length + 1 || data[length] != ',') {
    return false;
  }

  memcpy(payload_, data, length);
  payload_[length] = '\0';
  payload_len_ = static_cast<size_t>(length);
  payload_ready_ = true;
  return true;
}

bool Rylr998Receiver::takePayload(char* buf, size_t buf_len, size_t* out_len) {
  if (!payload_ready_ || buf == nullptr || out_len == nullptr ||
      buf_len < payload_len_ + 1) {
    return false;
  }
  memcpy(buf, payload_, payload_len_ + 1);
  *out_len = payload_len_;
  payload_ready_ = false;
  payload_len_ = 0;
  return true;
}
