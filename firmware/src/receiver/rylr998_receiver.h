#pragma once

#include <HardwareSerial.h>

#include "radio_receiver.h"

// REYAX RYLR998 adapter. This is the only type that speaks its AT protocol.
class Rylr998Receiver : public RadioReceiver {
 public:
  explicit Rylr998Receiver(HardwareSerial& serial);

  void begin() override;
  void update() override;
  bool takePayload(char* buf, size_t buf_len, size_t* out_len) override;

 private:
  static constexpr size_t kRxLineLen = 320;

  void pulseReset();
  void writeCommand(const char* cmd);
  bool awaitOk(uint32_t timeout_ms);
  void pollRx();
  void processRxByte(char c);
  void handleLine(const char* line);
  bool storeRcvPayload(const char* line);

  HardwareSerial& serial_;
  char rx_line_[kRxLineLen];
  size_t rx_len_ = 0;
  char payload_[241];
  size_t payload_len_ = 0;
  bool payload_ready_ = false;
  bool waiting_ok_ = false;
  uint32_t wait_started_ms_ = 0;
};
