// MIT License
//
// Copyright (c) 2021 Gabriele Tripi
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// ------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------
// FILE NAME : configuration_registers.sv
// AUTHOR : Gabriele Tripi
// AUTHOR'S EMAIL : tripi.gabriele2002@gmail.com
// ------------------------------------------------------------------------------------
// RELEASE HISTORY
// VERSION : 1.0 
// DESCRIPTION : This module contains the set of registers that controls the UART, they
//               can all be accessed by the programmer.
// ------------------------------------------------------------------------------------
// KEYWORDS : STR, DVR, CTR, ISR, RXR, TXR, DECODER, DATA BUS
// ------------------------------------------------------------------------------------

`ifndef CONFIGURATION_REGISTERS_INCLUDE
    `define CONFIGURATION_REGISTERS_INCLUDE

`include "Packages/uart_pkg.sv"
`include "sync_FIFO_buffer.sv"

module configuration_registers (
    input  logic        clk_i,    
    input  logic        rst_n_i,  
    input  logic        read_i,              
    input  logic        write_i,            
    input  logic [2:0]  address_i,                     
    input  logic        STR_en_i,           
    input  logic        set_std_config_i,  

    /* BUS */
    `ifdef FPGA 
        input  logic [7:0] data_i,
        output logic [7:0] data_o,
    `else 
        inout  logic [7:0] data_io,
    `endif 
    
    /* STR */
    input  logic [1:0]  data_width_i,   
    input  logic [1:0]  parity_mode_i,  
    input  logic [1:0]  stop_bits_i,    

    output logic        tx_dsm_o,       
    output logic        rx_dsm_o,       
    output logic [1:0]  data_width_o,   
    output logic [1:0]  parity_mode_o,  
    output logic [1:0]  stop_bits_o,    
    output logic [1:0]  updated_data_width_o,   
    output logic [1:0]  updated_parity_mode_o,  
    output logic [1:0]  updated_stop_bits_o,    

    /* DVR */
    input  logic        tx_idle_i,  
    input  logic        rx_idle_i,  

    output logic [15:0] divisor_o,  
    output logic        reset_bd_gen_o, 

    /* FSR */
    input  logic        tx_fifo_full_i, 
    input  logic        rx_fifo_empty_i,    

    output logic [5:0]  rx_fifo_threshold_o, 

    /* CTR */
    input  logic        configuration_done_i,  
    input  logic        int_pending_i,     
    
    output logic        enable_configuration_o,     
    output logic        send_configuration_req_o,  
    output logic        acknowledge_request_o, 
    output logic        tx_enable_o,               
    output logic        rx_enable_o,               

    /* ISR */
    input  logic        int_ackn_i, 
    input  logic [2:0]  interrupt_vector_i, 
    input  logic        interrupt_vector_en_i, 
 
    output logic        tx_done_en_o,  
    output logic        rx_rdy_en_o,   
    output logic        frame_error_en_o,  
    output logic        parity_error_en_o,  
    output logic        overrun_error_en_o,  

    /* RXR */
    input  logic [7:0]  rx_data_i,      
    output logic        rx_fifo_read_o, 

    /* TXR */
    output logic [7:0]  tx_data_o,  
    output logic        tx_fifo_write_o
); 

    /* Enable writing into registers */
    reg_enable_t enable;

    logic enable_config_req;

    logic std_config;

//----------------//
//  STR REGISTER  //
//----------------//

    STR_data_t STR_data;

        always_ff @(posedge clk_i or negedge rst_n_i) begin : STR_WR
            if (!rst_n_i) begin 
                STR_data <= {2'b0, STD_CONFIGURATION};
            end else if (set_std_config_i | std_config) begin 
                STR_data <= {2'b0, STD_CONFIGURATION};
            end else if (STR_en_i & enable_config_req) begin 
                /* The control unit is writing (SLAVE configuration) */
                STR_data.DWID <= data_width_i;
                STR_data.PMID <= parity_mode_i;
                STR_data.SBID <= stop_bits_i;
            end else if (enable.STR) begin 
                /* The CPU is writing */
                `ifdef FPGA 
                    STR_data <= data_i;
                `else 
                    STR_data <= data_io;
                `endif
            end
        end : STR_WR

    assign updated_data_width_o = STR_data.DWID;
    assign updated_parity_mode_o = STR_data.PMID;
    assign updated_stop_bits_o = STR_data.SBID;

    logic [1:0] data_width, parity_mode, stop_bits;

    logic config_done;

    edge_detector #(1) config_done_edge (
        .clk_i        ( clk_i                ),
        .signal_i     ( configuration_done_i ),
        .edge_pulse_o ( config_done          )
    );

        /* Since configuration state of the device must not change immediately 
         * but only after the configuration process, store the old
         * configuration in the register which is used to drive the 
         * modules configuration information. Update the configuration 
         * when the process has ended (when the device is MASTER) */
        always_ff @(posedge clk_i or negedge rst_n_i) begin : config_register
            if (!rst_n_i) begin
                data_width <= STD_DATA_WIDTH;
                parity_mode <= STD_PARITY_MODE;
                stop_bits <= STD_STOP_BITS;
            end else if (set_std_config_i | std_config) begin 
                data_width <= STD_DATA_WIDTH;
                parity_mode <= STD_PARITY_MODE;
                stop_bits <= STD_STOP_BITS;
            end else if (config_done) begin
                data_width <= STR_data.DWID;
                parity_mode <= STR_data.PMID;
                stop_bits <= STR_data.SBID;          
            end else if (STR_en_i & enable_config_req) begin 
                /* The control unit is writing (SLAVE configuration) */
                data_width <= data_width_i;
                parity_mode <= parity_mode_i;
                stop_bits <= stop_bits_i;
            end 
        end : config_register

    assign tx_dsm_o = STR_data.TDSM;
    assign rx_dsm_o = STR_data.RDSM;
    assign data_width_o = data_width;
    assign parity_mode_o = parity_mode;
    assign stop_bits_o = stop_bits;

    
    logic change_config;

    assign change_config = (STR_data.DWID != data_width) | (STR_data.PMID != parity_mode) | (STR_data.SBID != stop_bits);

    edge_detector #(1) config_change_edge (
        .clk_i        ( clk_i                    ),
        .signal_i     ( change_config            ),
        .edge_pulse_o ( send_configuration_req_o )
    );


