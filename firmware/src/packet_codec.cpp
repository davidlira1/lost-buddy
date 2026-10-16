#include "packet_codec.h"

#include <cstdio>

namespace PacketCodec {

size_t encode(const Telemetry& t, char* buf, size_t buf_len) {
  if (buf == nullptr || buf_len < 16) {
    return 0;
  }

  const int n = snprintf(
      buf, buf_len,
      "id=%u,seq=%lu,t=%lu,fix=%u,lat=%.6f,lon=%.6f,alt=%.1f,spd=%.1f,cog=%.1f,"
      "hdop=%.1f,bat=%u",
      static_cast<unsigned>(t.id), static_cast<unsigned long>(t.seq),
      static_cast<unsigned long>(t.time_hhmmss),
      t.fix_ok ? 1U : 0U, t.lat, t.lon, static_cast<double>(t.alt_m),
      static_cast<double>(t.speed_kmh), static_cast<double>(t.course_deg),
      static_cast<double>(t.hdop), static_cast<unsigned>(t.bat));

  if (n < 0 || static_cast<size_t>(n) >= buf_len) {
    if (buf_len > 0) {
      buf[0] = '\0';
    }
    return 0;
  }

  return static_cast<size_t>(n);
}

}  // namespace PacketCodec
