# 03 · 相关人物与研究方向

## Tony Nowatzki（UCLA）
- PolyArch Research Group 负责人，DSAGEN/OverGen 系列工作（含 REVEL、SPU、Stream-Dataflow）的导师/通讯作者。
- 方向：可编程空间加速器、加速器综合与编译、DSA 设计空间探索。

## Jian Weng 翁健（KAUST，助理教授）★重点关注
- **主页**：https://were.github.io
- **职位**：KAUST 计算机科学系 Assistant Professor；领导 **Synthesys Lab**（CEMSE Division）。
- **背景**：2023 年 UCLA 计算机科学 PhD，导师 Tony Nowatzki（即上述系列）。
- **荣誉**：IEEE Micro Top Picks 提名、MICRO Best Paper Runner-Up。

### 官方研究兴趣（Bio 原文意译）
> **全栈计算系统的设计与实现（full-stack computing systems' design and implementation）**，包括但不限于：
> 1. **设计与分析加速器（accelerators）**
> 2. **加速器配套软件栈（software stacks）** —— 即编译器
> 3. **挖掘现有器件的潜力（exploiting the potentials of existing devices）**

### 除"可编程加速器"外的扩展方向（来自其最新论文）

| 方向 | 代表工作 |
|---|---|
| AI / 大模型加速（LLM、VLM） | `AQuant`（把视频 CODEC 重用于 VLM 加速，ISCA'26）、`MLX`（空间架构上结构化 LLM 负载加速，ISCA'26 最佳论文候选） |
| 隐私计算 / 全同态加密（FHE） | `Hierarchical Exploitation of Memory Efficiency for GPU-Based FHE Acceleration`（ISCA'26） |
| 存内计算（PIM） | `PIMSAB`：空间感知通信 + 位串行计算的 PIM 系统（TACO'24） |
| 近缓存 / 近数据流加速 | `Near-Stream Computing`（HPCA'22）、`Stream Floating`（HPCA'21 最佳论文 Runner-Up） |
| 架构综合 / 统一编译 | `Assassyn`（架构综合与仿真统一框架，ISCA'25）、`UNIT`（张量化指令统一编译，CGO'21）、`DAEGEN`（CAL'19） |
| "废物利用"式器件改造 | 如把现成 CODEC 硬件重用于 AI 推理（AQuant），即 "exploiting existing devices" |

### 对本项目的启示
- 若做 follow-up，可考虑把方向**接到他当前兴趣**（LLM/VLM、FHE、PIM），既 follow-up 又更具前瞻性，甚至有机会联系/推荐。
- `Assassyn`（ISCA'25）是他新做的**统一综合+仿真框架**，可作为比 DSAGEN 更现代的上游基础，值得调研。
