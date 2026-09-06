#include "ampere_fp8_emulator.h"

#include <cmath>
#include <cstring>
#include <array>

namespace ampere_emulation
{
namespace
{
std::atomic<bool> gEmulationActive{false};
std::atomic<uint64_t> gEmulatedOperationCount{0};

// Pre-computed lookup tables for fast branchless conversion of 8-bit floats to 16-bit half floats
struct ConversionTables
{
    std::array<uint16_t, 256> e4m3ToFp16{};
    std::array<uint16_t, 256> e5m2ToFp16{};
    std::array<float, 256> e4m3ToFp32{};

    ConversionTables() noexcept
    {
        for (uint32_t i = 0; i < 256; ++i)
        {
            const uint8_t byte = static_cast<uint8_t>(i);

            // Compute E4M3 -> float -> FP16
            // E4M3: sign(1), exponent(4, bias 7), mantissa(3)
            const uint32_t sign = (byte >> 7) & 0x1;
            const uint32_t exp = (byte >> 3) & 0xF;
            const uint32_t mant = byte & 0x7;

            float valF32 = 0.0f;
            if (exp == 0)
            {
                // Subnormal
                valF32 = std::ldexp(static_cast<float>(mant) / 8.0f, -6);
            }
            else if (exp == 15 && mant == 7)
            {
                // NaN
                valF32 = NAN;
            }
            else
            {
                // Normalized
                valF32 = std::ldexp(1.0f + static_cast<float>(mant) / 8.0f, static_cast<int>(exp) - 7);
            }
            if (sign) valF32 = -valF32;
            e4m3ToFp32[i] = valF32;

            // Simple float to FP16 bitcast approximation
            uint32_t f32Bits = 0;
            std::memcpy(&f32Bits, &valF32, sizeof(f32Bits));
            const uint16_t f16Sign = static_cast<uint16_t>((f32Bits >> 16) & 0x8000);
            int32_t f16Exp = static_cast<int32_t>(((f32Bits >> 23) & 0xFF) - 127 + 15);
            uint32_t f16Mant = (f32Bits >> 13) & 0x3FF;

            if (f16Exp <= 0)
            {
                e4m3ToFp16[i] = f16Sign;
            }
            else if (f16Exp >= 31)
            {
                e4m3ToFp16[i] = f16Sign | 0x7C00;
            }
            else
            {
                e4m3ToFp16[i] = static_cast<uint16_t>(f16Sign | (f16Exp << 10) | f16Mant);
            }

            // Compute E5M2 -> FP16
            // E5M2: sign(1), exponent(5, bias 15), mantissa(2)
            // Exponent bias is identical to FP16 (15)! Mantissa simply shifts up by 8 bits
            const uint16_t signBit = static_cast<uint16_t>((byte & 0x80) << 8);
            const uint16_t expBits = static_cast<uint16_t>((byte & 0x7C) << 8);
            const uint16_t mantBits = static_cast<uint16_t>((byte & 0x03) << 8);
            e5m2ToFp16[i] = signBit | expBits | mantBits;
        }
    }
};

const ConversionTables gTables;
}

uint16_t ConvertFp8ToFp16(uint8_t fp8Value, Fp8Format format) noexcept
{
    return (format == Fp8Format::eE4M3)
        ? gTables.e4m3ToFp16[fp8Value]
        : gTables.e5m2ToFp16[fp8Value];
}

uint8_t ConvertFp16ToFp8(uint16_t fp16Value, Fp8Format format) noexcept
{
    const uint32_t sign = (fp16Value >> 15) & 0x1;
    const int32_t exp = (fp16Value >> 10) & 0x1F;
    const uint32_t mant = fp16Value & 0x3FF;

    if (format == Fp8Format::eE5M2)
    {
        // Direct conversion: truncate 10-bit mantissa to 2 bits
        return static_cast<uint8_t>((sign << 7) | ((exp & 0x1F) << 2) | ((mant >> 8) & 0x3));
    }
    else
    {
        // E4M3 conversion (bias 7 vs bias 15): exp - 15 + 7 = exp - 8
        int32_t e4m3Exp = exp - 8;
        if (e4m3Exp < 0) e4m3Exp = 0;
        if (e4m3Exp > 15) e4m3Exp = 15;
        const uint32_t e4m3Mant = (mant >> 7) & 0x7;
        return static_cast<uint8_t>((sign << 7) | ((e4m3Exp & 0xF) << 3) | e4m3Mant);
    }
}

void BatchConvertFp8ToFp16(const uint8_t* source, uint16_t* destination,
    size_t count, Fp8Format format) noexcept
{
    if (!source || !destination || count == 0)
        return;

    const uint16_t* const table = (format == Fp8Format::eE4M3)
        ? gTables.e4m3ToFp16.data()
        : gTables.e5m2ToFp16.data();

    for (size_t i = 0; i < count; ++i)
    {
        destination[i] = table[source[i]];
    }
    gEmulatedOperationCount.fetch_add(count, std::memory_order_relaxed);
}

void EmulateMmaM16N8K32_Fp8ToFp32(
    const uint8_t* matrixA_e4m3,
    const uint8_t* matrixB_e4m3,
    const float* matrixC_f32,
    float* matrixD_f32
) noexcept
{
    if (!matrixA_e4m3 || !matrixB_e4m3 || !matrixD_f32)
        return;

    // Tile dimensions for m16n8k32
    constexpr size_t M = 16;
    constexpr size_t N = 8;
    constexpr size_t K = 32;

    for (size_t i = 0; i < M; ++i)
    {
        for (size_t j = 0; j < N; ++j)
        {
            float acc = matrixC_f32 ? matrixC_f32[i * N + j] : 0.0f;
            for (size_t k = 0; k < K; ++k)
            {
                // Look up FP32 values for FP8 E4M3 weights and multiply-accumulate
                const float a = gTables.e4m3ToFp32[matrixA_e4m3[i * K + k]];
                const float b = gTables.e4m3ToFp32[matrixB_e4m3[k * N + j]];
                acc += a * b;
            }
            matrixD_f32[i * N + j] = acc;
        }
    }
    gEmulatedOperationCount.fetch_add(M * N * K, std::memory_order_relaxed);
}

bool IsEmulationActive() noexcept
{
    return gEmulationActive.load(std::memory_order_acquire);
}

void SetEmulationActive(bool active) noexcept
{
    gEmulationActive.store(active, std::memory_order_release);
}

uint64_t GetEmulatedOperationCount() noexcept
{
    return gEmulatedOperationCount.load(std::memory_order_acquire);
}

void IncrementEmulatedOperationCount(uint64_t delta) noexcept
{
    gEmulatedOperationCount.fetch_add(delta, std::memory_order_relaxed);
}
}
