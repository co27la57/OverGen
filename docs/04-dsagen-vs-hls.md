# 04 · DSAGEN 相对 HLS 的优势

核心分水岭：**HLS 生成的是"固定功能"加速器，DSAGEN 生成的是"可编程"空间加速器。**

---

## 1. 可编程性：生成"可编程"而非"固定功能"硬件（最核心）
DSAGEN 原文：
> "Automated ASIC generation (e.g. HLS) can be insufficient, because the hardware becomes **inflexible**."

- **HLS**：把 C+pragma 综合成**专用固定电路**，一次为一个任务定制，改算法就得重综合。
- **DSAGEN**：生成**可编程空间加速器**，保持**统一编程接口**，同一硬件能跑一个领域内的多个 kernel。

理想框架三要素 —— automatable / deep specialization / uniform programming interface —— HLS 在"灵活性"上失败，DSAGEN 三者兼得。

## 2. 自动软硬件协同设计 + 设计空间探索（DSE）
- **HLS**：本质是一次性"语言→电路"翻译，基本不做面向负载的设计空间搜索，也不考虑跨负载灵活性。
- **DSAGEN**：编译器同时分析多个 kernel，基于"程序对硬件原语的亲和度"在设计空间中搜索，自动产出优化 kernel + 加速器 RTL。
- **实测**：编译器达手调版本 **89%** 性能；自动 DSE 生成硬件平均 **1.3× perf²/mm²**。

## 3. 跨负载灵活性 / 可时分复用
- HLS 物理综合下游要**数小时到数天**，FPGA 重配置慢，**无法高效时分复用**。
- OverGen 验证：相比 DSE-HLS 框架 AutoDSE，编译与重配置时间减少约 **10000×**，并提供**运行时跨负载灵活性**。
- 含义：固定功能加速器不能时间共享，可编程加速器可以 → 硅面积利用率与适用面更好。

## 4. 基于"可组合硬件原语"的复用性
> "many prior accelerator architectures can be approximated by composing a **small number of hardware primitives** ... with **modular and composable transformations**."

用少量空间原语 + 模块化转换描述加速器，新架构可**组合复用**而非从零手写，降低成本并便于专用化。

---

## 诚实补充：二者并非纯粹对立
- OverGen 本身"利用并扩展了可定制空间架构、SoC 生成、加速器编译器"等既有技术；DSAGEN 也借鉴 HLS 的 pragma 注解式编程接口。
- 更准确地说：
  > **HLS 擅长把单程序快速变成固定电路；DSAGEN 擅长自动合成"既能专用、又能编程"的可重构加速器，并通过 DSE 在 PPA 上做全局优化。**

## 选型建议
- 场景："同一算法反复改 / 多种负载切换" → DSAGEN 类可编程合成框架优势明显。
- 场景："单算法固化部署、不计重编译成本" → HLS 仍最直接。
