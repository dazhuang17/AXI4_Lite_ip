# axi_lite_controller_v1.0

## 写在前面

这是一个用户定义的 verilog IP core ，用于通过 slave 的 AXI4_Lite 进行 FPGA 传输。

**仅分析初始代码**。

## 寄存器

slave 的 AXI4_Lite 接收主机传来的数据，将数据存放在 slave 的寄存器中。示例(**用户可自行扩展**)：
```
//-- Number of Slave Registers 4
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
```

比如说这里有四个寄存器，那对应的读写地址只有四个，与之相关的信号为：
```
// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
// ADDR_LSB is used for addressing 32/64 bit registers/memories
// ADDR_LSB = 2 for 32 bits (n downto 2)
// ADDR_LSB = 3 for 64 bits (n downto 3)
localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
localparam integer OPT_MEM_ADDR_BITS = 1;   //这个就是寄存器数量（二进制）

XXX_Xaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]  //对应地址确定寄存器。至多有4个寄存器
```

在总线操作中，片选读写寄存器是以寄存器为单位的，而不是以字节为单位的，所以在通过地址判断要读写的寄存器时，只需要判断地址的**高 2 位**选择 4 寄存器。

选择寄存器后，也可以使用 'WSTRB' 域来控制寄存器中指定字节的写使能。示例(32 bit = 4 Byte)：
```
for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
    if ( S_AXI_WSTRB[byte_index] == 1 ) begin
        // Respective byte enables are asserted as per write strobes
        // Slave register 0
        slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
```

如果要扩充寄存器，则扩大 `C_S_AXI_ADDR_WIDTH` 位数，若最多8个寄存器，则 `C_S_AXI_ADDR_WIDTH` 为 5 ，高三位是寄存器选择位、

**有一个疑问**，XXX_Xaddr 只有一部分充当地址，那其他部分的作用是什么呢？答案是**控制信息**！


## 接口时序

以 **写数据** 为例。

为了不过多占用总线，`axi_awready` 仅置高一个时钟周期，完成`地址信号`的接收：
```
if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
    begin
        // slave is ready to accept write address when
        // there is a valid write address and write data
        // on the write address and data bus. This design
        // expects no outstanding transactions.
        axi_awready <= 1'b1;
        // Write Address latching
        axi_awaddr <= S_AXI_AWADDR;
    end
    begin
        axi_awready <= 1'b0;
    end
```

为了不过多占用总线，`axi_wready` 仅置高一个时钟周期，完成`数据信号`的接收：
```
if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
    begin
        // slave is ready to accept write data when 
        // there is a valid write address and write data
        // on the write address and data bus. This design 
        // expects no outstanding transactions. 
        axi_wready <= 1'b1;
    end
    else
    begin
        axi_wready <= 1'b0;
    end
```

写入寄存器标志：`assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;`

具体写入寄存器的时候，还有写选通信号 `S_AXI_WSTRB` ，以写入寄存器 0 示例：
```
// 一次选通即 8 bit ，即 1 Byte
for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
    if ( S_AXI_WSTRB[byte_index] == 1 ) begin
        // Respective byte enables are asserted as per write strobes
        // Slave register 0
        slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
    end
```

**以上示例意味着，写地址和写数据的有效的同时的，即 `slv_reg_wren` 仅拉高一个时钟周期，完成信号的写入。**

**只能说完成 AXI 协议的一部分功能把，这边写数据还有其他条件下能够完成。**

哦哦哦，还有个写回复。。。。俺忘记了。。。。

（这边的自由度也很大），示例：
```
if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
    begin
        // indicates a valid write response is available
        axi_bvalid <= 1'b1;
        axi_bresp  <= 2'b0; // 'OKAY' response 
    end                   // work error responses in future
else
    begin
        if (S_AXI_BREADY && axi_bvalid) 
            //check if bready is asserted while bvalid is high) 
            //(there is a possibility that bready is always asserted high)   
            begin
              axi_bvalid <= 1'b0; 
            end
    end
```
