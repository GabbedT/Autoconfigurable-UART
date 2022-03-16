`ifndef UART_PACKAGE
  `define UART_PACKAGE

package UART_pkg;

//----------------------//
//  GENERAL PARAMETERS  //
//----------------------//

  /* System clock frequency in Hz */
  localparam SYSTEM_CLOCK_FREQ = 100_000_000;

  /* Number of words stored in the buffers */
  localparam TX_FIFO_DEPTH = 128;
  localparam RX_FIFO_DEPTH = 128;

  /* Interrupt id */
  localparam INT_NONE        = 4'b0000;
  localparam INT_CONFIG_FAIL = 4'b0001;
  localparam INT_OVERRUN     = 4'b0010;
  localparam INT_PARITY      = 4'b0100;
  localparam INT_FRAME       = 4'b1000;
  localparam INT_RXD_RDY     = 4'b0011;
  localparam INT_RX_FULL     = 4'b0101;
  localparam INT_CONFIG_DONE = 4'b0110;
  localparam INT_CONFIG_REQ  = 4'b0111;


//------------------------------//
//  MAIN CONTROLLER PARAMETERS  //
//------------------------------//

  localparam IDLE = 1;

  /* If the signal is driven directly by the controller or by the input */
  localparam DRV_CONTROLLER = 1;
  localparam DRV_INPUT = 0;

  /* The UART's type */ 
  localparam MASTER = 1;
  localparam SLAVE = 0;
  
  /* FSM next and current state */
  localparam NXT = 1;
  localparam CRT = 0;

  /* Milliseconds in seconds */ 
  localparam T_50MS = 50 * (10**(-3));
  localparam T_10MS = 10 * (10**(-3));
  
  /* How many clock cycles does it need to reach 10 / 50 ms */ 
  /* based on a specific system clock */
  localparam COUNT_10MS = SYSTEM_CLOCK_FREQ * T_10MS;
  localparam COUNT_50MS = SYSTEM_CLOCK_FREQ * T_50MS;

  localparam ACKN_PKT = 8'hFF;


//-------------//
// DATA PACKET //
//-------------//

  /*
   * Normally the data packet is just composed by 8 bit of data.
   * Data packet received from UART Host to CONFIGURE the device. 
   * is composed by 3 parts:
   *
   * COMMAND ID: bits [1:0] specifies the setting to configure
   * OPTION:     bits [3:2] select an option
   * DON'T CARE: bits [7:4] those bits are simply ignored
   */

  typedef struct packed {
    logic [1:0] id;
    logic [1:0] option;
    logic [3:0] dont_care;
  } configuration_packet_s;

  /* The packet can have 2 different rapresentation thus it's expressed as union */
  typedef union packed {
    /* Main state */
    logic [7:0] packet;
    /* Configuration state */
    configuration_packet_s cfg_packet;
  } data_packet_u;

  function logic [7:0] assemble_packet(input logic [1:0] id, input logic [1:0] option);
    return {4'b0, option, id};
  endfunction : assemble_packet
  
//----------------------------//
// PACKET WIDTH CONFIGURATION //
//----------------------------//

  /* Command ID */
  localparam logic [1:0] DATA_WIDTH_ID = 2'b01;

  /* Configuration code */
  localparam logic [1:0] DW_5BIT = 2'b00;
  localparam logic [1:0] DW_6BIT = 2'b01;
  localparam logic [1:0] DW_7BIT = 2'b10;
  localparam logic [1:0] DW_8BIT = 2'b11;

//-------------------------//
// STOP BITS CONFIGURATION //
//-------------------------//

  /* Command ID */
  localparam logic [1:0] STOP_BITS_ID = 2'b10;
  
  /* Configuration code */
  localparam logic [1:0] SB_1BIT   = 2'b00;
  localparam logic [1:0] SB_2BIT   = 2'b01;
  localparam logic [1:0] RESERVED1 = 2'b10;
  localparam logic [1:0] RESERVED2 = 2'b11;

//---------------------------//
// PARITY MODE CONFIGURATION //
//---------------------------//

  /* Command ID */
  localparam logic [1:0] PARITY_MODE_ID = 2'b11;

  /* Configuration code */
  localparam logic [1:0] EVEN       = 2'b00;
  localparam logic [1:0] ODD        = 2'b01;
  localparam logic [1:0] DISABLED1  = 2'b10;
  localparam logic [1:0] DISABLED2  = 2'b11;

//---------------------------//
// END CONFIGURATION PROCESS //
//---------------------------//

  localparam logic [1:0] END_CONFIGURATION_ID = 2'b00;

//-------------------------//
// ERROR AND CONFIGURATION //
//-------------------------//

  /* Standard configuration */
  localparam STD_DATA_WIDTH = DW_8BIT;
  localparam STD_STOP_BITS = SB_2BIT;
  localparam STD_PARITY_MODE = EVEN;
  
  typedef struct packed {
    /* If the UART doesn't see a stop bit */
    logic frame;
    /* If the receiver's buffer is full and the UART
     * is receiving data */
    logic overrun;
    /* If parity doesn't match */
    logic parity;
    /* If the uart has recieved an illegal config packet */
    logic configuration;
  } uart_error_s;

  typedef struct packed {
    logic [1:0] data_width;
    logic [1:0] stop_bits;
    logic [1:0] parity_mode;
  } uart_config_s;

//------------------------------//
// MAIN CONTROL FSM ENUMERATION //
//------------------------------//

  typedef enum logic [3:0] {
      /* After reset signal, every register is resetted in standard configuration */
      RESET,
      /* Send configuration request */ 
      CFG_REQ_MST,
      /* If the device sees the initialization signal (10ms RX low) then send an acknowledgment packet */
      SEND_ACKN_SLV,
      /* State before entering the main state */
      END_PROCESS,
      /* Drive TX low to send the initialization signal */
      SETUP_SLV,
      /* Send data width packet */ 
      SETUP_MST,
      /* Wait request acknowledgment */
      WAIT_REQ_ACKN_MST,
      /* Wait for the acknowledgment data width packet */
      WAIT_ACKN_MST,
      /* Setup the device in standard configuration */
      STD_CONFIG,
      /* UART's main state */
      MAIN
  } main_control_fsm_e;

endpackage

`endif 
