# 07 · 研究计划：C1 + C3

> **C1**：真实硅上「可编程 overlay vs HLS 固定加速器」同板同 kernel 实测对照（含功耗）
> **C3**：面向 ARM SoC 的真实集成方案（ARM PS host + PL overlay）

这两条组合即可支撑一篇 **tool / measurement 论文**或**本科毕设**。本文给出完整实验设计。

---

## 1. 研究动机与问题

### 背景
DSAGEN/OverGen 主张可编程 overlay 能以接近 HLS 固定加速器的性能，换取"可编程 + 快速重配置"。但：
- 其 PPA 结论多来自**建模/仿真**；
- 对比对象 AutoDSE 是 DSE-HLS 框架，非"同板、同 kernel、同工具链"的**受控实测**；
- 在**低成本商用器件**（如 Zynq-7020）上的真实代价未被量化。

### 研究问题（RQ）
- **RQ1（C1）**：在同一块 Zynq-7020、同一 kernel、同一工具链下，可编程 overlay 相比 HLS 固定加速器，**资源占用、时延/吞吐、功耗/能耗** 的差距是多少？
- **RQ2（C1）**：随 kernel 集合从 1 个增大到 N 个，overlay（一份硬件跑多 kernel）相对"每 kernel 一份 HLS 加速器"的**总资源/总重配置开销**优势如何变化？
- **RQ3（C3）**：在 ARM PS + AXI + PL overlay 的真实 SoC 上，kernel 派发、内存一致性、runtime 开销占端到端时延的比例是多少？哪些集成选择最影响性能？
- **RQ4（C3）**：DSAGEN 的 RISC-V/gem5 假设迁移到 ARM host 时，需要哪些适配？是否可形成可复用的集成 recipe？

### 假设（可证伪）
- **H1**：overlay 的单 kernel 峰值性能低于同 kernel 的 HLS 固定加速器（预期 0.4–0.9×）。
- **H2**：但 overlay 的"编译+重配置时间"低 2–4 个数量级（呼应 OverGen 的 10000× 主张）。
- **H3**：当 kernel 数 ≥ 3 时，overlay 的**总资源占用**（一份硬件 + 软切换）优于 HLS 的"一 kernel 一硬件"方案。
- **H4**：端到端时延中，AXI/驱动的**派发与数据传输开销**在小 kernel 上占比显著（>30%）。

---

## 2. 实验平台与工具

| 项 | 选型 |
|---|---|
| FPGA 板 | **Zynq-7020**（主）；7010 仅冒烟 |
| 工具链 | Vivado + Vitis HLS（固定加速器基线）；本仓库 RTL 骨架（overlay 侧） |
| 软件栈 | PetaLinux（Linux 用户态驱动）或裸机（Xilinx Standalone） |
| 功耗测量 | 板载 PMBus / INA 电流监测，或外接功率计；固定采样率，取稳态区间 |
| 仿真 | iverilog/Verilator（RTL TB）、gem5（DSAGEN 上游流程） |

---

## 3. 变量设计

### 自变量（IV）
| 变量 | 取值 |
|---|---|
| **实现方式** | ① Overlay（可编程，本仓库）② HLS 固定加速器（Vitis HLS） |
| **Kernel** | GEMM、stencil、SpMV（稀疏向量乘）、（可选）卷积 |
| **规模** | 问题尺寸（N=64/128/256）、PE 阵列规模（4×4/8×8/16×16）、位宽（int8/int16/fixed32） |
| **调度** | 单 kernel vs 多 kernel 时分复用 |

### 因变量（DV）
| 类别 | 指标 |
|---|---|
| 资源 | LUT、FF、DSP、BRAM、URAM 占用与利用率 |
| 性能 | 时延（cycles / ms）、吞吐（GOPS）、加速比（vs ARM 纯软件） |
| 能效 | 动态功耗（W）、能耗（mJ/op）、能耗延迟积（EDP） |
| 时间成本 | 综合/实现时间、bitstream 重配置时间、kernel 切换时间 |
| 开销分解 | 计算 / 数据传输 / 派发（launch+drain）各占比 |
| 可编程性 | 支持 kernel 数、切换粒度 |

### 控制变量
- 同一块 7020、同一 Vivado 版本、同一时钟频率（如 100 MHz）、同一电源状态。
- 同一输入数据分布与规模；同一功耗采样流程与稳态判据。
- ARM 侧关闭无关后台进程；CPU 频率锁定（governor=performance）。

---

## 4. 基线（Baselines）

