`timescale 1ns / 1ps

module tb_axi_spi_rtl();

    // 1. 시스템 클럭 및 리셋
    logic clk;
    logic reset_n;

    // 2. AXI-Lite Write 채널 신호 (우리가 직접 제어할 신호들)
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

    // 3. SPI 통신 핀
    logic spi_mosi;
    logic spi_miso;
    logic spi_sclk;
    logic spi_cs_n;

// =========================================================
    // 4. 작성자님의 AXI IP 인스턴스화
    // =========================================================
    SPI_v1_0 DUT (
        // 클럭 & 리셋 연결
        .s00_axi_aclk    (clk),
        .s00_axi_aresetn (reset_n),
        
        // AXI Write 채널 연결
        .s00_axi_awaddr  (awaddr),
        .s00_axi_awprot  (3'b000), // 안 쓰는 신호는 0으로 묶어줌
        .s00_axi_awvalid (awvalid),
        .s00_axi_awready (awready),
        
        .s00_axi_wdata   (wdata),
        .s00_axi_wstrb   (wstrb),
        .s00_axi_wvalid  (wvalid),
        .s00_axi_wready  (wready),
        
        .s00_axi_bresp   (bresp),
        .s00_axi_bvalid  (bvalid),
        .s00_axi_bready  (bready),

        // AXI Read 채널 연결 (이번 테스트엔 안 쓰니까 0으로 고정)
        .s00_axi_araddr  (32'h00000000),
        .s00_axi_arprot  (3'b000),
        .s00_axi_arvalid (1'b0),
        .s00_axi_arready (), // output은 비워둠
        
        .s00_axi_rdata   (),
        .s00_axi_rresp   (),
        .s00_axi_rvalid  (),
        .s00_axi_rready  (1'b0),

        // SPI 외부 핀 연결
        .sclk (spi_sclk),
        .mosi (spi_mosi),
        .miso (spi_miso),
        .cs_n (spi_cs_n)
    );

// =========================================================
    // 5. AXI Write 타이밍 수동 제어 함수 (안전한 타이밍으로 교체!)
    // =========================================================
    task axi_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            awaddr  <= addr;
            awvalid <= 1;
            wdata   <= data;
            wstrb   <= 4'b1111;
            wvalid  <= 1;
            bready  <= 1;

            // Slave가 준비(ready=1)될 때까지 기다림
            wait(awready && wready);
            
            // [핵심] Slave가 데이터를 레지스터에 안전하게 쓸 수 있도록 
            // 다음 클럭 엣지(posedge)까지 기다려준 뒤에 신호를 내립니다!
            @(posedge clk);
            awvalid <= 0;
            wvalid  <= 0;
            awaddr  <= 0;
            wdata   <= 0;
            wstrb   <= 0;

            wait(bvalid);
            @(posedge clk);
            bready  <= 0;
            
            #50; // 다음 명령을 위해 잠시 대기
        end
    endtask

    // =========================================================
    // 6. 메인 시뮬레이션 시나리오
    // =========================================================
    // 클럭 생성 (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // 리셋 및 데이터 전송
    initial begin
        // 초기화 (Reset ON)
        reset_n = 0;
        awvalid = 0; wvalid = 0; bready = 0;
        spi_miso = 0;
        
        // 100ns 후 리셋 해제 (Reset OFF)
        #100;
        reset_n = 1; 
        #100;

        $display("=== AXI Write 시작 ===");

        // [명령 1] slv_reg0 (주소 0x00)에 SPI 셋팅값 쓰기
        // (예: clk_div를 4로 설정 -> 15:8 비트 위치에 0x04 할당, cpol=0, cpha=0)
        axi_write(32'h0000_0000, 32'h0000_0400);
        
        #50;

        // [명령 2] slv_reg1 (주소 0x04)에 Start 방아쇠와 Data를 한 방에 쏘기!
        // 32'h8000_00AF -> 맨 앞 31번 비트가 1 (Start 켜짐), 맨 뒤 8비트가 0xAF (전송할 데이터)
        axi_write(32'h0000_0004, 32'h8000_00AF);

        $display("=== AXI 명령 완료, SPI 파형 대기 중 ===");

        // SPI 데이터가 모두 나갈 때까지 충분히 대기
        #5000;
        $finish;
    end

endmodule