//----------------//
//  DVR REGISTER  //
//----------------//

    localparam LOWER = 0;
    localparam UPPER = 1;

    logic [UPPER:LOWER][7:0] DVR_data;

        always_ff @(posedge clk_i or negedge rst_n_i) begin : DVR_WR
            if (!rst_n_i) begin 
                DVR_data <= STD_DIVISOR;
            end else if (set_std_config_i | std_config) begin 
                DVR_data <= STD_DIVISOR;
            end else if (enable.LDVR) begin 
                `ifdef FPGA 
                    DVR_data[LOWER] <= data_i;
                `else 
                    DVR_data[LOWER] <= data_io;
                `endif
            end else if (enable.UDVR) begin 
                `ifdef FPGA 
                    DVR_data[UPPER] <= data_i;
                `else 
                    DVR_data[UPPER] <= data_io;
                `endif
            end
        end : DVR_WR


    /* While the divisor value must be written in at least two clock cycles
     * because there are 8 data pins while the divisor value is 16 bits, 
     * the value must be delivered to the baud rate generator in a single
     * clock cycle. */
    logic [15:0]             divisor_bdgen;
    logic                    DVR_done;
    logic [1:0][2:0]         old_address;
        
        /* Shift register that record the last two address */
        always_ff @(posedge clk_i or negedge rst_n_i) begin
            if (!rst_n_i) begin
                old_address <= 6'b0;
            end else begin
                old_address <= {old_address[0], address_i};
            end
        end

    assign DVR_done = (old_address[1] == LDVR_ADDR) & (old_address[0] == UDVR_ADDR);
    assign reset_bd_gen_o = DVR_done & (tx_idle_i & rx_idle_i);

        always_ff @(posedge clk_i or negedge rst_n_i) begin 
            if (!rst_n_i) begin
                divisor_bdgen <= STD_DIVISOR;
            end else if (set_std_config_i | std_config) begin
                divisor_bdgen <= STD_DIVISOR;
            end else if (DVR_done) begin
                divisor_bdgen <= DVR_data;
            end
        end

    assign divisor_o = (tx_idle_i & rx_idle_i) ? divisor_bdgen : DVR_data;


