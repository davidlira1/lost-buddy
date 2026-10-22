#pragma once

#include <stddef.h>

// Transport-independent receiver. Payloads are raw bytes, not radio status lines.
class RadioReceiver {
 public:
  virtual ~RadioReceiver() = default;

  virtual void begin() = 0;
  virtual void update() = 0;
  // Copies one queued payload into buf and returns true. Drops it from the queue.
  virtual bool takePayload(char* buf, size_t buf_len, size_t* out_len) = 0;
};
