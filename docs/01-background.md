# 01 · 背景：DSA 与 DSAGEN 框架

## 1. DSA 是什么（三义）

在本项目语境下，**DSA** 对应三个相互关联的概念：

1. **Domain-Specific Accelerator（领域专用加速器）** —— 研究**目标产物**。为某一类应用（矩阵运算、深度学习、图像处理等）定制的硬件，相比通用 CPU/GPU 性能更高、能耗更低。痛点是软硬件均需人工深度定制，算法一变就要重做。

2. **Decoupled Spatial Architecture（解耦式空间架构）** —— 框架提出的**设计方法论**，也是框架名字（DSA Framework）的来源。
   - **Spatial（空间）**：用大量并行计算单元 + 互连网络做数据流处理（类似 systolic array）。
   - **Decoupled（解耦）**：把控制流与数据流解耦，用流处理机制处理数据依赖，兼顾专用性与可编程性。

3. **DSAGEN** —— 把上述理念落地的**研究基础设施**，包含编译、仿真、RTL 生成、设计空间探索，目标是"像 HLS 一样，但面向可编程加速器"。

> 一句话：DSA 既是"领域专用加速器"（产物），也是"解耦式空间架构"（方法）；DSAGEN 是自动生成这类加速器的工具链。

## 2. DSAGEN 框架（来自 MICRO 2022 Tutorial）

### 动机
随着晶体管 Scaling 放缓，专用加速器（DSA）因高性能、低功耗受关注，但需要大量软硬件工程，且每次新领域/新算法都要重做。理想目标是 **programmable accelerator synthesis（可编程加速器综合）**：
- 自动化（automatable）
- 深度专用化（deep specialization）
- 统一编程接口（uniform programming interface）

### 三大能力（框架栈）

1. **编译（Compilation）**
   - 用 **pragma 注解** + clang 解析 + LLVM pass 编码数据访问
   - **Spatial Mapper** 算法：完成解耦式计算与可视化
   - 生成汇编并与 `gnu-riscv-gcc` 链接
   - 用 **gem5** 仿真 RISC-V 二进制

2. **硬件构建（Hardware）**
   - 引入 **Architecture Description Graph（ADG, 架构描述图）** 概念
   - 设计空间与微架构 DSA；把设计导出为 ADG，在 RTL 级仿真
   - 解析式 **Power/Performance/Area（PPA）** 建模
   - 用 DSL 组合新算子与拓扑

3. **自动设计空间探索（DSE）**
   - 从一组程序端到端自动生成加速器
   - 在 PPA 之间做权衡搜索

### 关键洞察
> 许多已有加速器架构都可以由**少量空间架构硬件原语**组合近似出来。编译器理解这些原语，用**模块化、可组合的转换**适配给定程序特征；加速器则通过在这片丰富的设计空间中搜索来生成。

### 教程安排（MICRO 2022, 4 小时）
- Introduction（30min）：Decoupled-Spatial 编程范式、用原语组合硬件、框架栈
- Basic Programming（60min）：编译流程，改 pragma / 看空间映射 / gem5 仿真
- Build your own DSA（60min）：ADG 概念，用 DSL 组更大 ADG，看 PPA 差异
- Automatic DSE（40min）：DSE 端到端，测性能，可视化 DSE 过程

### 安装
```bash
git clone https://github.com/PolyArch/dsa-framework.git
cd dsa-framework
docker build .
# 然后按 Setup 页继续
```
依赖：Docker（Ubuntu 上安装），内部含 Chisel + gem5 + LLVM 工具链。