//----------------//
//  FSR REGISTER  //
//----------------//

    FSR_data_t FSR_data;

        always_ff @(posedge clk_i or negedge rst_n_i) begin : FSR_WR
            if (!rst_n_i) begin 
                FSR_data.RX_TRESHOLD <= 6'b0;
            end else if (enable.FSR) begin 
                `ifdef FPGA 
                    FSR_data.RX_TRESHOLD <= data_i[5:0];
                `else 
                    FSR_data.RX_TRESHOLD <= data_io[5:0];
                `endif
            end  
        end : FSR_WR

        always_ff @(posedge clk_i or negedge rst_n_i) begin : FSR_R
            if (!rst_n_i) begin
                FSR_data.TXF <= 1'b0;
                FSR_data.RXE <= 1'b1;
            end else begin 
                FSR_data.TXF <= tx_fifo_full_i;
                FSR_data.RXE <= rx_fifo_empty_i;
            end
        end : FSR_R

    assign rx_fifo_threshold_o = FSR_data.RX_TRESHOLD;


//----------------//
//  CTR REGISTER  //
//----------------//

    CTR_data_t CTR_data;

        always_ff @(posedge clk_i or negedge rst_n_i) begin : CTR_WR
            if (!rst_n_i) begin   
                CTR_data.VECTORED <= 1'b0;
                CTR_data.COM <= STD_COMM_MODE;
                CTR_data.ENREQ <= 1'b1;
            end else if (set_std_config_i | std_config) begin 
                CTR_data.COM   <= STD_COMM_MODE;
                CTR_data.ENREQ <= 1'b1;                
            end else if (enable.CTR) begin 
                `ifdef FPGA 
                    CTR_data.VECTORED <= data_i[6];
                    CTR_data.COM <= data_i[4:3];
                    CTR_data.ENREQ <= data_i[2];
                `else
                    CTR_data.VECTORED <= data_io[6];
                    CTR_data.COM <= data_io[4:3];
                    CTR_data.ENREQ <= data_io[2];
                `endif
            end 
        end : CTR_WR


    assign std_config = CTR_data.STDC;

        always_ff @(posedge clk_i or negedge rst_n_i) begin : CTR_R
            if (!rst_n_i) begin 
                CTR_data.CDONE <= 1'b1;
                CTR_data.INTPEND <= 1'b0;
            end else begin 
                CTR_data.CDONE <= configuration_done_i;
                CTR_data.INTPEND <= !int_pending_i;
            end
        end : CTR_R

    assign enable_config_req = CTR_data.ENREQ;


        always_ff @(posedge clk_i or negedge rst_n_i) begin 
            if (!rst_n_i) begin
                CTR_data.STDC <= 1'b0;
                CTR_data.AKREQ <= 1'b0;
            end else if (enable.CTR) begin
                `ifdef FPGA 
                    CTR_data.STDC <= data_i[1];
                    CTR_data.AKREQ <= data_i[0];
                `else
                    CTR_data.STDC <= data_io[1];
                    CTR_data.AKREQ <= data_io[0];
                `endif
            end else begin
                CTR_data.STDC <= 1'b0;
                CTR_data.AKREQ <= 1'b0;
            end
        end

    assign tx_enable_o = CTR_data.COM[0];
    assign rx_enable_o = CTR_data.COM[1];
    assign enable_configuration_o = enable_config_req;
    assign acknowledge_request_o = CTR_data.AKREQ;


//----------------//
//  ISR REGISTER  //
//----------------//

    ISR_data_t ISR_data;

        always_ff @(posedge clk_i or negedge rst_n_i) begin : ISR_WR
            if (!rst_n_i) begin 
                ISR_data.TXDONE <= 1'b1;
                ISR_data.RXRDY  <= 1'b1;
                ISR_data.FRM    <= 1'b1;
                ISR_data.PAR    <= 1'b1;
                ISR_data.OVR    <= 1'b1;
            end else if (enable.ISR) begin 
                `ifdef FPGA 
                    ISR_data.TXDONE <= data_i[6];
                    ISR_data.RXRDY  <= data_i[6];
                    ISR_data.FRM    <= data_i[5];
                    ISR_data.PAR    <= data_i[4];
                    ISR_data.OVR    <= data_i[3];
                `else
                    ISR_data.TXDONE <= data_io[6];
                    ISR_data.RXRDY  <= data_io[6];
                    ISR_data.FRM    <= data_io[5];
                    ISR_data.PAR    <= data_io[4];
                    ISR_data.OVR    <= data_io[3];
                `endif
            end
        end : ISR_WR

        always_ff @(posedge clk_i or negedge rst_n_i) begin : ISR_R
            if (!rst_n_i) begin 
                ISR_data.INTID <= 3'b0;
            end else if (interrupt_vector_en_i) begin 
                ISR_data.INTID <= interrupt_vector_i;
            end
        end : ISR_R

    assign overrun_error_en_o = ISR_data.OVR;
    assign parity_error_en_o = ISR_data.PAR;
    assign frame_error_en_o = ISR_data.FRM;
    assign tx_done_en_o = ISR_data.TXDONE;
    assign rx_rdy_en_o = ISR_data.RXRDY;


