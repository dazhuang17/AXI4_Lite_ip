
module axi_lite_controller
#
(
    parameter AXI_ADDERSS_WIDTH = 5,
    parameter AXI_DATA_WIDTH	= 32
)
(
    // clock & reset
    input                               aclk,
    input                               aresetn,

    // AXI write address channel
    input   [AXI_ADDERSS_WIDTH-1 : 0]   saxi_awaddr,
    input                               saxi_awvalid,
    output  reg                         saxi_awready,

    // AXI read address channel
    input   [AXI_ADDERSS_WIDTH-1 : 0]   saxi_araddr,
    input                               saxi_arvalid,
    output  reg                         saxi_arready,

    // AXI write data channel
    input   [AXI_DATA_WIDTH-1 : 0]      saxi_wdata,
    input                               saxi_wvalid,
    output  reg                         saxi_wready,

    // AXI read data channel
    output  reg [AXI_DATA_WIDTH-1 : 0]  saxi_rdata,
    output  reg                         saxi_rvalid,
    input                               saxi_rready,

    // AXI write response channel
    output  reg                         saxi_bvalid,
    input                               saxi_bready,

    // register
    output  [AXI_DATA_WIDTH-1 : 0]      reg1,
    output  [AXI_DATA_WIDTH-1 : 0]      reg2

);

    // register table
    // | address | name | func |
    // | 0x000   | reg1 |      |
    // | 0x004   | reg2 |      |
    // 一个 reg 32 位宽，占据 4个 字节

    reg [AXI_DATA_WIDTH-1 : 0]  reg1_reg;
    reg [AXI_DATA_WIDTH-1 : 0]  reg2_reg;

    assign reg1 = reg1_reg;
    assign reg2 = reg2_reg;

    // AXI write address channel
    // ------------------------------------------------------
    // 握手
    always @(posedge aclk or negedge aresetn) begin
        if (~aresetn) saxi_awready <= 1'b0;
        else begin
            if (saxi_awvalid) saxi_awready <= 1'b1;
            else saxi_awready <= 1'b0;
        end
    end

    // saxi_awaddr -> saxi_awaddr_buffer
    reg [AXI_ADDERSS_WIDTH-1 : 0]  saxi_awaddr_buffer;
    always @(posedge aclk or negedge aresetn) begin
        if (~aresetn) saxi_awaddr_buffer <= 'b0;
        else begin
            if (saxi_awvalid & saxi_awready) saxi_awaddr_buffer <= saxi_awaddr;
            else saxi_awaddr_buffer <= saxi_awaddr_buffer;
        end
    end
    // -----------------------------------------------------


    // AXI write data channel
    // ------------------------------------------------------
    // 握手
    always @(posedge aclk or negedge aresetn) begin
        if (~aresetn) saxi_wready <= 1'b0;
        else begin
            if (saxi_wvalid) saxi_wready <= 1'b1;
            else saxi_wready <= 1'b0;
        end
    end

    // real address to write
    // data    -> address -> write or
    // address -> data    -> write
    reg [AXI_ADDERSS_WIDTH-1 : 0]  axi_waddr;
    always @(*) begin
        if (saxi_awvalid & saxi_awready & saxi_wvalid & saxi_wready) axi_waddr <= saxi_awaddr;
        else axi_waddr <= saxi_awaddr_buffer;
    end

    // data -> register
    always @(posedge aclk or negedge aresetn) begin
        if (~aresetn) begin
            reg1_reg <= 'b0;
            reg2_reg <= 'b0;
        end
        else begin
            case (axi_waddr)
                'h00: reg1_reg <= saxi_wdata;
                'h04: reg2_reg <= saxi_wdata;
                default: begin
                    reg1_reg <= reg1_reg;
                    reg2_reg <= reg2_reg;
                end
            endcase
        end
    end
    // -----------------------------------------------------


    // AXI response request channel
    // ------------------------------------------------------
    reg axi_need_resp;
    always @(posedge aclk or negedge aresetn) begin
        if (~aresetn) axi_need_resp <= 1'b0;
        else begin
            if (saxi_wvalid & saxi_wready) axi_need_resp <= 1'b1;
            else axi_need_resp <= 1'b0;
        end
    end

    // output
    always @(posedge aclk or negedge aresetn) begin
        if (~aresetn) saxi_bvalid <= 1'b0;
        else begin
            if (axi_need_resp) saxi_bvalid <= 1'b1;
            if (saxi_bvalid & saxi_bready) saxi_bvalid <= 1'b0;
        end
    end
    // -----------------------------------------------------


    // AXI read address channel
    // ------------------------------------------------------
    // 握手
    always @(posedge aclk or negedge aresetn) begin
        if (~aresetn) saxi_arready <= 1'b0;
        else begin
            if (saxi_arvalid) saxi_arready <= 1'b1;
            else saxi_arready <= 1'b0;
        end
    end

    // axi_raddr -> saxi_araddr
    reg [AXI_ADDERSS_WIDTH-1 : 0]  axi_raddr;
    reg axi_need_read;
    always @(posedge aclk or negedge aresetn) begin
        if (~aresetn) begin
            axi_raddr     <= 'b0;
            axi_need_read <= 1'b0;
        end
        else begin
            if (saxi_arvalid & saxi_arready) begin
                axi_raddr     <= saxi_araddr;
                axi_need_read <= 1'b1;
            end
            else begin
                axi_raddr     <= axi_raddr;
                axi_need_read <= 1'b0;
            end
        end
    end
    // -----------------------------------------------------


    // AXI read data channel
    // -----------------------------------------------------
    // data register -> axi_data_to_read
    reg [AXI_DATA_WIDTH-1 : 0] axi_data_to_read; //data_temp
    always @(*) begin
        case (axi_raddr)
            'h00: axi_data_to_read <= reg1_reg;
            'h04: axi_data_to_read <= reg2_reg;
            default: axi_data_to_read <= 'b0;
        endcase
    end

    // axi_data_to_read -> output
    reg axi_wait_for_read;
    always @(posedge aclk or negedge aresetn) begin
        if (~aresetn) begin
            saxi_rvalid       <= 1'b0;
            saxi_rdata        <= 'b0;
            axi_wait_for_read <= 1'b0;
        end
        else begin
            if (axi_wait_for_read) begin
                if (saxi_rready) begin
                    axi_wait_for_read <= 1'b0;
                    saxi_rdata        <= axi_data_to_read;
                    saxi_rvalid       <= 1'b1;
                end
                else axi_wait_for_read <= axi_wait_for_read;
            end
            else begin
                if (axi_need_read & saxi_rready) begin
                    saxi_rdata  <= axi_data_to_read;
                    saxi_rvalid <= 1'b1;
                end
                else if (axi_need_read) begin
                    axi_wait_for_read <= 1'b1;
                    saxi_rvalid       <= 1'b0;
                end
                else saxi_rvalid      <= 1'b0;
            end
        end
    end

    // -----------------------------------------------------

endmodule
