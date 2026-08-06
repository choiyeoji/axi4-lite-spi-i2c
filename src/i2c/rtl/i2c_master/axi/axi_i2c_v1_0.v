`timescale 1ns / 1ps

// ==========================================
// 1. Top Wrapper Module
// ==========================================
module axi_i2c_v1_0 #(
    parameter integer C_S00_AXI_DATA_WIDTH = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH = 4
) (
    // I2C external pins
    output wire scl,
    inout  wire sda,

    // AXI Slave Bus Interface
    input  wire                                    s00_axi_aclk,
    input  wire                                    s00_axi_aresetn,
    input  wire [C_S00_AXI_ADDR_WIDTH-1:0]         s00_axi_awaddr,
    input  wire [2:0]                              s00_axi_awprot,
    input  wire                                    s00_axi_awvalid,
    output wire                                    s00_axi_awready,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0]         s00_axi_wdata,
    input  wire [(C_S00_AXI_DATA_WIDTH/8)-1:0]     s00_axi_wstrb,
    input  wire                                    s00_axi_wvalid,
    output wire                                    s00_axi_wready,
    output wire [1:0]                              s00_axi_bresp,
    output wire                                    s00_axi_bvalid,
    input  wire                                    s00_axi_bready,
    input  wire [C_S00_AXI_ADDR_WIDTH-1:0]         s00_axi_araddr,
    input  wire [2:0]                              s00_axi_arprot,
    input  wire                                    s00_axi_arvalid,
    output wire                                    s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1:0]         s00_axi_rdata,
    output wire [1:0]                              s00_axi_rresp,
    output wire                                    s00_axi_rvalid,
    input  wire                                    s00_axi_rready
);

    // Internal wires
    wire        start_pulse;
    wire        rw_mode;
    wire [6:0]  slave_addr_w;
    wire [7:0]  clk_div;
    wire [15:0] tx_data;
    wire [15:0] rx_data;
    wire        done;
    wire        busy;
    wire        sda_o, sda_i;

    // SDA open-drain
    assign sda_i = sda;
    assign sda   = sda_o ? 1'bz : 1'b0;

    // AXI Slave Interface
    axi_i2c_v1_0_S00_AXI #(
        .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
    ) axi_i2c_v1_0_S00_AXI_inst (
        .start_pulse  (start_pulse),
        .rw_mode      (rw_mode),
        .slave_addr   (slave_addr_w),
        .clk_div      (clk_div),
        .tx_data      (tx_data),
        .rx_data      (rx_data),
        .done         (done),
        .busy         (busy),
        .S_AXI_ACLK   (s00_axi_aclk),
        .S_AXI_ARESETN(s00_axi_aresetn),
        .S_AXI_AWADDR (s00_axi_awaddr),
        .S_AXI_AWPROT (s00_axi_awprot),
        .S_AXI_AWVALID(s00_axi_awvalid),
        .S_AXI_AWREADY(s00_axi_awready),
        .S_AXI_WDATA  (s00_axi_wdata),
        .S_AXI_WSTRB  (s00_axi_wstrb),
        .S_AXI_WVALID (s00_axi_wvalid),
        .S_AXI_WREADY (s00_axi_wready),
        .S_AXI_BRESP  (s00_axi_bresp),
        .S_AXI_BVALID (s00_axi_bvalid),
        .S_AXI_BREADY (s00_axi_bready),
        .S_AXI_ARADDR (s00_axi_araddr),
        .S_AXI_ARPROT (s00_axi_arprot),
        .S_AXI_ARVALID(s00_axi_arvalid),
        .S_AXI_ARREADY(s00_axi_arready),
        .S_AXI_RDATA  (s00_axi_rdata),
        .S_AXI_RRESP  (s00_axi_rresp),
        .S_AXI_RVALID (s00_axi_rvalid),
        .S_AXI_RREADY (s00_axi_rready)
    );

    // I2C Master core
    i2c_master U_I2C_MASTER (
        .clk        (s00_axi_aclk),
        .reset      (~s00_axi_aresetn),
        .slave_addr (slave_addr_w),
        .rw         (rw_mode),
        .clk_div    (clk_div),
        .tx_data    (tx_data),
        .start      (start_pulse),
        .sda_i      (sda_i),
        .rx_data    (rx_data),
        .done       (done),
        .busy       (busy),
        .scl_o      (scl),
        .sda_o      (sda_o)
    );

endmodule


// ==========================================
// 2. I2C Master Core (2-byte transfer)
// ==========================================
module i2c_master (
    input  wire        clk,
    input  wire        reset,
    input  wire [6:0]  slave_addr,
    input  wire        rw,           // 0=write, 1=read
    input  wire [7:0]  clk_div,
    input  wire [15:0] tx_data,
    input  wire        start,
    input  wire        sda_i,

    output reg  [15:0] rx_data,
    output reg         done,
    output reg         busy,
    output reg         scl_o,
    output reg         sda_o
);

    localparam IDLE    = 4'd0;
    localparam START_S = 4'd1;
    localparam TX_BIT  = 4'd2;
    localparam RX_ACK  = 4'd3;
    localparam RX_BIT  = 4'd4;
    localparam TX_ACK  = 4'd5;
    localparam STOP_S  = 4'd6;

    reg [3:0]  state;
    reg [7:0]  div_cnt;
    reg        half_tick;
    reg        step;
    reg [2:0]  bit_cnt;
    reg [7:0]  shift_out;
    reg [7:0]  shift_in;
    reg [1:0]  byte_phase;  // 0=addr, 1=data_high, 2=data_low
    reg        is_read;

    // Clock divider
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            div_cnt   <= 0;
            half_tick <= 1'b0;
        end else begin
            if (state != IDLE) begin
                if (div_cnt == clk_div) begin
                    div_cnt   <= 0;
                    half_tick <= 1'b1;
                end else begin
                    div_cnt   <= div_cnt + 1;
                    half_tick <= 1'b0;
                end
            end else begin
                div_cnt   <= 0;
                half_tick <= 1'b0;
            end
        end
    end

    // Main FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= IDLE;
            scl_o      <= 1'b1;
            sda_o      <= 1'b1;
            done       <= 1'b0;
            busy       <= 1'b0;
            rx_data    <= 16'd0;
            shift_out  <= 8'd0;
            shift_in   <= 8'd0;
            bit_cnt    <= 3'd0;
            byte_phase <= 2'd0;
            step       <= 1'b0;
            is_read    <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                // ==============================
                // IDLE
                // ==============================
                IDLE: begin
                    scl_o <= 1'b1;
                    sda_o <= 1'b1;
                    if (start) begin
                        busy       <= 1'b1;
                        is_read    <= rw;
                        shift_out  <= {slave_addr, rw};
                        byte_phase <= 2'd0;
                        bit_cnt    <= 3'd0;
                        step       <= 1'b0;
                        state      <= START_S;
                    end
                end

                // ==============================
                // START condition
                // ==============================
                START_S: begin
                    if (half_tick) begin
                        if (!step) begin
                            sda_o <= 1'b0;       // SDA falls while SCL high
                            step  <= 1'b1;
                        end else begin
                            scl_o     <= 1'b0;   // SCL falls
                            sda_o     <= shift_out[7]; // first bit
                            shift_out <= {shift_out[6:0], 1'b0};
                            bit_cnt   <= 3'd0;
                            step      <= 1'b0;
                            state     <= TX_BIT;
                        end
                    end
                end

                // ==============================
                // TX_BIT: send 8 bits
                // ==============================
                TX_BIT: begin
                    if (half_tick) begin
                        if (!step) begin
                            scl_o <= 1'b1;       // SCL rises
                            step  <= 1'b1;
                        end else begin
                            scl_o <= 1'b0;       // SCL falls
                            if (bit_cnt == 3'd7) begin
                                sda_o   <= 1'b1; // release for ACK
                                bit_cnt <= 3'd0;
                                step    <= 1'b0;
                                state   <= RX_ACK;
                            end else begin
                                sda_o     <= shift_out[7];
                                shift_out <= {shift_out[6:0], 1'b0};
                                bit_cnt   <= bit_cnt + 1;
                                step      <= 1'b0;
                            end
                        end
                    end
                end

                // ==============================
                // RX_ACK: receive slave ACK
                // ==============================
                RX_ACK: begin
                    if (half_tick) begin
                        if (!step) begin
                            scl_o <= 1'b1;       // SCL rises
                            step  <= 1'b1;
                        end else begin
                            scl_o <= 1'b0;       // SCL falls
                            step  <= 1'b0;

                            if (sda_i == 1'b0) begin
                                // ACK received
                                case (byte_phase)
                                    2'd0: begin
                                        // Address done
                                        byte_phase <= 2'd1;
                                        if (!is_read) begin
                                            sda_o     <= tx_data[15];
                                            shift_out <= {tx_data[14:8], 1'b0};
                                            bit_cnt   <= 3'd0;
                                            state     <= TX_BIT;
                                        end else begin
                                            sda_o   <= 1'b1;
                                            bit_cnt <= 3'd0;
                                            state   <= RX_BIT;
                                        end
                                    end
                                    2'd1: begin
                                        // First write byte done
                                        byte_phase <= 2'd2;
                                        sda_o     <= tx_data[7];
                                        shift_out <= {tx_data[6:0], 1'b0};
                                        bit_cnt   <= 3'd0;
                                        state     <= TX_BIT;
                                    end
                                    2'd2: begin
                                        // Second write byte done
                                        sda_o <= 1'b0;
                                        state <= STOP_S;
                                    end
                                    default: begin
                                        sda_o <= 1'b0;
                                        state <= STOP_S;
                                    end
                                endcase
                            end else begin
                                // NACK -> stop
                                sda_o <= 1'b0;
                                state <= STOP_S;
                            end
                        end
                    end
                end

                // ==============================
                // RX_BIT: receive 8 bits
                // ==============================
                RX_BIT: begin
                    if (half_tick) begin
                        if (!step) begin
                            scl_o <= 1'b1;       // SCL rises
                            step  <= 1'b1;
                        end else begin
                            scl_o    <= 1'b0;    // SCL falls
                            shift_in <= {shift_in[6:0], sda_i};

                            if (bit_cnt == 3'd7) begin
                                bit_cnt <= 3'd0;
                                step    <= 1'b0;
                                state   <= TX_ACK;
                                if (byte_phase == 2'd1)
                                    sda_o <= 1'b0;   // ACK (more data)
                                else
                                    sda_o <= 1'b1;   // NACK (last byte)
                            end else begin
                                sda_o   <= 1'b1;
                                bit_cnt <= bit_cnt + 1;
                                step    <= 1'b0;
                            end
                        end
                    end
                end

                // ==============================
                // TX_ACK: send ACK or NACK
                // ==============================
                TX_ACK: begin
                    if (half_tick) begin
                        if (!step) begin
                            scl_o <= 1'b1;       // SCL rises
                            step  <= 1'b1;
                        end else begin
                            scl_o <= 1'b0;       // SCL falls
                            step  <= 1'b0;

                            if (byte_phase == 2'd1) begin
                                // First read byte, ACK sent
                                rx_data[15:8] <= shift_in;
                                byte_phase    <= 2'd2;
                                sda_o         <= 1'b1;
                                bit_cnt       <= 3'd0;
                                state         <= RX_BIT;
                            end else begin
                                // Second read byte, NACK sent
                                rx_data[7:0] <= shift_in;
                                sda_o        <= 1'b0;
                                state        <= STOP_S;
                            end
                        end
                    end
                end

                // ==============================
                // STOP condition
                // ==============================
                STOP_S: begin
                    if (half_tick) begin
                        if (!step) begin
                            scl_o <= 1'b1;       // SCL rises (SDA low)
                            step  <= 1'b1;
                        end else begin
                            sda_o <= 1'b1;       // SDA rises while SCL high
                            done  <= 1'b1;
                            busy  <= 1'b0;
                            state <= IDLE;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule