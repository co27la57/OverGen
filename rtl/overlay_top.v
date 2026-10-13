// overlay_top.v
// -----------------------------------------------------------------------------
// 顶层：把 AXI4-Lite 控制器、scratchpad、空间 fabric 连接起来。
// 这是接入 Zynq PS + AXI Interconnect 的顶层 AXI4-Lite 从设备。
//
//   PS(ARM) ──AXI4-Lite──> overlay_top ──> scratchpad(A/B/C)
//                                      └─> fabric (TILE x TILE MAC)
// -----------------------------------------------------------------------------
`default_nettype none

module overlay_top #(
  parameter TILE     = 4,
  parameter W        = 16,
  parameter SCR_WORDS= 64,
  parameter AW       = 6,
  parameter ADDR_W   = 6,
  parameter DATA_W   = 32
)(
  input  wire               clk,        // AXI 时钟（与 PS FCLK 同步）
  input  wire               rst_n,

  // AXI4-Lite 从机
  input  wire [ADDR_W-1:0]  s_axi_awaddr,
  input  wire               s_axi_awvalid,
  output wire               s_axi_awready,
  input  wire [DATA_W-1:0]  s_axi_wdata,
  input  wire [DATA_W/8-1:0] s_axi_wstrb,
  input  wire               s_axi_wvalid,
  output wire               s_axi_wready,
  output wire [1:0]         s_axi_bresp,
  output wire               s_axi_bvalid,
  input  wire               s_axi_bready,
  input  wire [ADDR_W-1:0]  s_axi_araddr,
  input  wire               s_axi_arvalid,
  output wire               s_axi_arready,
  output wire [DATA_W-1:0]  s_axi_rdata,
  output wire [1:0]         s_axi_rresp,
  output wire               s_axi_rvalid,
  input  wire               s_axi_rready
);

  // ctrl <-> scratchpad(AXI 侧)
  wire               scr_we;
  wire [AW-1:0]      scr_waddr;
  wire [DATA_W-1:0]  scr_wdata;
  wire [AW-1:0]      scr_raddr;
  wire [DATA_W-1:0]  scr_rdata;

  // ctrl <-> scratchpad(fabric 侧)
  wire               f_we;
  wire [AW-1:0]      f_waddr;
  wire [DATA_W-1:0]  f_wdata;
  wire [AW-1:0]      f_raddr;
  wire [DATA_W-1:0]  f_rdata;

  // ctrl <-> fabric
  wire               fab_clr, fab_en;
  wire               we_a, we_b;
  wire [$clog2(TILE)-1:0] waddr_a, waddr_b;
  wire [W-1:0]       wdata_a, wdata_b;
  wire [$clog2(TILE*TILE)-1:0] rd_idx;
  wire [2*W-1:0]     rd_acc;

  overlay_ctrl #(
    .TILE(TILE), .W(W), .AW(AW), .ADDR_W(ADDR_W), .DATA_W(DATA_W)
  ) u_ctrl (
    .clk(clk), .rst_n(rst_n),
    .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
    .scr_we(scr_we), .scr_waddr(scr_waddr), .scr_wdata(scr_wdata), .scr_raddr(scr_raddr), .scr_rdata(scr_rdata),
    .f_we(f_we), .f_waddr(f_waddr), .f_wdata(f_wdata), .f_raddr(f_raddr), .f_rdata(f_rdata),
    .fab_clr(fab_clr), .fab_en(fab_en),
    .we_a(we_a), .waddr_a(waddr_a), .wdata_a(wdata_a),
    .we_b(we_b), .waddr_b(waddr_b), .wdata_b(wdata_b),
    .rd_idx(rd_idx), .rd_acc(rd_acc)
  );

  scratchpad #(
    .WORDS(SCR_WORDS), .AW(AW), .DATA_W(DATA_W)
  ) u_scratch (
    .clk(clk),
    .axi_we(scr_we), .axi_waddr(scr_waddr), .axi_wdata(scr_wdata),
    .axi_raddr(scr_raddr), .axi_rdata(scr_rdata),
    .f_we(f_we), .f_waddr(f_waddr), .f_wdata(f_wdata),
    .f_raddr(f_raddr), .f_rdata(f_rdata)
  );

  fabric #(
    .TILE(TILE), .W(W)
  ) u_fabric (
    .clk(clk), .rst_n(rst_n), .clr(fab_clr), .en(fab_en),
    .we_a(we_a), .waddr_a(waddr_a), .wdata_a(wdata_a),
    .we_b(we_b), .waddr_b(waddr_b), .wdata_b(wdata_b),
    .rd_idx(rd_idx), .rd_acc(rd_acc)
  );

endmodule

`default_nettype wire
