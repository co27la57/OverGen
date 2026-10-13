# 02 · 论文线梳理：PolyArch 的可编程空间加速器之路

按**时间顺序**（即思想演进脉络）排列。

---

## 1. Stream-Dataflow Acceleration（ISCA 2017）
**作者**：Tony Nowatzki, Vinay Gangadhar, Newsha Ardalani, Karthikeyan Sankaralingam（UCLA + UW-Madison）

- **问题**：专用加速器高效但缺通用性，CPU/GPU 通用但能耗高 —— 能否**不写专用硬件就获得专用级效率**？
- **方法**：提出 **stream-dataflow** 软硬件接口。洞察"可加速算法"的共性（高计算强度、长相位、简单控制流、流式访存）。**dataflow 部分**提供高并发，**stream 部分**以极低功耗/面积做通信与协调。实现名 **Softbrain**（CGRA 类可重构架构）。
- **结果**：对比专用加速器 DianNao 与 MachSuite 中的固定功能加速器，性能相当，平均仅多 **2× 功耗**。
- **定位**：整个系列的**理论起点**，"解耦式空间架构"思想的雏形。

## 2. Towards General Purpose Acceleration by Exploiting Common Data-Dependence Forms（MICRO 2019）
**作者**：Vidushi Dadu, Jian Weng, Sihao Liu, Tony Nowatzki（UCLA）

- **问题**：上述加速器遇到**数据依赖**（数据相关控制 / 访存）就失效（GPU 也搞不定稀疏/不规则）。
- **方法**：归纳两类"常见且可被专用硬件利用"的依赖形式 —— **stream-join**（受限控制依赖）与 **alias-free indirection**（受限访存依赖），据此设计 **SPU（Sparse Processing Unit）**：用"可计算暂存器"支持无别名间接访存 + 激进流重排，用新型数据流控制模型支持流连接。
- **结果**：ML / 数据库 / 图算法上分别达 24 核 CPU 的 **16.5× / 10.3× / 14.2×**；ML 上对比同等 GPGPU **1.8–7×**，面积与功耗更低。
- **荣誉**：IEEE Micro Top Picks 2020。
- **定位**：把"通用加速"扩展到**不规则/稀疏**领域。

## 3. DSAGEN: Synthesizing Programmable Spatial Accelerators（ISCA 2020）
**作者**：Jian Weng, Sihao Liu, Vidushi Dadu, Zhengrong Wang, Preyas Shah, Tony Nowatzki（UCLA）

- **问题**：前面都是"手工设计"加速器，成本高、难复用。能否**自动生成**可编程空间加速器？
- **方法**：核心洞察 —— 许多已有加速器可由**少量空间架构原语**组合近似。编译器理解原语，用模块化、可组合的转换适配程序；再在设计空间中搜索。构建 **DSAGEN 框架**，自动化"软硬协同设计"。
- **结果**：对多个已有加速器，编译器达手工调优的 **89%** 性能；自动 DSE 生成的硬件，相对已有可编程加速器平均 **1.3× perf²/mm²**。
- **荣誉**：IEEE Micro Honorable Mentions 2021。
- **定位**：**本教程框架的命名来源与核心论文** —— 从"手工设计"走向"自动合成"。

## 4. A Hybrid Systolic-Dataflow Architecture for Inductive Matrix Algorithms（HPCA 2020）
**作者**：Jian Weng, Sihao Liu, Zhengrong Wang, Vidushi Dadu, Tony Nowatzki（UCLA）

- **问题**：稠密线性代数（QR、SVD、Cholesky、求解器，5G 无线关键）多为**归纳性算法**，依赖距离/复用率/访存模式随迭代变化，CPU/DSP/GPU 远低于峰值。
- **方法**：提出 **inductive dataflow（归纳式数据流）**，把"归纳依赖"与"访存流"作为一等原语；设计混合空间架构 **REVEL**（Reconfigurable Vector Lanes），融合 systolic 与 tagged-dataflow，用向量-流控制模型摊薄控制开销。
- **结果**：超同等配置 DSP **4.6–37×**，超前沿空间架构平均 **3.4×**，功耗为 ASIC 集合的 **2×**、面积其一半。
- **定位**：针对**归纳式矩阵算法**的专用架构实例。

## 5. OverGen: Improving FPGA Usability through Domain-specific Overlay Generation（MICRO 2022）
**作者**：Sihao Liu\*, Jian Weng\*, Dylan Kupsh, Atefeh Sohrabizadeh, Zhengrong Wang, Licheng Guo, Jiuyang Liu, Maxim Zhulin, Rishabh Mani, Lucheng Zhang, Jason Cong, Tony Nowatzki（UCLA + 中科院等）

- **问题**：FPGA 上主流 HLS 编译快但下游物理综合要**数小时到数天**、重配置慢、不考虑跨负载灵活性；Overlay 灵活但抽象间隙导致效率低。
- **方法**：构建 **OverGen** —— 面向"高度可定制 Overlay"的硬件生成框架，把设计实例针对应用调优以缩小抽象间隙；整合可定制空间架构、SoC 生成、加速器编译器、DSE。新技术解决片上存储与 PE 间的低效网络，并减少 DSE 重编译量。
- **结果**：对比前沿 DSE-HLS 框架 AutoDSE，无 kernel 调优时几何平均 **1.2×**，即便基线手工调优仍有 **0.55×**，同时提供运行时跨负载灵活性；编译/重配置时间少 **~10000×**；**已被报道 "Verified on FPGA"**。
- **荣誉**：**MICRO 2022 Best Paper Runner-Up**。
- **定位**：把整套思路**落地到 FPGA Overlay**，是本方向的近期集大成之作。

---

## 演进主线

> **Stream-Dataflow（思想起点，2017）→ SPU（扩展到不规则/稀疏，2019）→ DSAGEN（自动合成框架，2020）→ REVEL（归纳式矩阵架构实例，2020）→ OverGen（FPGA Overlay 落地，2022）**

核心一脉相承：**用"可组合的空间架构原语 + 编译器自动搜索"兼得专用加速器的效率与可编程性**。
