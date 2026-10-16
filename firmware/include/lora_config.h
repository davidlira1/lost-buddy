#pragma once

#include <stddef.h>
#include <stdint.h>

#include "telemetry.h"

namespace LoraConfig {

// UART1: module TXD -> ESP32 RX, module RXD -> ESP32 TX.
static constexpr int kRxPin = 4;
static constexpr int kTxPin = 5;
static constexpr int kRstPin = 15;

static constexpr uint32_t kBaud = 115200;

static constexpr uint16_t kAddress = kDeviceId;
static constexpr uint16_t kDestAddress = 2;
static constexpr uint8_t kNetworkId = 18;
static constexpr uint32_t kBandHz = 915000000;

static constexpr size_t kMaxPayload = 240;
static constexpr uint32_t kReplyTimeoutMs = 2000;
static constexpr uint32_t kResetPulseMs = 100;
static constexpr uint32_t kResetSettleMs = 200;

}  // namespace LoraConfig
