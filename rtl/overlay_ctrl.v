// overlay_ctrl.v
// -----------------------------------------------------------------------------
// Overlay 控制器：
//   1) AXI4-Lite 从机 —— Host(ARM) 的寄存器读写接口；
//   2) 寄存器组 —— 配置 M/N/K、scratchpad 访问、状态与周期计数；
//   3) 计算 FSM —— 从 scratchpad 取 A/B 装载 fabric，累加，再把 C 写回 scratchpad。
//
// 本骨架约定：M = N = TILE（阵列一轮算完一个 TILE x TILE 的 C 块），K 可配。
// 通用 M/N/K 需要外层分块（tiling），留作后续工作。
// -----------------------------------------------------------------------------
`default_nettype none
`include "overlay_regs.vh"

module overlay_ctrl #(
  parameter TILE      = 4,        // fabric 阵列维度
  parameter W         = 16,       // 操作数位宽
  parameter AW        = 6,        // scratchpad 字地址位宽
  parameter ADDR_W    = 6,        // AXI 字节地址位宽
  parameter DATA_W    = 32        // AXI 数据位宽
)(
  input  wire               clk,
  input  wire               rst_n,

  // ---------- AXI4-Lite 从机 ----------
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
  input  wire               s_axi_rready,

  // ---------- scratchpad：AXI 侧 ----------
  output wire               scr_we,
  output wire [AW-1:0]      scr_waddr,
  output wire [DATA_W-1:0]  scr_wdata,
  output wire [AW-1:0]      scr_raddr,
  input  wire [DATA_W-1:0]  scr_rdata,

  // ---------- scratchpad：fabric 侧 ----------
  output wire               f_we,
  output wire [AW-1:0]      f_waddr,
  output wire [DATA_W-1:0]  f_wdata,
  output wire [AW-1:0]      f_raddr,
  input  wire [DATA_W-1:0]  f_rdata,

  // ---------- fabric 控制 ----------
  output wire               fab_clr,
  output wire               fab_en,
  output wire               we_a,
  output wire [$clog2(TILE)-1:0] waddr_a,
  output wire [W-1:0]       wdata_a,
  output wire               we_b,
  output wire [$clog2(TILE)-1:0] waddr_b,
  output wire [W-1:0]       wdata_b,
  output wire [$clog2(TILE*TILE)-1:0] rd_idx,
  input  wire [2*W-1:0]     rd_acc
);

  // ---------------------------------------------------------------- 寄存器
  reg [31:0] cfg_m, cfg_n, cfg_k;
  reg [AW-1:0]      scr_addr;
  reg [31:0]        perf_cnt;
  reg               busy, done;

  // AXI 写/读握手
  reg               aw_done, w_done, bvalid;
  reg [ADDR_W-1:0]  awaddr_r;
  reg [DATA_W-1:0]  wdata_r;
  reg               ar_done, rvalid;
  reg [ADDR_W-1:0]  araddr_r;
  reg [DATA_W-1:0]  rdata_r;

  // 由 AXI 写产生的 1 拍脉冲
  reg               start_pulse, soft_rst_pulse, scr_we_r;
  reg [AW-1:0]      scr_waddr_r;
  reg [DATA_W-1:0]  scr_wdata_r;

  // FSM
  localparam S_IDLE=3'd0, S_CLEAR=3'd1, S_RDA=3'd2, S_RDB=3'd3,
             S_MAC=3'd4,  S_NEXTK=3'd5, S_STORE=3'd6, S_DONE=3'd7;
  reg [2:0]  state;
  reg [31:0] i_idx, j_idx;      // 行/列索引（用 32 位避免位宽告警，端口处切片）
  reg [31:0] k_idx;
  reg [31:0] st_i, st_j;

  wire [31:0] cidx = st_i * TILE + st_j;

  // ============================================================ AXI 写通道
  assign s_axi_awready = ~aw_done;
  assign s_axi_wready  = ~w_done;
  assign s_axi_bresp   = 2'b00;
  assign s_axi_bvalid  = bvalid;

  wire wr_fire = aw_done & w_done & ~bvalid;
  wire [3:0] wsel = awaddr_r[ADDR_W-1:2];

  // ============================================================ AXI 读通道
  assign s_axi_arready = ~ar_done;
  assign s_axi_rresp   = 2'b00;
  assign s_axi_rvalid  = rvalid;
  assign s_axi_rdata   = rdata_r;

  wire [3:0] rsel = araddr_r[ADDR_W-1:2];

  reg [DATA_W-1:0] rd_mux;
  always @(*) begin
    case (rsel)
      `REG_STATUS      : rd_mux = {30'b0, done, busy};
      `REG_DIM_M       : rd_mux = cfg_m;
      `REG_DIM_N       : rd_mux = cfg_n;
      `REG_DIM_K       : rd_mux = cfg_k;
      `REG_SCR_ADDR    : rd_mux = {{(DATA_W-AW){1'b0}}, scr_addr};
      `REG_SCR_RDATA   : rd_mux = scr_rdata;
      `REG_PERF_CYCLES : rd_mux = perf_cnt;
      default          : rd_mux = {DATA_W{1'b0}};
    endcase
  end

  // ============================================================ 时序：AXI 握手 + 寄存器写
  always @(posedge clk) begin
    if (!rst_n) begin
      aw_done<=0; w_done<=0; bvalid<=0; awaddr_r<=0; wdata_r<=0;
      ar_done<=0; rvalid<=0; araddr_r<=0; rdata_r<=0;
      start_pulse<=0; soft_rst_pulse<=0;
      scr_we_r<=0; scr_waddr_r<=0; scr_wdata_r<=0;
      cfg_m<=TILE; cfg_n<=TILE; cfg_k<=TILE; scr_addr<=0;
    end else begin
      // ---- 默认脉冲复位 ----
      start_pulse<=1'b0; soft_rst_pulse<=1'b0; scr_we_r<=1'b0;

      // ---- AW 捕获 ----
      if (s_axi_awvalid & ~aw_done) begin aw_done<=1'b1; awaddr_r<=s_axi_awaddr; end
      // ---- W 捕获 ----
      if (s_axi_wvalid & ~w_done) begin w_done<=1'b1; wdata_r<=s_axi_wdata; end

      // ---- 写生效 ----
      if (wr_fire) begin
        case (wsel)
          `REG_CTRL: begin
            if (wdata_r[0]) start_pulse     <= 1'b1;
            if (wdata_r[1]) soft_rst_pulse  <= 1'b1;
          end
          `REG_DIM_M    : cfg_m    <= wdata_r;
          `REG_DIM_N    : cfg_n    <= wdata_r;
          `REG_DIM_K    : cfg_k    <= wdata_r;
          `REG_SCR_ADDR : scr_addr <= wdata_r[AW-1:0];
          `REG_SCR_WDATA: begin
            scr_we_r    <= 1'b1;
            scr_waddr_r <= scr_addr;
            scr_wdata_r <= wdata_r;
          end
          default: ;
        endcase
        aw_done<=1'b0; w_done<=1'b0; bvalid<=1'b1;
      end
      if (bvalid & s_axi_bready) bvalid<=1'b0;

      // ---- AR 捕获 ----
      if (s_axi_arvalid & ~ar_done) begin ar_done<=1'b1; araddr_r<=s_axi_araddr; end
      if (ar_done & ~rvalid) begin rvalid<=1'b1; ar_done<=1'b0; rdata_r<=rd_mux; end
      if (rvalid & s_axi_rready) rvalid<=1'b0;
    end
  end

  // ============================================================ FSM
  always @(posedge clk) begin
    if (!rst_n) begin
      state<=S_IDLE; busy<=0; done<=0; perf_cnt<=0;
      i_idx<=0; j_idx<=0; k_idx<=0; st_i<=0; st_j<=0;
    end else if (soft_rst_pulse) begin
      state<=S_IDLE; busy<=0; done<=0; perf_cnt<=0;
    end else begin
      case (state)
        S_IDLE: begin
          if (start_pulse) begin
            busy<=1'b1; done<=1'b0; perf_cnt<=0;
            i_idx<=0; j_idx<=0; k_idx<=0; st_i<=0; st_j<=0;
            state<=S_CLEAR;
          end
        end

        S_CLEAR: begin state<=S_RDA; i_idx<=0; end

        S_RDA: begin
          // we_a 组合有效，逐行装载 A[i][k]
          if (i_idx == TILE-1) begin state<=S_RDB; j_idx<=0; end
          else                     i_idx<=i_idx+1'b1;
        end

        S_RDB: begin
          // we_b 组合有效，逐列装载 B[k][j]
          if (j_idx == TILE-1) begin state<=S_MAC; end
          else                     j_idx<=j_idx+1'b1;
        end

        S_MAC: begin state<=S_NEXTK; end

        S_NEXTK: begin
          if (k_idx == cfg_k-1) begin state<=S_STORE; st_i<=0; st_j<=0; end
          else begin k_idx<=k_idx+1'b1; i_idx<=0; state<=S_RDA; end
        end

        S_STORE: begin
          // f_we 组合有效，逐元素写回 C[i][j]
          if (st_i == TILE-1 && st_j == TILE-1) begin state<=S_DONE; end
          else if (st_j == TILE-1) begin st_j<=0; st_i<=st_i+1'b1; end
          else st_j<=st_j+1'b1;
        end

        S_DONE: begin done<=1'b1; busy<=1'b0; state<=S_IDLE; end
        default: state<=S_IDLE;
      endcase

      if (busy) perf_cnt<=perf_cnt+1'b1;
    end
  end

  // ============================================================ 组合输出：fabric
  // A 装载：地址 = i_idx*K + k_idx
  wire [31:0] a_rd_addr = i_idx * cfg_k + k_idx;
  // B 装载：地址 = M*K + k_idx*N + j_idx
  wire [31:0] b_rd_addr = cfg_m*cfg_k + k_idx*cfg_n + j_idx;
  // C 写回：地址 = M*K + K*N + st_i*N + st_j
  wire [31:0] c_wr_addr = cfg_m*cfg_k + cfg_k*cfg_n + st_i*cfg_n + st_j;

  assign f_raddr = (state==S_RDA) ? a_rd_addr[AW-1:0] :
                   (state==S_RDB) ? b_rd_addr[AW-1:0] : {AW{1'b0}};
  assign f_we    = (state==S_STORE);
  assign f_waddr = c_wr_addr[AW-1:0];
  assign f_wdata = {{(DATA_W-2*W){1'b0}}, rd_acc};

  assign fab_clr = (state==S_CLEAR);
  assign fab_en  = (state==S_MAC);

  assign we_a    = (state==S_RDA);
  assign waddr_a = i_idx[$clog2(TILE)-1:0];
  assign wdata_a = f_rdata[W-1:0];

  assign we_b    = (state==S_RDB);
  assign waddr_b = j_idx[$clog2(TILE)-1:0];
  assign wdata_b = f_rdata[W-1:0];

  assign rd_idx  = cidx[$clog2(TILE*TILE)-1:0];

  // ============================================================ scratchpad AXI 侧
  assign scr_we    = scr_we_r;
  assign scr_waddr = scr_waddr_r;
  assign scr_wdata = scr_wdata_r;
  assign scr_raddr = scr_addr;

endmodule

`default_nettype wire
