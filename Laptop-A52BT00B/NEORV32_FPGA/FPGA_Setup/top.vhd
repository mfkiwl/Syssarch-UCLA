-- #################################################################################################
-- # << NEORV32 - Test Setup using the RISC-V-compatible On-Chip Debugger >>                       #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2023, Stephan Nolting. All rights reserved.                                     #
-- #                                                                                               #
-- # Redistribution and use in source and binary forms, with or without modification, are          #
-- # permitted provided that the following conditions are met:                                     #
-- #                                                                                               #
-- # 1. Redistributions of source code must retain the above copyright notice, this list of        #
-- #    conditions and the following disclaimer.                                                   #
-- #                                                                                               #
-- # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
-- #    conditions and the following disclaimer in the documentation and/or other materials        #
-- #    provided with the distribution.                                                            #
-- #                                                                                               #
-- # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
-- #    endorse or promote products derived from this software without specific prior written      #
-- #    permission.                                                                                #
-- #                                                                                               #
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
-- # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
-- # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
-- # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
-- # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
-- # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
-- # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
-- # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
-- # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
-- # ********************************************************************************************* #
-- # The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32                           #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity top is
  generic (
    -- adapt these for your setup --
    -- CLOCK_FREQUENCY   : natural := 100000000; -- clock frequency of clk_i in Hz
    CLOCK_FREQUENCY   : natural := 50000000; -- clock frequency of clk_i in Hz (stevez) need to be the same as CLOCK_50 in FPGA
    MEM_INT_IMEM_SIZE : natural := 16*1024;   -- size of processor-internal instruction memory in bytes
    MEM_INT_DMEM_SIZE : natural := 8*1024     -- size of processor-internal data memory in bytes
  );
  port (
    -- Global control --
    clk_i       : in  std_ulogic; -- global clock, rising edge
    rstn_i      : in  std_ulogic; -- global reset, low-active, async
    -- JTAG on-chip debugger interface --
    jtag_trst_i : in  std_ulogic; -- low-active TAP reset (optional)
    jtag_tck_i  : in  std_ulogic; -- serial clock
    jtag_tdi_i  : in  std_ulogic; -- serial data input
    jtag_tdo_o  : out std_ulogic; -- serial data output
    jtag_tms_i  : in  std_ulogic; -- mode select
    -- GPIO --
    gpio_o      : out std_ulogic_vector(7 downto 0); -- parallel output 
    -- UART0 --
    uart0_txd_o : out std_ulogic; -- UART0 send data
    uart0_rxd_i : in  std_ulogic;  -- UART0 receive data
	  	
	-- SPI for bootloader (stevez) --
   	spi_clk_o      : out std_ulogic; -- SPI serial clock
   	spi_dat_o      : out std_ulogic; -- controller data out, peripheral data in
   	spi_dat_i      : in  std_ulogic := 'U'; -- controller data in, peripheral data out
   	spi_csn_o      : out std_ulogic_vector(07 downto 0); -- chip-select
	 
	  -- input key (stevez) --
	  key0			: in std_ulogic;
	  key1 			: in std_ulogic; --> neorv32_cpu
	  
	  -- output LED (stevez) -- 
	  led 		: out std_ulogic_vector(9 downto 0) 
  );
end entity;

architecture neorv32_test_on_chip_debugger_rtl of top is

  signal con_gpio_o : std_ulogic_vector(63 downto 0);

-- input gpio (stevez) --
signal con_gpio_i : std_ulogic_vector(63 downto 0);

begin

  -- The Core Of The Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst: neorv32_top
  generic map (
    -- General --
    CLOCK_FREQUENCY              => CLOCK_FREQUENCY,   -- clock frequency of clk_i in Hz
    INT_BOOTLOADER_EN            => true,              -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM
    -- On-Chip Debugger (OCD) --
    ON_CHIP_DEBUGGER_EN          => true,              -- implement on-chip debugger
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_C        => true,              -- implement compressed extension?
    CPU_EXTENSION_RISCV_M        => true,              -- implement mul/div extension?
    CPU_EXTENSION_RISCV_U        => true,              -- implement user mode extension?
    CPU_EXTENSION_RISCV_Zicntr   => true,              -- implement base counters?
    CPU_EXTENSION_RISCV_Zifencei => true,              -- implement instruction stream sync.? (required for the on-chip debugger)
    -- Internal Instruction memory --
	-- (stevez) always set below to true regadless whether or not it's bootloder
    MEM_INT_IMEM_EN              => true,              -- implement processor-internal instruction memory
    MEM_INT_IMEM_SIZE            => MEM_INT_IMEM_SIZE, -- size of processor-internal instruction memory in bytes
    -- Internal Data memory --
    MEM_INT_DMEM_EN              => true,              -- implement processor-internal data memory
    MEM_INT_DMEM_SIZE            => MEM_INT_DMEM_SIZE, -- size of processor-internal data memory in bytes
    -- Processor peripherals --
    IO_GPIO_NUM                  => 8,                 -- number of GPIO input/output pairs (0..64)
    IO_MTIME_EN                  => true,              -- implement machine system timer (MTIME)?
    IO_UART0_EN                  => true,               -- implement primary universal asynchronous receiver/transmitter (UART0)?

	-- SPI for bootloder (stevez) -- 
	IO_SPI_EN                => true,  -- implement serial peripheral interface (SPI)?
    	IO_SPI_FIFO              => 1      -- RTX fifo depth, has to be a power of two, min 1
  )
  port map (
    -- Global control --
    clk_i       => clk_i,       -- global clock, rising edge
    rstn_i      => rstn_i,      -- global reset, low-active, async
    -- JTAG on-chip debugger interface (available if ON_CHIP_DEBUGGER_EN = true) --
    jtag_trst_i => jtag_trst_i, -- low-active TAP reset (optional)
    jtag_tck_i  => jtag_tck_i,  -- serial clock
    jtag_tdi_i  => jtag_tdi_i,  -- serial data input
    jtag_tdo_o  => jtag_tdo_o,  -- serial data output
    jtag_tms_i  => jtag_tms_i,  -- mode select
    -- GPIO (available if IO_GPIO_NUM > 0) --
    gpio_o      => con_gpio_o,  -- parallel output
	-- input gpio (stevez) -- 
	gpio_i 	=> con_gpio_i, -- parallel input
    -- primary UART0 (available if IO_UART0_EN = true) --
    uart0_txd_o => uart0_txd_o, -- UART0 send data
    uart0_rxd_i => uart0_rxd_i,  -- UART0 receive data

	-- SPI for bootloader (stevez) --
    spi_clk_o	=> spi_clk_o, 	-- SPI serial clock
    spi_dat_o	=> spi_dat_o,	-- controller data out, peripheral data in
    spi_dat_i	=> spi_dat_i,	-- controller data in, peripheral data out
    spi_csn_o	=> spi_csn_o	-- chip-select

  );

  -- GPIO output --
  gpio_o <= con_gpio_o(7 downto 0);

  -- debug (stevez) -- 
led(7 downto 0) <= con_gpio_o(7 downto 0);
led(9) <= NOT key0; --> key0 default '1'
con_gpio_i(0) <= NOT key1; --> key1 default '1'
con_gpio_i(63 downto 1) <= (others => '0');


end architecture;
