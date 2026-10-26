#include "bluetooth_payload_output.h"

#include <Arduino.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

namespace {

class RestartAdvertising : public BLEServerCallbacks {
  void onDisconnect(BLEServer* server) override { server->startAdvertising(); }
};

RestartAdvertising restart_advertising;

}  // namespace

void BluetoothPayloadOutput::begin() {
  BLEDevice::init(kDeviceName);
  BLEDevice::setMTU(kLocalMtu);

  server_ = BLEDevice::createServer();
  server_->setCallbacks(&restart_advertising);

  BLEService* service = server_->createService(kServiceUUID);
  payload_ = service->createCharacteristic(
      kPayloadUUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  payload_->addDescriptor(new BLE2902());
  service->start();

  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(kServiceUUID);
  BLEDevice::startAdvertising();
  Serial.println("bluetooth: advertising");
}

void BluetoothPayloadOutput::publish(const char* payload, size_t length) {
  if (payload == nullptr || length == 0 || payload_ == nullptr || server_ == nullptr) {
    return;
  }
  if (server_->getConnectedCount() == 0) {
    return;
  }

  const uint16_t mtu = server_->getPeerMTU(server_->getConnId());
  if (mtu < 3 || length > static_cast<size_t>(mtu - 3)) {
    Serial.println("bluetooth: payload larger than MTU");
    return;
  }

  payload_->setValue(reinterpret_cast<const uint8_t*>(payload), length);
  payload_->notify();
}
