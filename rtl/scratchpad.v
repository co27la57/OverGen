// scratchpad.v
// -----------------------------------------------------------------------------
// 双端口 scratchpad（片上 BRAM 模型）。
//  - AXI 侧端口：Host 通过驱动加载/回读数据。
//  - Fabric 侧端口：空间 fabric 读取 A/B、写回 C。
// 两侧均为"异步读"（组合读），以简化骨架控制逻辑；真实设计可改为同步读 + 流水线。
// -----------------------------------------------------------------------------
`default_nettype none

module scratchpad #(
  parameter WORDS  = 64,       // 字数
  parameter AW     = 6,        // 字地址位宽
  parameter DATA_W = 32
)(
  input  wire                clk,
  // ---- AXI 侧端口 ----
  input  wire                axi_we,
  input  wire [AW-1:0]       axi_waddr,
  input  wire [DATA_W-1:0]   axi_wdata,
  input  wire [AW-1:0]       axi_raddr,
  output wire [DATA_W-1:0]   axi_rdata,
  // ---- Fabric 侧端口 ----
  input  wire                f_we,
  input  wire [AW-1:0]       f_waddr,
  input  wire [DATA_W-1:0]   f_wdata,
  input  wire [AW-1:0]       f_raddr,
  output wire [DATA_W-1:0]   f_rdata
);

  reg [DATA_W-1:0] mem [0:WORDS-1];

  // 异步（组合）读：简化 FSM，避免显式 read latency 处理。
  assign axi_rdata = mem[axi_raddr];
  assign f_rdata   = mem[f_raddr];

  always @(posedge clk) begin
    if (axi_we) mem[axi_waddr] <= axi_wdata;
    if (f_we)   mem[f_waddr]   <= f_wdata;
  end

endmodule

`default_nettype wire
