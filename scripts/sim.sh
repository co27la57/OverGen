#!/usr/bin/env bash
# sim.sh —— 用 Verilator 编译并运行 RTL testbench
# 依赖：verilator >= 5.0（支持 --binary --timing）
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build/sim

echo "== 编译 RTL + testbench =="
verilator --binary --timing -Wno-fatal --top-module tb_overlay_top -Irtl \
  --Mdir build/sim \
  tb/tb_overlay_top.v \
  rtl/overlay_top.v rtl/overlay_ctrl.v rtl/fabric.v rtl/scratchpad.v

echo "== 运行仿真 =="
./build/sim/Vtb_overlay_top