| 基线 | 说明 | 对照目的 |
|---|---|---|
| **B1: HLS 固定加速器** | Vitis HLS 生成，逐 kernel 一份 | 主对照（C1） |
| **B2: ARM 纯软件** | Cortex-A9 上优化 C 实现 | 加速比基准 |
| **B3: AutoDSE（可选）** | 若可复现上游 DSE-HLS 流程 | 对齐 OverGen 的对比对象 |
| **B4: 上游 DSAGEN/OverGen 仿真** | gem5/RTL 仿真结果 | 与实测交叉验证 |

> B1 与 overlay 必须用**同一 kernel、同一问题规模**，并记录各自综合脚本以公开可复现。

---

## 5. 测量方法

1. **性能**：PL 侧内置 cycle counter（见 `rtl/overlay_regs.vh` 的 `PERF_CYCLES`）；ARM 侧用 `clock_gettime(CLOCK_MONOTONIC)` 测端到端。
2. **开销分解**：ARM 计时围绕 (a) 数据搬运、(b) 寄存器派发、(c) PL 执行、(d) 回读，逐段打点。
3. **功耗**：稳态区间采样 ≥ 5 s，重复 ≥ 10 次取中位数；报告均值±标准差。基线为"空载可编程逻辑"功耗。
4. **重配置时间**：完整 bitstream 加载计时；若支持部分重配置（DFX），单独测 PR 加载。
5. **可复现**：所有 TCL/Makefile/脚本入库；固定种子与数据生成器。

---

## 6. 实验流程

```
阶段A 单 kernel 受控对照（C1 主体）
  A1 选 3 个 kernel，各实现 overlay + HLS 两版
  A2 同板、同频、同规模，测资源/时延/功耗
  A3 汇总 → RQ1/H1 结论图

阶段B 多 kernel 复用（C1 的 RQ2）
  B1 固定 kernel 集合 {1,2,3,4}
  B2 对比：1 份 overlay(软切换) vs N 份 HLS(硬切换)
  B3 测总资源、总重配置时间、切换开销 → RQ2/H3

阶段C SoC 集成与开销分解（C3）
  C1 部署 overlay 到 PS+PL，跑通端到端
  C2 开销分解（搬运/派发/执行/回读）
  C3 对比集成方案：轮询 vs 中断、小/大传输粒度 → RQ3/RQ4/H4

阶段D 交叉验证（可选）
  D1 gem5/RTL 仿真 vs 实测
```

---

## 7. 预期图表

| 图 | 内容 | 支撑 |
|---|---|---|
| Fig.1 | 系统框图：ARM PS + AXI + PL overlay + scratchpad | C3 |
| Fig.2 | **资源占用柱状图**（overlay vs HLS：LUT/DSP/BRAM） | C1/RQ1 |
| Fig.3 | **性能-能效散点**（加速比 vs 能耗，两实现叠加） | C1/H1 |
| Fig.4 | **编译/重配置时间对数柱状图**（期望 2–4 数量级差） | C1/H2 |
| Fig.5 | **多 kernel 总资源 vs kernel 数**（overlay 平坦 vs HLS 线性增长） | C1/H3 |
| Fig.6 | **端到端时延堆叠条**（搬运/派发/执行/回读占比） | C3/H4 |
| Fig.7（可选） | 可行性边界曲线（fabric 规模 vs 性能/资源） | C2 |

---

## 8. 有效性威胁（Threats to Validity）

| 类型 | 威胁 | 缓解 |
|---|---|---|
| 内部 | 功耗测量受温度/后台干扰 | 稳态采样、重复取中位数、锁频、控制环境 |
| 构造 | overlay 实现未充分优化，低估其性能 | 用 DSAGEN 生成或经 DSE 调优的配置；公开脚本 |
| 外部 | 7020 器件小，结论未必外推到大数据中心 | 明确定位为"资源受限商用器件"；KU3P 做后续外推 |
| 结论 | 与 AutoDSE 对比不公平 | 同时报告"对其默认"与"其手工调优"两种口径 |

---

## 9. 里程碑

| 里程碑 | 产出 |
|---|---|
| M1 | 骨架跑通（RTL TB + host 驱动 + Vivado 工程） |
| M2 | 1 个 kernel 的 overlay 与 HLS 双实现，实测数据 |
| M3 | 3 kernel 受控对照 + Fig.2/3/4 |
| M4 | 多 kernel 复用实验 + Fig.5 |
| M5 | SoC 开销分解 + Fig.6 |
| M6 | 论文/报告草稿 + 开源仓库整理 |

---

## 10. 交付物
- 本仓库：RTL 骨架、host 驱动、Vivado/HLS 脚本、测量脚本、数据与图表。
- 技术报告 / 论文草稿。
- （可选）对 PolyArch/dsa-framework 的集成适配 PR（C3/C5）。
