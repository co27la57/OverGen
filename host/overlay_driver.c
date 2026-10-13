/*
 * overlay_driver.c —— Overlay ARM 用户态驱动实现
 */
#include "overlay_driver.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <sys/mman.h>

struct overlay_dev {
    int               fd;
    volatile uint32_t *regs;
    uint32_t          map_size;
};

overlay_dev_t *overlay_open(uint32_t base_phys, uint32_t map_size)
{
    overlay_dev_t *dev = (overlay_dev_t *)calloc(1, sizeof(*dev));
    if (!dev) return NULL;

    dev->fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (dev->fd < 0) {
        perror("[overlay] open /dev/mem");
        free(dev);
        return NULL;
    }

    void *p = mmap(NULL, map_size, PROT_READ | PROT_WRITE, MAP_SHARED,
                   dev->fd, base_phys);
    if (p == MAP_FAILED) {
        perror("[overlay] mmap");
        close(dev->fd);
        free(dev);
        return NULL;
    }

    dev->regs     = (volatile uint32_t *)p;
    dev->map_size = map_size;
    return dev;
}

void overlay_close(overlay_dev_t *dev)
{
    if (!dev) return;
    if (dev->regs) munmap((void *)dev->regs, dev->map_size);
    if (dev->fd >= 0) close(dev->fd);
    free(dev);
}

void overlay_write_reg(overlay_dev_t *dev, uint32_t off, uint32_t val)
{
    dev->regs[off >> 2] = val;
}

uint32_t overlay_read_reg(overlay_dev_t *dev, uint32_t off)
{
    return dev->regs[off >> 2];
}

void overlay_scr_write(overlay_dev_t *dev, uint32_t word_addr, uint32_t val)
{
    overlay_write_reg(dev, OV_SCR_ADDR,  word_addr);
    overlay_write_reg(dev, OV_SCR_WDATA, val);
}

uint32_t overlay_scr_read(overlay_dev_t *dev, uint32_t word_addr)
{
    overlay_write_reg(dev, OV_SCR_ADDR, word_addr);
    return overlay_read_reg(dev, OV_SCR_RDATA);
}

static double now_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}

int overlay_run_gemm(overlay_dev_t *dev,
                     const uint16_t *A, const uint16_t *B, uint16_t *C,
                     int M, int N, int K)
{
    if (M != OV_TILE || N != OV_TILE) {
        fprintf(stderr, "[overlay] 骨架仅支持 M=N=%d（当前 M=%d,N=%d）\n",
                OV_TILE, M, N);
        return -1;
    }
    if (K <= 0 || K > 4096) {
        fprintf(stderr, "[overlay] K 非法: %d\n", K);
        return -1;
    }

    const int A_BASE = 0;
    const int B_BASE = M * K;
    const int C_BASE = M * K + K * N;

    /* 1) 配置维度 */
    overlay_write_reg(dev, OV_DIM_M, (uint32_t)M);
    overlay_write_reg(dev, OV_DIM_N, (uint32_t)N);
    overlay_write_reg(dev, OV_DIM_K, (uint32_t)K);

    /* 2) 载入 A（M x K）与 B（K x N） */
    for (int i = 0; i < M; i++)
        for (int k = 0; k < K; k++)
            overlay_scr_write(dev, A_BASE + i * K + k, A[i * K + k]);

    for (int k = 0; k < K; k++)
        for (int j = 0; j < N; j++)
            overlay_scr_write(dev, B_BASE + k * N + j, B[k * N + j]);

    /* 3) 启动 */
    double t0 = now_ms();
    overlay_write_reg(dev, OV_CTRL, 0x1);   /* start */

    /* 4) 轮询 done（超时保护） */
    uint32_t st = 0;
    for (int spin = 0; spin < 10000000; spin++) {
        st = overlay_read_reg(dev, OV_STATUS);
        if (st & OV_STATUS_DONE) break;
    }
    double t1 = now_ms();

    if (!(st & OV_STATUS_DONE)) {
        fprintf(stderr, "[overlay] 等待 done 超时\n");
        return -2;
    }

    /* 5) 回读 C（M x N） */
    for (int i = 0; i < M; i++)
        for (int j = 0; j < N; j++)
            C[i * N + j] = (uint16_t)(overlay_scr_read(dev, C_BASE + i * N + j) & 0xFFFF);

    uint32_t cyc = overlay_read_reg(dev, OV_PERF_CYCLES);
    printf("[overlay] GEMM %dx%dx%d 完成: %u 周期, 端到端 %.4f ms\n",
           M, N, K, cyc, t1 - t0);
    return 0;
}
