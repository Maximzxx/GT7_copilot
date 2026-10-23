#ifndef GT7PACKET_H
#define GT7PACKET_H

// Decodificación de los paquetes de telemetría de Gran Turismo 7.
// Soporta los tres tipos documentados: "A" (296 bytes), "B" (316) y "~" (344).
// Los tres empiezan con la misma estructura, así que los campos que usamos se
// leen igual; solo cambia la constante del nonce. El paquete "C" (368) no se
// soporta porque su constante no está documentada.
// No depende de Qt, así que se puede probar por separado.
//
// Formato según la documentación de la comunidad (MacManley/gt7-udp y las
// herramientas PDTools de Nenkai):
//   - Cifrado Salsa20/20. Clave: primeros 32 bytes de
//     "Simulator Interface Packet GT7 ver 0.0".
//   - Nonce de 8 bytes: iv1 = bytes 0x40..0x43 del paquete cifrado (little-endian),
//     iv2 = iv1 ^ constante (A: 0xDEADBEAF, B: 0xDEADBEEF, ~: 0x55FABB4F).
//     El nonce es iv2 (LE) seguido de iv1 (LE).
//   - Al descifrar, los 4 primeros bytes valen 0x47375330 ("G7S0").
//   - Todos los números son little-endian.

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstring>

namespace gt7 {

constexpr std::size_t kPacketSize = 296;         // paquete A
constexpr std::size_t kPacketSizeB = 316;        // paquete B (no existe en modo Sport)
constexpr std::size_t kPacketSizeTilde = 344;    // paquete ~ (no existe en repeticiones)
constexpr std::uint32_t kMagic = 0x47375330u;
constexpr std::uint32_t kIvXor = 0xDEADBEAFu;    // A
constexpr std::uint32_t kIvXorB = 0xDEADBEEFu;
constexpr std::uint32_t kIvXorTilde = 0x55FABB4Fu;

namespace detail {

inline std::uint32_t rotl(std::uint32_t v, int c)
{
    return (v << c) | (v >> (32 - c));
}

inline std::uint32_t le32(const std::uint8_t *p)
{
    return static_cast<std::uint32_t>(p[0])
         | (static_cast<std::uint32_t>(p[1]) << 8)
         | (static_cast<std::uint32_t>(p[2]) << 16)
         | (static_cast<std::uint32_t>(p[3]) << 24);
}

inline void putLe32(std::uint8_t *p, std::uint32_t v)
{
    p[0] = static_cast<std::uint8_t>(v);
    p[1] = static_cast<std::uint8_t>(v >> 8);
    p[2] = static_cast<std::uint8_t>(v >> 16);
    p[3] = static_cast<std::uint8_t>(v >> 24);
}

inline std::int16_t leI16(const std::uint8_t *p)
{
    return static_cast<std::int16_t>(
        static_cast<std::uint16_t>(p[0] | (p[1] << 8)));
}

inline std::int32_t leI32(const std::uint8_t *p)
{
    return static_cast<std::int32_t>(le32(p));
}

inline float leFloat(const std::uint8_t *p)
{
    const std::uint32_t bits = le32(p);
    float value;
    std::memcpy(&value, &bits, sizeof(value));
    return value;
}

// Un bloque de 64 bytes del keystream de Salsa20/20.
inline void salsa20Block(const std::uint32_t in[16], std::uint8_t out[64])
{
    std::uint32_t x[16];
    for (int i = 0; i < 16; ++i)
        x[i] = in[i];

    for (int round = 0; round < 20; round += 2) {
        // Ronda de columnas.
        x[4]  ^= rotl(x[0]  + x[12], 7);
        x[8]  ^= rotl(x[4]  + x[0],  9);
        x[12] ^= rotl(x[8]  + x[4],  13);
        x[0]  ^= rotl(x[12] + x[8],  18);
        x[9]  ^= rotl(x[5]  + x[1],  7);
        x[13] ^= rotl(x[9]  + x[5],  9);
        x[1]  ^= rotl(x[13] + x[9],  13);
        x[5]  ^= rotl(x[1]  + x[13], 18);
        x[14] ^= rotl(x[10] + x[6],  7);
        x[2]  ^= rotl(x[14] + x[10], 9);
        x[6]  ^= rotl(x[2]  + x[14], 13);
        x[10] ^= rotl(x[6]  + x[2],  18);
        x[3]  ^= rotl(x[15] + x[11], 7);
        x[7]  ^= rotl(x[3]  + x[15], 9);
        x[11] ^= rotl(x[7]  + x[3],  13);
        x[15] ^= rotl(x[11] + x[7],  18);
        // Ronda de filas.
        x[1]  ^= rotl(x[0]  + x[3],  7);
        x[2]  ^= rotl(x[1]  + x[0],  9);
        x[3]  ^= rotl(x[2]  + x[1],  13);
        x[0]  ^= rotl(x[3]  + x[2],  18);
        x[6]  ^= rotl(x[5]  + x[4],  7);
        x[7]  ^= rotl(x[6]  + x[5],  9);
        x[4]  ^= rotl(x[7]  + x[6],  13);
        x[5]  ^= rotl(x[4]  + x[7],  18);
        x[11] ^= rotl(x[10] + x[9],  7);
        x[8]  ^= rotl(x[11] + x[10], 9);
        x[9]  ^= rotl(x[8]  + x[11], 13);
        x[10] ^= rotl(x[9]  + x[8],  18);
        x[12] ^= rotl(x[15] + x[14], 7);
        x[13] ^= rotl(x[12] + x[15], 9);
        x[14] ^= rotl(x[13] + x[12], 13);
        x[15] ^= rotl(x[14] + x[13], 18);
    }

    for (int i = 0; i < 16; ++i)
        putLe32(out + 4 * i, x[i] + in[i]);
}

} // namespace detail

// Aplica Salsa20/20 (clave de 256 bits, nonce de 64 bits, contador desde 0).
// Cifrar y descifrar son la misma operación.
inline void salsa20Xor(const std::uint8_t key[32], const std::uint8_t nonce[8],
                       const std::uint8_t *in, std::uint8_t *out, std::size_t len)
{
    using namespace detail;

    std::uint32_t state[16];
    state[0]  = 0x61707865u;            // "expa"
    state[1]  = le32(key + 0);
    state[2]  = le32(key + 4);
    state[3]  = le32(key + 8);
    state[4]  = le32(key + 12);
    state[5]  = 0x3320646eu;            // "nd 3"
    state[6]  = le32(nonce);
    state[7]  = le32(nonce + 4);
    state[8]  = 0;                      // contador, parte baja
    state[9]  = 0;                      // contador, parte alta
    state[10] = 0x79622d32u;            // "2-by"
    state[11] = le32(key + 16);
    state[12] = le32(key + 20);
    state[13] = le32(key + 24);
    state[14] = le32(key + 28);
    state[15] = 0x6b206574u;            // "te k"

    std::uint8_t block[64];
    for (std::size_t offset = 0; offset < len; offset += 64) {
        salsa20Block(state, block);
        const std::size_t count = std::min<std::size_t>(64, len - offset);
        for (std::size_t i = 0; i < count; ++i)
            out[offset + i] = in[offset + i] ^ block[i];
        if (++state[8] == 0)
            ++state[9];
    }
}

// Campos del paquete A que usa la aplicación.
struct Sample
{
    float posX = 0, posY = 0, posZ = 0;     // metros; Y es la altura
    float velX = 0, velY = 0, velZ = 0;     // m/s
    float rpm = 0;
    float speedMs = 0;                      // m/s
    std::int32_t packetId = 0;
    std::int16_t lapCount = 0;
    std::int16_t totalLaps = 0;
    std::int32_t bestLapMs = -1;            // -1 si no hay
    std::int32_t lastLapMs = -1;            // -1 si no hay
    std::int16_t minAlertRpm = 0;
    std::int16_t maxAlertRpm = 0;
    std::int16_t flags = 0;
    int gear = 0;                           // marcha actual
    int suggestedGear = 0;                  // 15 si no hay sugerencia
    float throttle = 0;                     // 0 a 1
    float brake = 0;                        // 0 a 1

