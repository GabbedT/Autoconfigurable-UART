# Table of contents
- [Table of contents](#table-of-contents)
- [Introduction](#introduction)
  - [Features](#features)
  - [Block Diagram](#block-diagram)
- [Architecture](#architecture)
  - [Signal Description](#signal-description)
  - [Configuration Protocol](#configuration-protocol)
  - [Main Controller](#main-controller)
  - [Receiver](#receiver)
  - [Transmitter](#transmitter)
  - [Baud Rate Generator](#baud-rate-generator)
  - [Interrupt](#interrupt)
- [Registers](#registers)
  - [Status Register (STR)](#status-register-str)
    - [Fields Description](#fields-description)
  - [Divisor Register (DVR)](#divisor-register-dvr)
  - [FIFO Status Register (FSR)](#fifo-status-register-fsr)
    - [Fields Description](#fields-description-1)
  - [Control Register (CTR)](#control-register-ctr)
    - [Fields Description](#fields-description-2)
  - [Interrupt Status Register (ISR)](#interrupt-status-register-isr)
    - [Fields Description](#fields-description-3)
    - [Interrupt Table](#interrupt-table)
  - [Data Received Register (RXR)](#data-received-register-rxr)
    - [Fields Description](#fields-description-4)
  - [Data Transmitted Register (TXR)](#data-transmitted-register-txr)
    - [Fields Description](#fields-description-5)
- [Operations](#operations)
  - [Transmission](#transmission)
  - [Reception](#reception)
  - [Configuration](#configuration)
- [References](#references)

# Introduction

  ## Features

  ## Block Diagram



# Architecture

  ## Signal Description
  
  ## Configuration Protocol

  ## Main Controller

  ## Receiver

  ## Transmitter
  
  ## Baud Rate Generator

  ## Interrupt 



# Registers

  ## Status Register (STR)

  ![STR](Images/STR.PNG)

  The status register contains the device current configuration except for the baudrate.

  **ADDRESS** : 0

  ### Fields Description

  | Field  | Access Mode | Description |
  | ------ | ----------- | ----------- |
  | TDSM   | `(R/W)`     | Enable _` data stream mode `_ for transmitter module.
  | RDSM   | `(R/W)`     | Enable _` data stream mode `_ for receiver module.
  | SBID   | `(R/W)`     | Set _` stop bit number `_ configuration ID.
  | PMID   | `(R/W)`     | Set _` parity mode `_ configuration ID.
  | DWID   | `(R/W)`     | Set _` data width `_ configuration ID.


  **SBID Field**
  | Value       | Description |
  | ----------- | ----------- |
  | `00`        | 1 stop bit. | 
  | `01`        | 2 stop bit. | 
  | `10`        | Reserved. | 
  | `11`        | Reserved. | 

  **PMID Field**
  | Value       | Description |
  | ----------- | ----------- |
  | `00`        | Even. | 
  | `01`        | Odd. | 
  | `10`        | Disabled. | 
  | `11`        | Disabled. | 

  **DWID Field**
  | Value       | Description |
  | ----------- | ----------- |
  | `00`        | 5 bits.     | 
  | `01`        | 6 bits. | 
  | `10`        | 7 bits. | 
  | `11`        | 8 bits. | 


<br />

  ## Divisor Register (DVR)

  ![DVR](Images/DVR.PNG)

  The Divisor Register is a 16 bit register splitted in two different addressable register (`LDVR` and `UDVR`). Since the divisor is a 16 bit value and two registers can't be addressed at the same time, to read or write the entire value, two different operation must be executed. 
  
  The UART doesn't change it's configuration until two writes on two the two registers happens.

  **LOWER ADDRESS** : 1  
  **UPPER ADDRESS** : 2

<br />

  ## FIFO Status Register (FSR)

  ![FSR](Images/FSR.PNG)

  The FIFO Status Register holds the state of both recever and transmitter FIFOs. Notice how the only useful status flags are: the `full` flag for the transmitter FIFO: the `empty` flag is not really needed because an interrupt will occur when it's empty; the same thing for the `empty` flag for the receiver FIFO: the `full` flag is not really needed because an interrupt will occur when it's full. 

  If the programmer wants the device to interrupt when it receives a fixed amount of data, he can set a threshold for the receiver FIFO buffer.

  **ADDRESS** : 3

  ### Fields Description

  | Field  | Access Mode | Description |
  | ------ | ----------- | ----------- |
  | TXF    | `(R)`       | Transmitter FIFO `full` flag.
  | RXE    | `(R)`       | Receiver FIFO `empty` flag.
  | RX THRESHOLD | `(R/W)` | Forces the UART to interrupt when it receives an amount of data that equals that number. Any value between `RX_FIFO_SIZE` and `0` can be set (**those two values are illegal**).


<br />

  ## Control Register (CTR)

  ![CTR](Images/CTR.PNG)

  The Control Register controls the state of the configuration request for both master and slave. A bit can also be set to set the device into standard configuration.

  **ADDRESS** : 4

  ### Fields Description

  | Field  | Access Mode | Description |
  | ------ | ----------- | ----------- |
  | CDONE  | `(R)`       | The configuration process has ended, this bit **must be polled** during every configuration process (both master and slave).
  | AKREQ  | `(W)`       | Acknowledge the configuration request sended by the master device, the device become slave.
  | STDC   | `(W)`       | Set standard configuration.
  | SREQ   | `(W)`       | Send configuration request, the device in this case become master.

<br />

  ## Interrupt Status Register (ISR)

  ![CTR](Images/ISR.PNG)

  The Interrupt Status Register contains the interrupt status and enable bits as well as a vector that give the cause of the interruption.

  **ADDRESS** : 5

  ### Fields Description

  | Field  | Access Mode | Description |
  | ------ | ----------- | ----------- |
  | RXRDY  | `(R/W)`     | Enable interrupt on data received (works with and withoud data stream mode). |
  | FRM    | `(R/W)`     | Enable interrupt on frame error. |
  | PAR    | `(R/W)`     | Enable interrupt on parity error. |
  | OVR    | `(R/W)`     | Enable interrupt on overrun error. |
  | INTID  | `(R)`       | Returns the interrupt ID with the highest priority.
  | IACK   | `(W)`       | Set this bit to acknowledge the interrupt, once it's cleared (the interrupt), the bit is resetted automatically

  ### Interrupt Table

  | Cause   | Priority | ID      | Clear       |
  | ------- | -------- | ------- | ----------- |
  | Transmission done | 3 | `000` | Acknowledge interrupt
  | Configuration error | 1 | `001` | Send another configuration request 
  | Overrun error | 1 | `010` | Read the data
  | Parity error | 1 | `011` | Read the data
  | Frame error | 1 | `100` | Read the data 
  | Data received ready | 3 | `101` | Standard mode: read RXR. Data stream mode: The fifo has reached his threshold read RXR till the buffer is empty.
  | Receiver fifo full | 2 | `110` | Standard mode: read RXR. Data stream mode: read RXR till the buffer is empty.
  | Requested configuration | 2 | `111` | Acknowledge the request or let the request expire.


<br />

  ## Data Received Register (RXR)

  ![RXR](Images/RXR.PNG)
  
  The Data Received Register simply holds the data stored in the FIFO of the receiver.

  **ADDRESS** : 6
  ### Fields Description

  | Field   | Access Mode | Description   |
  | ------- | ----------- | ------------- | 
  | DATA RX | `(R)`       | Data received |

  
<br />

  ## Data Transmitted Register (TXR)

  ![TXR](Images/TXR.PNG)

  The Data Transmitted Register holds the data that will be sent by the transmitter. 

  ### Fields Description

  | Field   | Access Mode | Description   |
  | ------- | ----------- | ------------- | 
  | DATA TX | `(W)`       | Data to be transmitted |


# Operations

  ## Transmission

  ## Reception

  ## Configuration  


# References