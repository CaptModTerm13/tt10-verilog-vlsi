/*
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module BaudRateGenerator#(
    parameter CLOCK_RATE=100000000,
    parameter BAUD_RATE=9600
)(
    input wire clk,
    output reg rxClk,
    output reg txClk
);
parameter MAX_RATE_RX=CLOCK_RATE/(2*BAUD_RATE*16);
parameter MAX_RATE_TX=CLOCK_RATE/(2*BAUD_RATE);
parameter RX_CNT_WIDTH=$clog2(MAX_RATE_RX);
parameter TX_CNT_WIDTH=$clog2(MAX_RATE_TX);
reg[RX_CNT_WIDTH-1:0]rxCounter=0;
reg[TX_CNT_WIDTH-1:0]txCounter=0;
initial begin
    rxClk=1'b0;
    txClk=1'b0;
end
always@(posedge clk)begin
    if(rxCounter==MAX_RATE_RX[RX_CNT_WIDTH-1:0])begin
        rxCounter<=0;
        rxClk<=~rxClk;
    end else begin
        rxCounter<=rxCounter+1'b1;
    end
    if(txCounter==MAX_RATE_TX[TX_CNT_WIDTH-1:0])begin
        txCounter<=0;
        txClk<=~txClk;
    end else begin
        txCounter<=txCounter+1'b1;
    end
end
endmodule

module uart_tx(
    input wire clk,
    input wire rst,
    input wire baudTick,
    input wire transmit,
    input wire[7:0]data,
    output reg tx,
    output reg busy
);
localparam STATE_IDLE=2'b00;
localparam STATE_START=2'b01;
localparam STATE_DATA=2'b10;
localparam STATE_STOP=2'b11;
reg[1:0]state=STATE_IDLE;
reg[2:0]bitIndex=0;
reg[7:0]dataBuffer=0;
always@(posedge clk)begin
    if(rst)begin
        state<=STATE_IDLE;
        tx<=1'b1;
        busy<=1'b0;
        bitIndex<=3'd0;
        dataBuffer<=8'd0;
    end else begin
        if(baudTick)begin
            case(state)
                STATE_IDLE:begin
                    if(transmit)begin
                        busy<=1'b1;
                        dataBuffer<=data;
                        state<=STATE_START;
                        tx<=1'b0;
                    end else begin
                        tx<=1'b1;
                        busy<=1'b0;
                    end
                end
                STATE_START:begin
                    state<=STATE_DATA;
                    bitIndex<=3'd0;
                    tx<=dataBuffer[0];
                end
                STATE_DATA:begin
                    if(bitIndex==3'd7)begin
                        state<=STATE_STOP;
                        tx<=1'b1;
                    end else begin
                        bitIndex<=bitIndex+1;
                        tx<=dataBuffer[bitIndex+1];
                    end
                end
                STATE_STOP:begin
                    state<=STATE_IDLE;
                    busy<=1'b0;
                    tx<=1'b1;
                end
            endcase
        end
    end
end
endmodule

module tt_um_example(
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
wire rst=~rst_n;
wire[7:0] data=ui_in;
wire transmit=uio_in[0];
wire baudTick;
wire tx;
wire busy;
BaudRateGenerator#(
    .CLOCK_RATE(100000000),
    .BAUD_RATE(9600)
) baud_gen(
    .clk(clk),
    .rxClk(),
    .txClk(baudTick)
);
uart_tx uart_transmitter(
    .clk(clk),
    .rst(rst),
    .baudTick(baudTick),
    .transmit(transmit),
    .data(data),
    .tx(tx),
    .busy(busy)
);
assign uo_out[0]=tx;
assign uo_out[1]=busy;
assign uo_out[7:2]=6'b0;
assign uio_out=8'b0;
assign uio_oe=8'b0;
wire _unused=&{ena,1'b0};
endmodule
