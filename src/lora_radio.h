#pragma once

#include <HardwareSerial.h>
#include <stddef.h>

class LoraRadio {
 public:
  explicit LoraRadio(HardwareSerial& serial);

  void begin();
  // Drain UART1 and handle +OK / +ERR / +RCV. Call frequently from loop().
  void update();
  // Queue AT+SEND. Returns false if busy, payload too large, or encode fails.
  bool send(const char* payload, size_t len);
  bool busy() const { return waiting_ok_; }

 private:
  static constexpr size_t kRxLineLen = 256;
  static constexpr size_t kTxCmdLen = 288;

  void pulseReset();
  void writeCommand(const char* cmd);
  bool awaitOk(uint32_t timeout_ms);
  void pollRx();
  void handleLine(const char* line);
  void processRxByte(char c);

  HardwareSerial& serial_;
  char rx_line_[kRxLineLen];
  size_t rx_len_ = 0;
  char tx_cmd_[kTxCmdLen];
  bool waiting_ok_ = false;
  uint32_t wait_started_ms_ = 0;
};
