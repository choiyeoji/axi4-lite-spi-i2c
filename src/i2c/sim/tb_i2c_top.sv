`timescale 1ns / 1ps

module tb_i2c_top ();

    logic       clk;
    logic       reset;
    logic       cmd_start;
    logic       cmd_write;
    logic       cmd_read;
    logic       cmd_stop;
    logic [7:0] tx_data;
    logic       ack_in;
    logic [7:0] rx_data;
    logic       done;
    logic       ack_out;
    logic       busy;

    wire scl;
    wire sda;

    pullup(scl);
    pullup(sda);

    localparam SLA = 7'h25;

    I2C_Master dut (
        .clk      (clk),
        .reset    (reset),
        //.sw(tx_data),
        .scl(scl),
        .sda(sda),
        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read (cmd_read),
        .cmd_stop (cmd_stop),
        .tx_data  (tx_data),
        .ack_in   (ack_in),
        .rx_data  (rx_data),
        .done     (done),
        .ack_out  (ack_out),
        .busy     (busy)
    );

    wire [7:0] slave_led;

    i2c_slave_led u_slave (
        .clk   (clk),
        .reset (reset),
        .scl   (scl),
        .sda   (sda),
        .led   (slave_led)
    );

    always #5 clk = ~clk;

    task i2c_start();
        cmd_start = 1'b1;
        cmd_write = 1'b0;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait (done);
        @(posedge clk);
    endtask

    task i2c_addr(byte addr);
        tx_data = (SLA << 1) + 1'b0; 
        cmd_start = 1'b0;
        cmd_write = 1'b1;
        cmd_read = 1'b0;
        cmd_stop = 1'b0;
        @(posedge clk);
        wait (done);
        @(posedge clk);
    endtask

    task i2c_write(byte data);
        tx_data   = data;
        cmd_start = 1'b0;
        cmd_write = 1'b1;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait (done);  
        @(posedge clk);
    endtask

    task i2c_read();
        cmd_start = 1'b0;
        cmd_write = 1'b0;
        cmd_read  = 1'b1;
        cmd_stop  = 1'b0;
        @(posedge clk);
        wait (done);
        @(posedge clk);
    endtask

    task i2c_stop();
        //stop
        cmd_start = 1'b0;
        cmd_write = 1'b0;
        cmd_read  = 1'b0;
        cmd_stop  = 1'b1;
        @(posedge clk);
        wait (done);
        @(posedge clk);
    endtask

    initial begin
        clk   = 0;
        reset = 1;
        ack_in = 1'b0;
        repeat (3) @(posedge clk);
        reset = 0;
        @(posedge clk);

        i2c_start();
        i2c_addr(SLA << 1 + 1'b0);
        i2c_write(8'h55);

        //i2c_start();
        //i2c_addr(SLA << 1 + 1'b0);
        i2c_write(8'haa);

        //i2c_start();
        //i2c_addr(SLA << 1 + 1'b0);
        i2c_write(8'h01);
        i2c_read();

        //i2c_start();
        //i2c_addr(SLA << 1 + 1'b0);
        i2c_write(8'h02);

        //i2c_start();
        //i2c_addr(SLA << 1 + 1'b0);
        i2c_write(8'h03);
        //i2c_write(8'h04);
        //i2c_write(8'h05);
        //i2c_write(8'hff);
        i2c_stop();

        #100;
        $stop;
    end

endmodule
