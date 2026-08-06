`timescale 1ns / 1ps

module spi_slave_top (
    input logic clk,
    input logic rst,
    input logic sclk,
    input logic cpol,  // idle 0:Low, 1:high
    input logic cpha,  // first sampling, 0:first edge, 1:second edge
    input logic [7:0] tx_data,
    input logic cs_n,
    input logic mosi,
    output logic miso,
    output logic [7:0] rx_data,
    output logic done
);
    logic [7:0] w_rx_data;

    spi_slave U_SPI_SLAVE (
        .clk    (clk),
        .rst    (rst),
        .sclk   (sclk),
        .cpol   (cpol),     // idle 0:Low, 1:high
        .cpha   (cpha),     // first sampling, 0:first edge, 1:second edge
        .tx_data(tx_data),
        .cs_n   (cs_n),
        .mosi   (mosi),
        .miso   (miso),
        .rx_data(w_rx_data),
        .done   (done)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_data <= 0;
        end else begin
            if (done) rx_data <= w_rx_data;
        end
    end
endmodule
