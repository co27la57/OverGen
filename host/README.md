# host —— ARM 用户态驱动与示例

## 文件

| 文件 | 说明 |
|---|---|
| `overlay_driver.h/.c` | `/dev/mem` + `mmap` 访问 overlay 寄存器；`overlay_run_gemm()` 派发接口 |
| `gemm_demo.c` | 调用 overlay 完成 4x4x4 GEMM 并与软件参考比对 |
| `Makefile` | 本地 / 交叉编译 |

## 编译

```bash
# 本地语法检查
make

# 交叉编译到 Zynq ARM（按你的工具链前缀）
make CROSS=arm-linux-gnueabihf-
```

产物：`gemm_demo`（静态链接，便于直接拷贝到板子）。

## 部署与运行（Zynq 上）

```bash
# 1) 拷贝到板子
scp gemm_demo root@<board-ip>:/root/

# 2) 板子上需有 overlay 的 bitstream（通过 FPGA manager 或 devicetree overlay 加载）
#    例如：echo overlay.bit > /sys/class/fpga_manager/fpga0/firmware   （依平台而定）

# 3) 运行（基地址需与 Vivado Address Editor 一致）
./gemm_demo 0x43C00000
```

期望输出：`==== DEMO PASSED ====`。

## 注意

- 需要 root 权限（`/dev/mem`）；也可改用 **UIO** 或内核驱动以获得更安全/更快的访问。
- `DEFAULT_BASE`（0x43C00000）与 `scripts/create_project.tcl` 中分配到的地址必须一致。
- 本骨架用寄存器逐字搬运数据；真实设计中数据应经 **AXI4/DMA** 从 DDR 批量搬运，并测开销分解（研究计划 C3）。
