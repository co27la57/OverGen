# rtl —— 最小可编程空间 fabric + AXI4-Lite 控制

## 模块

| 文件 | 说明 |
|---|---|
| `overlay_regs.vh` | 寄存器映射（Host ↔ overlay 的软件接口） |
| `scratchpad.v` | 双端口片上存储（AXI 侧 / fabric 侧），异步读 |
| `fabric.v` | `TILE x TILE` MAC 阵列（output-stationary 广播模型） |
| `overlay_ctrl.v` | AXI4-Lite 从机 + 寄存器组 + 计算 FSM |
| `overlay_top.v` | 顶层，可直接作为 AXI4-Lite 从设备接入 Zynq PS |

## 数据流

```
PS(ARM) --AXI4-Lite--> overlay_ctrl --配置/启动-->
                          | 装载 A/B
                          v
                       scratchpad <---> fabric(TILE x TILE MAC)
                          ^ 写回 C
```

## 寄存器映射

| 偏移 | 名称 | R/W | 说明 |
|---|---|---|---|
| 0x00 | CTRL | W | bit0=start，bit1=soft_reset |
| 0x04 | STATUS | R | bit0=busy，bit1=done |
| 0x08 | DIM_M | W/R | M |
| 0x0C | DIM_N | W/R | N |
| 0x10 | DIM_K | W/R | K |
| 0x14 | SCR_ADDR | W/R | scratchpad 字地址 |
| 0x18 | SCR_WDATA | W | 写入 SCR_ADDR 处 |
| 0x1C | SCR_RDATA | R | 读出 SCR_ADDR 处 |
| 0x20 | PERF_CYCLES | R | 上次运行的周期数 |

## scratchpad 布局（骨架：M=N=TILE=4）

| 区域 | 字数 | 说明 |
|---|---|---|
| A | M*K | 行主序 |
| B | K*N | 行主序 |
| C | M*N | 行主序 |

## 参数

- `TILE`：阵列维度（默认 4 → 16 个 MAC）。增大即扩展并行度。
- `W`：操作数位宽（默认 16；`DATA_W` 需 = `2*W`，默认 32）。

## 仿真

```bash
scripts/sim.sh          # Verilator 编译 + 运行 tb_overlay_top
```

期望输出：`==== TEST PASSED ====`。

## 已知边界 / 后续工作

- 骨架仅支持 **M = N = TILE**（一轮阵列算完一个 tile）；通用 M/N/K 需外层 tiling。
- scratchpad 采用"异步读 + 单字加载/回读"，便于验证；真实设计应改为 **AXI4 主/DMA 批量搬运** + 同步读流水。
- 增加流水线与多 bank 可进一步提升频率与吞吐。
