// overlay_regs.vh
// -----------------------------------------------------------------------------
// 寄存器映射（AXI4-Lite，字节偏移）。Host(ARM) 通过该映射配置并启动 overlay。
// word 索引 = awaddr[5:2]（ADDR_W=6，32-bit 对齐）。
// -----------------------------------------------------------------------------
`ifndef OVERLAY_REGS_VH
`define OVERLAY_REGS_VH

// 字索引（word index）
`define REG_CTRL        4'd0   // [0]=start, [1]=soft_reset          (W)
`define REG_STATUS      4'd1   // [0]=busy,  [1]=done                  (R)
`define REG_DIM_M       4'd2   // M = A 行数 / C 行数                   (W/R)
`define REG_DIM_N       4'd3   // N = B 列数 / C 列数                   (W/R)
`define REG_DIM_K       4'd4   // K = 内维                              (W/R)
`define REG_SCR_ADDR    4'd5   // scratchpad 字地址（load/store 用）    (W/R)
`define REG_SCR_WDATA   4'd6   // 写此寄存器 → 向 SCR_ADDR 写入数据     (W)
`define REG_SCR_RDATA   4'd7   // 读此寄存器 → 返回 SCR_ADDR 处数据     (R)
`define REG_PERF_CYCLES 4'd8   // 上次运行的周期数                      (R)

`endif
