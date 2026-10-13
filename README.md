# OverGen Follow-up: 面向低成本 Zynq 的可编程空间加速器研究

> 跟随 UCLA PolyArch 的 **DSAGEN (ISCA'20)** / **OverGen (MICRO'22)** 路线，在低成本商用 **Zynq-7020** 上做可编程空间加速器的**实测**与**集成**研究。

## 一句话定位

在低成本的商用 Zynq-7020 上，用真实硅的受控实验回答三个问题：

1. **可编程 overlay 相对 HLS 固定加速器的代价与收益到底是多少？**（实测 PPA / 功耗）
2. **在资源受限器件上，可编程 overlay 能撑多小、何时失效？**（可行性边界）
3. **如何在 ARM SoC（PS + PL）上真正落地这套 overlay？**（集成方案与 runtime）

## 硬件平台

| 板卡 | 器件 | 关键资源 | 硬处理器 | 角色 |
|---|---|---|---|---|
| Zynq-7010 | Artix-7 级 | ~17.6K LUT, 80 DSP, 2.1Mb BRAM | 双核 Cortex-A9 | 流程冒烟测试 |
| **Zynq-7020** | 中端 | ~53K LUT, 220 DSP, 4.9Mb BRAM | 双核 Cortex-A9 | **主验证平台** |
| KU3P (XCKU3P) | Kintex UltraScale+ | ~170K LUT, 1368 DSP, 11Mb+22.5Mb URAM | **无硬核** | 后续放大（需 MicroBlaze / 外挂主机） |

## 仓库结构

```
.
├── README.md                     # 本文件：项目总览与定位
├── docs/                         # 研究资料与计划
│   ├── 01-background.md          # DSA 概念 + DSAGEN 框架/教程概述
│   ├── 02-literature-review.md   # 论文线梳理（5 篇）+ 逐篇概括
│   ├── 03-people-research.md     # Tony Nowatzki / Jian Weng 研究方向
│   ├── 04-dsagen-vs-hls.md       # DSAGEN 相对 HLS 的优势
│   ├── 05-followup-plan.md       # 基于 Zynq-7020 的 follow-up 路线图
│   ├── 06-contributions.md       # 贡献清单与定位（含"不算贡献"的黑名单）
│   └── 07-research-plan-C1-C3.md # C1+C3 详细研究计划与实验设计
├── rtl/                          # 最小空间 fabric + AXI4-Lite 控制（骨架）
├── tb/                           # 仿真 testbench
├── host/                         # ARM 用户态驱动与示例 kernel
├── scripts/                      # Vivado 建工程 / 构建脚本
└── constraints/                  # 7020 引脚与时钟约束
```

## 上游资源

- **DSA Framework 文档**：https://dsa-framework.readthedocs.io/en/latest/Tutorial/
- **上游仓库**：https://github.com/PolyArch/dsa-framework （Docker + Chisel + gem5 + LLVM）
- **Jian Weng 主页**：https://were.github.io

## 状态

- [x] 资料整理与仓库初始化
- [x] C1+C3 研究计划文档
- [x] 7020 集成骨架（RTL + TB + host 驱动 + Vivado 脚本）
  - RTL 已通过 Verilator lint，4x4x4 GEMM testbench **PASSED**（`perf_cycles=58`）
  - Host 驱动本地编译通过
- [ ] 上板实测（bitstream + PetaLinux 部署）
- [ ] 同板 HLS 对照实验

### 快速开始

```bash
scripts/sim.sh                                  # 跑 RTL 仿真（期望 TEST PASSED）
cd host && make CROSS=arm-linux-gnueabihf-       # 交叉编译 ARM 驱动
vivado -mode batch -source scripts/create_project.tcl   # 建立 7020 工程
```

## 许可

研究用资料整理；RTL/软件骨架为原创，欢迎在此基础上继续开发。
