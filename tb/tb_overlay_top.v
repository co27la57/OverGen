// tb_overlay_top.v
// -----------------------------------------------------------------------------
// 功能验证：用一个行为级 AXI4-Lite 主机，
//   1) 把 A、B 载入 scratchpad；
//   2) 配置 M/N/K 并启动 overlay；
//   3) 轮询 STATUS.done；
//   4) 回读 C 并与软件计算结果比对。
//   C[i][j] = sum_k A[i][k]*B[k][j]
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module tb_overlay_top;

  localparam TILE = 4, W = 16, AW = 6, ADDR_W = 6, DATA_W = 32;

  reg clk = 0, rst_n = 0;
  always #5 clk = ~clk;    // 100 MHz

  // ---- AXI4-Lite 信号 ----
  reg  [ADDR_W-1:0]   awaddr;
  reg                 awvalid;
  wire                awready;
  reg  [DATA_W-1:0]   wdata;
  reg  [DATA_W/8-1:0] wstrb;
  reg                 wvalid;
  wire                wready;
  wire [1:0]          bresp;
  wire                bvalid;
  reg                 bready;

  reg  [ADDR_W-1:0]   araddr;
  reg                 arvalid;
  wire                arready;
  wire [DATA_W-1:0]   rdata;
  wire [1:0]          rresp;
  wire                rvalid;
  reg                 rready;

  // ---- 寄存器字节地址 ----
  localparam CTRL      = 6'h00;
  localparam STATUS    = 6'h04;
  localparam DIM_M     = 6'h08;
  localparam DIM_N     = 6'h0C;
  localparam DIM_K     = 6'h10;
  localparam SCR_ADDR  = 6'h14;
  localparam SCR_WDATA = 6'h18;
  localparam SCR_RDATA = 6'h1C;
  localparam PERF      = 6'h20;

  // scratchpad 布局
  localparam A_BASE = 0;
  localparam B_BASE = 16;
  localparam C_BASE = 32;

  overlay_top #(.TILE(TILE), .W(W), .SCR_WORDS(64), .AW(AW),
                .ADDR_W(ADDR_W), .DATA_W(DATA_W)) dut (
    .clk(clk), .rst_n(rst_n),
    .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready)
  );

  // ---------------------------------------------------------------- AXI 主机任务
  task axi_write(input [ADDR_W-1:0] addr, input [DATA_W-1:0] data);
  begin
    @(posedge clk);
    awaddr <= addr; awvalid <= 1'b1;
    wdata  <= data; wstrb <= 4'hF; wvalid <= 1'b1;
    @(posedge clk);
    awvalid <= 1'b0; wvalid <= 1'b0;
    wait (bvalid === 1'b1);
    @(posedge clk);
    bready <= 1'b1;
    @(posedge clk);
    bready <= 1'b0;
  end
  endtask

  task axi_read(input [ADDR_W-1:0] addr, output [DATA_W-1:0] data);
  begin
    @(posedge clk);
    araddr <= addr; arvalid <= 1'b1;
    @(posedge clk);
    arvalid <= 1'b0;
    wait (rvalid === 1'b1);
    data = rdata;
    @(posedge clk);
    rready <= 1'b1;
    @(posedge clk);
    rready <= 1'b0;
  end
  endtask

  // ---------------------------------------------------------------- 数据与校验
  reg [31:0] a_mem [0:15];
  reg [31:0] b_mem [0:15];
  reg [31:0] exp_c [0:15];
  reg [31:0] rd, st;
  integer i, j, k, idx;
  integer errors;

  initial begin
    // 初始化
    clk=0; rst_n=0;
    awvalid=0; wvalid=0; awaddr=0; wdata=0; wstrb=0; bready=0;
    arvalid=0; araddr=0; rready=0;
    errors=0;

    // 构造 A、B（简单可区分的数据模式）
    for (i = 0; i < 16; i = i + 1) begin
      a_mem[i] = i + 1;          // A[i][k]
      b_mem[i] = 16 - i;         // B[k][j]
    end

    // 软件参考结果 C = A x B
    for (i = 0; i < TILE; i = i + 1) begin
      for (j = 0; j < TILE; j = j + 1) begin
        exp_c[i*TILE + j] = 0;
        for (k = 0; k < TILE; k = k + 1)
          exp_c[i*TILE + j] = exp_c[i*TILE + j] + a_mem[i*TILE+k] * b_mem[k*TILE+j];
      end
    end

    // 复位
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);

    // ---- 1) 载入 A ----
    for (idx = 0; idx < 16; idx = idx + 1) begin
      axi_write(SCR_ADDR,  A_BASE + idx);
      axi_write(SCR_WDATA, a_mem[idx]);
    end
    // ---- 2) 载入 B ----
    for (idx = 0; idx < 16; idx = idx + 1) begin
      axi_write(SCR_ADDR,  B_BASE + idx);
      axi_write(SCR_WDATA, b_mem[idx]);
    end

    // ---- 3) 配置并启动 ----
    axi_write(DIM_M, TILE);
    axi_write(DIM_N, TILE);
    axi_write(DIM_K, TILE);
    axi_write(CTRL,  32'h1);     // start

    // ---- 4) 轮询 done ----
    st = 0;
    for (idx = 0; idx < 200; idx = idx + 1) begin
      axi_read(STATUS, st);
      if (st[1]) idx = 200;      // done
    end
    if (!st[1]) begin
      $display("[FAIL] timeout waiting for done");
      errors = errors + 1;
    end

    axi_read(PERF, rd);
    $display("[INFO] perf_cycles = %0d", rd);

    // ---- 5) 回读 C 并比对 ----
    for (i = 0; i < 16; i = i + 1) begin
      axi_write(SCR_ADDR, C_BASE + i);
      axi_read (SCR_RDATA, rd);
      if (rd[15:0] !== exp_c[i][15:0]) begin
        $display("[MISMATCH] C[%0d] got=0x%h exp=0x%h", i, rd[15:0], exp_c[i][15:0]);
        errors = errors + 1;
      end else begin
        $display("[ OK ] C[%0d] = %0d", i, rd[15:0]);
      end
    end

    if (errors == 0) $display("\n==== TEST PASSED ====");
    else             $display("\n==== TEST FAILED (%0d errors) ====", errors);

    $finish;
  end

  // 超时保护
  initial begin
    #200000;
    $display("[FAIL] global timeout");
    $finish;
  end

endmodule

`default_nettype wire
