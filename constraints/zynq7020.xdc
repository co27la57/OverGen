# =============================================================================
# zynq7020.xdc —— 约束（骨架）
#
# 说明：
#   * Block Design 流程下，overlay 的 clk / rst_n 由 PS(FCLK_CLK0 / proc_sys_reset)
#     驱动，无需在此约束顶层引脚；引脚约束由 BD 的 DDR / FIXED_IO 端口 + 板卡文件提供。
#   * 若把 overlay_top 独立综合（非 BD），clk 为顶层输入，下方条件约束会生效。
#   * 需要额外引脚约束时，请按你的板卡手册补充。
# =============================================================================

# 独立综合时的系统时钟（100 MHz）。BD 流程下顶层无 clk 端口，此行自动跳过。
if {[llength [get_ports -quiet clk]] > 0} {
    create_clock -period 10.000 -name sys_clk [get_ports clk]
    set_input_delay  -clock sys_clk -max 2.0 [get_ports {s_axi_*}] -quiet
    set_output_delay -clock sys_clk -max 2.0 [get_ports {s_axi_*}] -quiet
}

# 异步复位（无时序要求）
set_false_path -from [get_ports rst_n] -quiet