    bool onTrack() const { return (flags & (1 << 0)) != 0; }
    bool paused() const { return (flags & (1 << 1)) != 0; }
    bool loading() const { return (flags & (1 << 2)) != 0; }
    bool inGear() const { return (flags & (1 << 3)) != 0; }
};

// Descifra y lee un paquete A, B o ~ (según su tamaño). Devuelve false si el
// tamaño no es el de ninguno o si la firma "G7S0" no coincide tras descifrar.
inline bool decode(const std::uint8_t *data, std::size_t len, Sample &out)
{
    using namespace detail;

    if (data == nullptr)
        return false;

    std::uint32_t ivXor;
    if (len == kPacketSize)
        ivXor = kIvXor;
    else if (len == kPacketSizeB)
        ivXor = kIvXorB;
    else if (len == kPacketSizeTilde)
        ivXor = kIvXorTilde;
    else
        return false;

    static const char kKeyText[] = "Simulator Interface Packet GT7 ver 0.0";
    std::uint8_t key[32];
    std::memcpy(key, kKeyText, sizeof(key));

    const std::uint32_t iv1 = le32(data + 0x40);
    const std::uint32_t iv2 = iv1 ^ ivXor;
    std::uint8_t nonce[8];
    putLe32(nonce, iv2);
    putLe32(nonce + 4, iv1);

    std::uint8_t p[kPacketSizeTilde];
    salsa20Xor(key, nonce, data, p, len);

    if (le32(p) != kMagic)
        return false;

    out.posX = leFloat(p + 0x04);
    out.posY = leFloat(p + 0x08);
    out.posZ = leFloat(p + 0x0C);
    out.velX = leFloat(p + 0x10);
    out.velY = leFloat(p + 0x14);
    out.velZ = leFloat(p + 0x18);
    out.rpm = leFloat(p + 0x3C);
    out.speedMs = leFloat(p + 0x4C);
    out.packetId = leI32(p + 0x70);
    out.lapCount = leI16(p + 0x74);
    out.totalLaps = leI16(p + 0x76);
    out.bestLapMs = leI32(p + 0x78);
    out.lastLapMs = leI32(p + 0x7C);
    out.minAlertRpm = leI16(p + 0x88);
    out.maxAlertRpm = leI16(p + 0x8A);
    out.flags = leI16(p + 0x8E);
    out.gear = p[0x90] & 0x0F;
    out.suggestedGear = p[0x90] >> 4;
    out.throttle = static_cast<float>(p[0x91]) / 255.0f;
    out.brake = static_cast<float>(p[0x92]) / 255.0f;
    return true;
}

} // namespace gt7

#endif
