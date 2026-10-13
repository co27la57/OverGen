// fabric.v
// -----------------------------------------------------------------------------
// 最小可编程空间 fabric：TILE x TILE 的 MAC 计算阵列（output-stationary 广播模型）。
//
// 计算语义（一个 k 步）：
//   a_reg[i] = A[i][k]（A 的第 k 列，按行广播）
//   b_reg[j] = B[k][j]（B 的第 k 行，按列广播）
//   acc[i][j] += a_reg[i] * b_reg[j]
// 完成 K 步后： C[i][j] = acc[i][j] = sum_k A[i][k]*B[k][j]
//
// 输入寄存器由控制器通过简单写端口逐元素装载；结果通过 rd_idx 组合读出。
// 该结构即"可编程空间架构"的最小实例：PE 阵列 + 可配置数据广播 + 可切 kernel。
// -----------------------------------------------------------------------------
`default_nettype none

module fabric #(
  parameter TILE = 4,          // 阵列维度（TILE x TILE 个 MAC）
  parameter W    = 16          // 操作数位宽
)(
  input  wire                       clk,
  input  wire                       rst_n,
  input  wire                       clr,       // 清空累加器
  input  wire                       en,        // 累加使能（一个 k 步有效一拍）

  // A 行向量装载
  input  wire                       we_a,
  input  wire [$clog2(TILE)-1:0]    waddr_a,
  input  wire [W-1:0]               wdata_a,
  // B 列向量装载
  input  wire                       we_b,
  input  wire [$clog2(TILE)-1:0]    waddr_b,
  input  wire [W-1:0]               wdata_b,

  // 结果读出
  input  wire [$clog2(TILE*TILE)-1:0] rd_idx,
  output wire [2*W-1:0]               rd_acc
);

  reg [W-1:0]   a_reg [0:TILE-1];
  reg [W-1:0]   b_reg [0:TILE-1];
  reg [2*W-1:0] acc   [0:TILE*TILE-1];

  // ---- 输入寄存器装载 ----
  always @(posedge clk) begin
    if (we_a) a_reg[waddr_a] <= wdata_a;
    if (we_b) b_reg[waddr_b] <= wdata_b;
  end

  // ---- MAC 阵列 ----
  genvar i, j;
  generate
    for (i = 0; i < TILE; i = i + 1) begin : G_ROW
      for (j = 0; j < TILE; j = j + 1) begin : G_COL
        always @(posedge clk) begin
          if (!rst_n)            acc[i*TILE + j] <= {(2*W){1'b0}};
          else if (clr)          acc[i*TILE + j] <= {(2*W){1'b0}};
          else if (en)           acc[i*TILE + j] <= acc[i*TILE + j] + (a_reg[i] * b_reg[j]);
        end
      end
    end
  endgenerate

  // ---- 结果组合读出 ----
  assign rd_acc = acc[rd_idx];

endmodule

`default_nettype wire
