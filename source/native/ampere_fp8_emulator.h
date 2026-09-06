#pragma once

#include <cstdint>
#include <cstddef>
#include <atomic>

namespace ampere_emulation
{
// FP8 format specifications used in NVIDIA Ada Lovelace (SM 8.9) and Blackwell (SM 12.0)
enum class Fp8Format : uint32_t
{
    eE4M3 = 0, // 1 sign bit, 4 exponent bits, 3 mantissa bits (bias 7) - inference weights
    eE5M2 = 1  // 1 sign bit, 5 exponent bits, 2 mantissa bits (bias 15) - dynamic activations
};

// Software conversion between FP8 and IEEE 754 half-precision FP16
uint16_t ConvertFp8ToFp16(uint8_t fp8Value, Fp8Format format) noexcept;
uint8_t ConvertFp16ToFp8(uint16_t fp16Value, Fp8Format format) noexcept;

// Batch buffer conversion for generic CUDA core streaming
void BatchConvertFp8ToFp16(const uint8_t* source, uint16_t* destination,
    size_t count, Fp8Format format) noexcept;

// Emulated Tensor Core Matrix-Multiply Accumulate (MMA tile 16x8x32)
// Emulates hardware instruction: mma.sync.aligned.m16n8k32.row.col.f32.e4m3.e4m3
// Transforms unsupported FP8 tensor ops into FP16/FP32 operations runnable on Ampere (SM 8.6)
void EmulateMmaM16N8K32_Fp8ToFp32(
    const uint8_t* matrixA_e4m3, // 16 x 32 elements
    const uint8_t* matrixB_e4m3, // 32 x 8 elements
    const float* matrixC_f32,    // 16 x 8 accumulator input
    float* matrixD_f32           // 16 x 8 accumulator output
) noexcept;

// Emulation State & Telemetry
bool IsEmulationActive() noexcept;
void SetEmulationActive(bool active) noexcept;
uint64_t GetEmulatedOperationCount() noexcept;
void IncrementEmulatedOperationCount(uint64_t delta = 1) noexcept;
}
