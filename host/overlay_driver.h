/*
 * overlay_driver.h —— Overlay 的 ARM 用户态驱动接口
 * ---------------------------------------------------------------------------
 * 通过 /dev/mem + mmap 把 overlay_top 的 AXI4-Lite 寄存器映射到用户空间，
 * 提供寄存器读写、scratchpad 访问、以及 GEMM 派发接口。
 *
 * 这是 C3 贡献（ARM PS host + PL overlay 集成）的最小可用形态。
 * 真实产品化应改为 UIO / 内核驱动 / DMA，此处作为骨架以 mmap 演示。
 * ---------------------------------------------------------------------------
 */
#ifndef OVERLAY_DRIVER_H
#define OVERLAY_DRIVER_H

#include <stdint.h>

/* fabric 阵列维度（需与 RTL 参数 TILE 一致） */
#define OV_TILE 4

/* 寄存器偏移（字节） —— 与 rtl/overlay_regs.vh 保持一致 */
#define OV_CTRL        0x00   /* [0]=start, [1]=soft_reset            */
#define OV_STATUS      0x04   /* [0]=busy,  [1]=done                  */
#define OV_DIM_M       0x08
#define OV_DIM_N       0x0C
#define OV_DIM_K       0x10
#define OV_SCR_ADDR    0x14
#define OV_SCR_WDATA   0x18
#define OV_SCR_RDATA   0x1C
#define OV_PERF_CYCLES 0x20

#define OV_STATUS_BUSY (1u << 0)
#define OV_STATUS_DONE (1u << 1)

typedef struct overlay_dev overlay_dev_t;

/* 打开设备：base_phys 为 AXI 基地址，map_size 为映射字节数（建议 >= 0x1000） */
overlay_dev_t *overlay_open(uint32_t base_phys, uint32_t map_size);
void overlay_close(overlay_dev_t *dev);

/* 寄存器读写 */
void     overlay_write_reg(overlay_dev_t *dev, uint32_t off, uint32_t val);
uint32_t overlay_read_reg (overlay_dev_t *dev, uint32_t off);

/* scratchpad 字访问 */
void     overlay_scr_write(overlay_dev_t *dev, uint32_t word_addr, uint32_t val);
uint32_t overlay_scr_read (overlay_dev_t *dev, uint32_t word_addr);

/*
 * 派发一次 GEMM：C = A x B
 *   A: M x K（行主序），B: K x N（行主序），C: M x N（行主序）
 * 骨架约束：M == N == OV_TILE（一轮阵列算完）；K 任意。
 * 返回 0 成功；<0 失败（参数不合法 / 超时）。
 */
int overlay_run_gemm(overlay_dev_t *dev,
                     const uint16_t *A, const uint16_t *B, uint16_t *C,
                     int M, int N, int K);

#endif /* OVERLAY_DRIVER_H */
