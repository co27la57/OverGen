# scripts —— 仿真与构建脚本

| 脚本 | 说明 |
|---|---|
| `sim.sh` | 用 Verilator 编译并运行 RTL testbench |
| `create_project.tcl` | 建立 Zynq-7020 的 Vivado 工程与 Block Design |

## 仿真

```bash
scripts/sim.sh
```

## 建立 Vivado 工程

```bash
vivado -mode batch -source scripts/create_project.tcl
```

要点：
- 修改 `part` 为你的板卡型号（Pynq-Z2 / Arty Z7-20: `xc7z020clg400-1`；ZedBoard: `xc7z020clg484-1`）。
- 运行后在 **Address Editor** 中确认 `overlay_0` 的基地址，并与 `host/gemm_demo.c` 的 `DEFAULT_BASE` 对齐。
- 综合 → 实现 → 生成 bitstream → 导出 XSA（供 PetaLinux/裸机使用）。

## 若 Vivado 未自动推断 AXI 接口（IP 打包方案）

`create_project.tcl` 以 module reference 引入 `overlay_top`，依赖端口命名推断 AXI4-Lite 接口。
若推断失败，可改为打包为 IP：

```tcl
create_project -in_memory -part xc7z020clg400-1
add_files [glob ./rtl/*.v]
set_property top overlay_top [current_fileset]
update_compile_order -fileset sources_1
ipx::package_project -root_dir ./vivado_proj/ip_repo -vendor user -library user \
    -taxonomy /UserIP -import_files -set_current true
ipx::infer_bus_interface s_axi_awaddr xilinx.com:interface:aximm_rtl:1.0 [ipx::current_core]
# （对 s_axi 的其余信号重复 infer，或使用 ipx::infer_bus_interfaces 一次性推断）
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
```

随后在 Block Design 中用 `create_bd_cell -type ip -vlnv user:user:overlay_top:1.0 ...` 实例化。
