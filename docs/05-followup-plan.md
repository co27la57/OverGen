# 05 · 基于 Zynq-7020 的 follow-up 路线图

## 大前提：真实空白在哪
OverGen 已被报道 **"Verified on FPGA"**，所以**单纯移植上板不算新贡献**。真正的空白：

1. 同一块板上，可编程 overlay vs HLS 固定加速器的**实测 PPA / 功耗**对照（原工作多为建模/仿真或框架级对比）。
2. 资源受限器件上的 overlay **可行性与效率边界**。
3. 面向 **ARM PS + PL overlay** 的真实 SoC 集成方案（AXI、runtime、内存模型）。
4. 真实**重配置/时分复用成本**实证（校验 ~10000× 主张）。
5. **工具链轻量化与可复现性**（对上游开源贡献）。
6. （进阶）**新负载域 / 新原语**的泛化验证。

## 硬件角色分配
| 板卡 | 角色 |
|---|---|
| Zynq-7010 | 流程冒烟测试（太小，放不下大 overlay） |
| **Zynq-7020** | **主力**：PS 双核 Cortex-A9 跑 Linux，PL 放 overlay，AXI 驱动 |
| KU3P | 后续放大（大 fabric）；**无硬核 ARM**，需 MicroBlaze 或外挂主机 |

---

## 分阶段路线图

### 阶段 0（1–2 周）复现流程
- `git clone https://github.com/PolyArch/dsa-framework.git`，Docker 构建。
- 跑 Tutorial 的 hands-on：改 pragma → 看 spatial mapping 可视化 → gem5 仿真看性能差。
- **目标**：在仿真层把全栈（编译/映射/DSE/仿真）跑通。

### 阶段 1（2–4 周）小 kernel 真实落地 7020 ★
- 选干净的小 kernel（矩阵乘 / stencil / 稀疏向量乘）。
- 用 DSAGEN 生成的 RTL 或手搭简化空间 fabric，例化到 **7020**。
- 写 ARM host（裸机或 PetaLinux），经 AXI 派发 kernel、回收结果，**实测**资源与加速比。
- 本仓库 `rtl/`、`host/` 提供起步骨架。

### 阶段 2（2–3 周）同板对比 HLS ★
- 同一 kernel 用 Vivado HLS 做成**固定功能加速器**也跑在 7020。
- 对比：overlay（可编程）vs HLS（固定）的真实 LUT/DSP/BRAM、时延、功耗。→ 核心贡献图。

### 阶段 3（放大）上 KU3P
- 用大 fabric 放更大 overlay 或多 kernel。
- 若支持部分重配置，实测 kernel 切换开销，验证"万倍重配时间"卖点。

### 阶段 4（创新）延伸
- 接新域（FHE / LLM / 自选课题）、加新原语、或工具链轻量化，形成可投产出。

---

## 必须提前知道的坑
- **RISC-V vs ARM host**：DSAGEN 用 RISC-V 二进制 + gem5；上 Zynq 大概率在 **Cortex-A9** 上跑控制（或 PL 放 RISC-V 软核），移植步骤要算进排期。
- **7010 太小**：仅流程验证。
- **代码库是科研级**：环境踩坑会花时间，阶段 0 预留缓冲。
- **KU3P 无硬核**：早定 MicroBlaze 还是外挂主机，免得返工。
