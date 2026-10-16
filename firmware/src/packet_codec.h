#pragma once

#include <stddef.h>

#include "telemetry.h"

namespace PacketCodec {

// Max length of an encoded line including NUL.
static constexpr size_t kMaxEncodedLen = 160;

// Writes a single-line packet into buf. Returns bytes written (excluding NUL),
// or 0 on failure.
size_t encode(const Telemetry& t, char* buf, size_t buf_len);

}  // namespace PacketCodec
