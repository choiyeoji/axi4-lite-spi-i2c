`timescale 1ns / 1ps

module tb_axi_spi_full_rtl();

    // 1. 시스템 클럭 및 리셋
    logic clk;
    logic reset_n;

    // 2. AXI-Lite Write 채널 신호
    logic [31:0] awaddr;
    logic        awvalid;
    logic        awready;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid;
    logic        wready;
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;

    // [추가됨] 3. AXI-Lite Read 채널 신호 (슬레이브 데이터를 읽어오기 위함)
    logic [31:0] araddr;
    logic        arvalid;
    logic        arready;
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;

    // 4. SPI 통신 물리적 핀
    logic spi_mosi;
    logic spi_miso;
    logic spi_sclk;
    logic spi_cs_n;

    // [추가됨] 슬레이브에서 관찰할 신호
    logic [7:0] slave_rx_data;
    logic       slave_done;

// =========================================================
    // 5. 마스터 (AXI + SPI Master) 인스턴스화
// =========================================================
    SPI_v1_0 DUT (
        .s00_axi_aclk    (clk),
        .s00_axi_aresetn (reset_n),
        
        // Write Channel
        .s00_axi_awaddr  (awaddr),
        .s00_axi_awprot  (3'b000),
        .s00_axi_awvalid (awvalid),
        .s00_axi_awready (awready),
        .s00_axi_wdata   (wdata),
        .s00_axi_wstrb   (wstrb),
        .s00_axi_wvalid  (wvalid),
        .s00_axi_wready  (wready),
        .s00_axi_bresp   (bresp),
        .s00_axi_bvalid  (bvalid),
        .s00_axi_bready  (bready),

        // [수정됨] Read Channel 연결 활성화
        .s00_axi_araddr  (araddr),
        .s00_axi_arprot  (3'b000),
        .s00_axi_arvalid (arvalid),
        .s00_axi_arready (arready),
        .s00_axi_rdata   (rdata),
        .s00_axi_rresp   (rresp),
        .s00_axi_rvalid  (rvalid),
        .s00_axi_rready  (rready),

        // SPI 외부 핀
        .sclk (spi_sclk),
        .mosi (spi_mosi),
        .miso (spi_miso),
        .cs_n (spi_cs_n)
    );

// =========================================================
    // [핵심 추가] 6. SPI Slave 인스턴스화 (보드의 칩 역할)
// =========================================================
    spi_slave_top SLAVE (
        .clk     (clk),
        .rst     (~reset_n),   // Slave 코드는 Active High 리셋이므로 반전 적용
        .sclk    (spi_sclk),
        .cpol    (1'b0),       // Mode 0 고정
        .cpha    (1'b0),
        .tx_data (8'hC3),      // [중요] Slave가 Master로 응답할 데이터 (1100_0011)
        .cs_n    (spi_cs_n),
        .mosi    (spi_mosi),
        .miso    (spi_miso),   // 마스터의 miso 핀으로 쏙 들어갑니다.
        .rx_data (slave_rx_data),
        .done    (slave_done)
    );

// =========================================================
    // 7. AXI Write & Read 수동 제어 함수
// =========================================================
    task axi_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            awaddr  <= addr; awvalid <= 1;
            wdata   <= data; wstrb   <= 4'b1111; wvalid  <= 1;
            bready  <= 1;
            wait(awready && wready);
            @(posedge clk);
            awvalid <= 0; wvalid  <= 0; awaddr  <= 0; wdata   <= 0; wstrb   <= 0;
            wait(bvalid);
            @(posedge clk);
            bready  <= 0;
            #50;
        end
    endtask

    // [추가됨] AXI를 통해 레지스터 값을 읽어오는 함수
    task axi_read(input [31:0] addr);
        begin
            @(posedge clk);
            araddr  <= addr;
            arvalid <= 1;
            rready  <= 1;

            wait(arready && arvalid); // 주소 전달 완료 대기
            @(posedge clk);
            arvalid <= 0;
            araddr  <= 0;

            wait(rvalid && rready);   // 데이터 도착 대기
            $display("[%0t] READ RESULT >> ADDR: 0x%0h | DATA: 0x%0h", $time, addr, rdata);
            @(posedge clk);
            rready <= 0;
            #50;
        end
    endtask

// =========================================================
    // 8. 메인 시뮬레이션 시나리오
// =========================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    initial begin
        // 초기화
        reset_n = 0;
        awvalid = 0; wvalid = 0; bready = 0;
        arvalid = 0; rready = 0;
        
        #100; reset_n = 1; #100;

        $display("=== 1. AXI Write (Master 설정 및 송신 시작) ===");
        // [명령 1] slv_reg0 (주소 0x00): SPI 설정 (clk_div=4, cpol=0, cpha=0)
        axi_write(32'h0000_0000, 32'h0000_0400); 
        
        #50;

        // [명령 2] slv_reg1 (주소 0x04): Start On & Master 송신 데이터(0xAF) 전송
        axi_write(32'h0000_0004, 32'h8000_00AF);

        $display("=== 2. 버스 통신 중 (Master <-> Slave) 대기 ===");
        // SPI 통신(8비트)이 완전히 끝날 때까지 대기
        #850; 

        $display("=== 3. AXI Read (Slave가 보낸 데이터 0xC3 확인) ===");
        // [명령 3] 슬레이브에서 받은 데이터가 들어있는 레지스터 읽기
        // (주의: 작성자님의 설계에서 rx_data가 매핑된 레지스터 주소가 0x08 또는 0x0C일 수 있습니다. 여기서는 모두 읽어봅니다.)
        axi_read(32'h0000_0008); // slv_reg2 확인
        axi_read(32'h0000_000C); // slv_reg3 확인

        #500;
        $display("=== 시뮬레이션 종료 ===");
        $finish;
    end

endmodule