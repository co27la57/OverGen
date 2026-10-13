# =============================================================================
# create_project.tcl —— 建立 Zynq-7020 + overlay 的 Vivado 工程与 Block Design
#
# 用法：  vivado -mode batch -source scripts/create_project.tcl
#
# 注意：
#   * part / board_part 需按你的板卡修改（见下方 part 变量）。
#   * 本脚本是"骨架起始点"：overlay_top 以 module reference 方式加入，
#     Vivado 会依据 AXI 端口命名（s_axi_*）自动推断 AXI4-Lite 接口。
#     若你的 Vivado 版本未成功推断接口，请改为将 overlay_top 打包为 IP
#     （见 scripts/README.md 的"IP 打包"小节）。
#   * 运行后在 Address Editor 中确认 overlay_0 的基地址（默认常为 0x43C00000），
#     该地址需与 host/gemm_demo.c 的 DEFAULT_BASE 一致。
# =============================================================================

set proj_name "overlay_7020"
set proj_dir  "./vivado_proj"
set part      "xc7z020clg400-1"       ;# Pynq-Z2 / Arty Z7-20：clg400；ZedBoard：clg484

create_project $proj_name $proj_dir -part $part -force
set_property target_language Verilog [current_project]

# ------------------------------------------------------------------ 源文件
add_files -norecurse [glob ./rtl/*.v]
set_property include_dirs [file normalize ./rtl] [current_fileset]
add_files -fileset constrs_1 -norecurse [glob ./constraints/*.xdc]
update_compile_order -fileset sources_1

# ------------------------------------------------------------------ Block Design
create_bd_design "system"

# --- PS7 ---
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
set_property -dict [list \
  CONFIG.PCW_USE_M_AXI_GP0 {1} \
  CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
] [get_bd_cells ps7]

# --- AXI 互连（1 master -> 1 slave）---
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_smc
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_smc]

# --- 复位生成 ---
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_gen

# --- overlay 模块引用 ---
create_bd_cell -type module -reference overlay_top overlay_0

# ------------------------------------------------------------------ 连接
connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0]   [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins overlay_0/s_axi]

connect_bd_net [get_bd_pins ps7/FCLK_CLK0] \
  [get_bd_pins axi_smc/ACLK] [get_bd_pins axi_smc/S00_ACLK] [get_bd_pins axi_smc/M00_ACLK] \
  [get_bd_pins rst_gen/slowest_sync_clk] [get_bd_pins overlay_0/clk]

connect_bd_net [get_bd_pins rst_gen/peripheral_aresetn] \
  [get_bd_pins axi_smc/ARESETN] [get_bd_pins axi_smc/S00_ARESETN] [get_bd_pins axi_smc/M00_ARESETN] \
  [get_bd_pins overlay_0/rst_n]

connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins rst_gen/ext_reset_in]

# --- 外部端口（DDR / FIXED_IO）---
make_bd_intf_pins_external [get_bd_intf_pins ps7/DDR]
make_bd_intf_pins_external [get_bd_intf_pins ps7/FIXED_IO]
set_property name DDR      [get_bd_intf_ports DDR_0]
set_property name FIXED_IO [get_bd_intf_ports FIXED_IO_0]

# --- 地址分配 ---
assign_bd_address [get_bd_addr_segs {overlay_0/s_axi/reg0}]
set overlay_addr [get_property OFFSET [get_bd_addr_segs {ps7/Data/SEG_overlay_0_reg0}]]
puts "==== overlay_0 AXI 基地址 = $overlay_addr ===="

save_bd_design
validate_bd_design
generate_target all [get_files system.bd]

# ------------------------------------------------------------------ 顶层 wrapper
make_wrapper -files [get_files system.bd] -top
add_files -norecurse [glob "$proj_dir/$proj_name.gen/sources_1/bd/system/hdl/system_wrapper.v"]
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "==== 工程已建立: $proj_dir/$proj_name.xpr ===="
puts "==== 下一步: 综合 -> 实现 -> 生成 bitstream -> 导出 XSA ===="
