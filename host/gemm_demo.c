/*
 * gemm_demo.c —— 在 Zynq PS 上调用 PL overlay 完成一次 4x4x4 GEMM 并校验
 * ---------------------------------------------------------------------------
 * 用法： ./gemm_demo [AXI_BASE_PHYS]
 *   默认 AXI_BASE_PHYS = 0x43C00000（请在 Vivado Address Editor 中确认实际值）
 * ---------------------------------------------------------------------------
 */
#include "overlay_driver.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define DEFAULT_BASE 0x43C00000u
#define MAP_SIZE     0x1000u

int main(int argc, char **argv)
{
    uint32_t base = (argc > 1) ? (uint32_t)strtoul(argv[1], NULL, 0) : DEFAULT_BASE;
    const int M = OV_TILE, N = OV_TILE, K = OV_TILE;

    printf("== Overlay GEMM demo ==\n");
    printf("AXI base = 0x%08X, 规模 %dx%dx%d\n", base, M, N, K);

    overlay_dev_t *dev = overlay_open(base, MAP_SIZE);
    if (!dev) {
        fprintf(stderr, "打开 overlay 失败（检查 /dev/mem 权限与基地址）\n");
        return 1;
    }

    /* 构造 A、B（与 RTL testbench 相同的简单模式，便于对照） */
    uint16_t A[OV_TILE * OV_TILE], B[OV_TILE * OV_TILE];
    uint16_t C[OV_TILE * OV_TILE], REF[OV_TILE * OV_TILE];

    for (int i = 0; i < M * K; i++) A[i] = (uint16_t)(i + 1);
    for (int i = 0; i < K * N; i++) B[i] = (uint16_t)(16 - i);

    /* 软件参考 */
    for (int i = 0; i < M; i++)
        for (int j = 0; j < N; j++) {
            uint32_t acc = 0;
            for (int k = 0; k < K; k++) acc += (uint32_t)A[i * K + k] * B[k * N + j];
            REF[i * N + j] = (uint16_t)acc;
        }

    /* 硬件执行 */
    int rc = overlay_run_gemm(dev, A, B, C, M, N, K);
    overlay_close(dev);
    if (rc != 0) {
        fprintf(stderr, "overlay_run_gemm 失败 rc=%d\n", rc);
        return 2;
    }

    /* 校验 + 打印 */
    int errors = 0;
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) {
            int idx = i * N + j;
            printf("C[%d][%d] = %5u  (ref %5u)%s\n",
                   i, j, C[idx], REF[idx], (C[idx] == REF[idx]) ? "" : "  <-- MISMATCH");
            if (C[idx] != REF[idx]) errors++;
        }
    }

    printf(errors == 0 ? "\n==== DEMO PASSED ====\n"
                       : "\n==== DEMO FAILED (%d errors) ====\n", errors);
    return errors == 0 ? 0 : 3;
}
