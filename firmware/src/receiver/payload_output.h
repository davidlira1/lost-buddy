#pragma once

#include <stddef.h>

// Sends one received payload onward. The transport stays inside the implementation.
class PayloadOutput {
 public:
  virtual ~PayloadOutput() = default;

  virtual void begin() = 0;
  virtual void publish(const char* payload, size_t length) = 0;
};