//----------------//
//  RXR REGISTER  //
//----------------//

    logic rx_fifo_empty_edge;

    edge_detector #(0) empty_fifo_negedge (
        .clk_i        ( clk_i              ),
        .signal_i     ( rx_fifo_empty_i    ),
        .edge_pulse_o ( rx_fifo_empty_edge )
    );


    logic [7:0] RXR_data;
    logic rx_fifo_read;

        always_ff @(posedge clk_i or negedge rst_n_i) begin : RXR_WR
            if (!rst_n_i) begin
                RXR_data <= 8'b0;
            end else if (rx_fifo_read) begin
                RXR_data <= rx_data_i;
            end
        end : RXR_WR

    /* Should be high for 1 clock cycle, the register must be loaded when the fifo is not empty
     * anymore so a read will return a valid value */
    assign rx_fifo_read = (!rx_fifo_empty_i & read_i & (address_i == RXR_ADDR)) | rx_fifo_empty_edge;
    assign rx_fifo_read_o = rx_fifo_read;


//----------------//
//  TXR REGISTER  //
//----------------//

    logic [7:0] TXR_data;

        always_ff @(posedge clk_i or negedge rst_n_i) begin 
            if (!rst_n_i) begin
                TXR_data <= 8'b0;
            end else if (enable.TXR) begin
                `ifdef FPGA 
                    TXR_data <= data_i;
                `else 
                    TXR_data <= data_io;
                `endif
            end
        end

    /* Flop the write signal so that it arrives to the 
     * transmitter at the same time of the data (which
     * is also registred) */
    logic write_ff;

        always_ff @(posedge clk_i or negedge rst_n_i) begin 
            if (!rst_n_i) begin
                write_ff <= 1'b0;
            end else begin
                write_ff <= write_i;
            end
        end

    assign tx_data_o = TXR_data;
    assign tx_fifo_write_o = (write_ff & (address_i == TXR_ADDR));


//-----------//
//  DECODER  //
//-----------//
  
    /* Data stored into the registers */
    logic [7:0] data_register;

        always_comb begin : decoder
            enable = 8'b0;
            data_register = 8'b0;

            if (write_i) begin
                /* Enable register write */
                case (address_i)
                    STR_ADDR:  enable.STR  = 1'b1;
                    LDVR_ADDR: enable.LDVR = 1'b1;
                    UDVR_ADDR: enable.UDVR = 1'b1;
                    FSR_ADDR:  enable.FSR  = 1'b1;
                    CTR_ADDR:  enable.CTR  = 1'b1;
                    ISR_ADDR:  enable.ISR  = 1'b1;
                    TXR_ADDR:  enable.TXR  = 1'b1;
                    default:   enable = 8'b0;
                endcase
            end else if (read_i) begin 
                case (address_i)
                    STR_ADDR:  data_register = STR_data;
                    LDVR_ADDR: data_register = DVR_data[LOWER];
                    UDVR_ADDR: data_register = DVR_data[UPPER];
                    FSR_ADDR:  data_register = FSR_data;
                    CTR_ADDR:  data_register = CTR_data;
                    ISR_ADDR:  data_register = ISR_data;
                    RXR_ADDR:  data_register = RXR_data;
                    TXR_ADDR:  data_register = TXR_data;
                    default:   data_register = 8'b0;
                endcase          
            end 
        end : decoder


//------------//
//  DATA BUS  //
//------------//

    logic [7:0] data; 

    always_comb begin
        if (CTR_data.VECTORED & !int_pending_i & int_ackn_i) begin
            data = UART_ISR_VECTOR;        
        end else begin
            data = data_register;
        end
    end

    `ifdef FPGA 
        assign data_o = data;
    `else  
        assign data_io = (read_i) ? data : 8'bZ;
    `endif 

endmodule : configuration_registers

`endif