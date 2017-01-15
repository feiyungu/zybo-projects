-------------------------------------------------------------------------------
-- SRL_FIFO entity and architecture
-------------------------------------------------------------------------------
--
-- *************************************************************************
-- **                                                                     **
-- ** DISCLAIMER OF LIABILITY                                             **
-- **                                                                     **
-- ** This text/file contains proprietary, confidential                   **
-- ** information of Xilinx, Inc., is distributed under                   **
-- ** license from Xilinx, Inc., and may be used, copied                  **
-- ** and/or disclosed only pursuant to the terms of a valid              **
-- ** license agreement with Xilinx, Inc. Xilinx hereby                   **
-- ** grants you a license to use this text/file solely for               **
-- ** design, simulation, implementation and creation of                  **
-- ** design files limited to Xilinx devices or technologies.             **
-- ** Use with non-Xilinx devices or technologies is expressly            **
-- ** prohibited and immediately terminates your license unless           **
-- ** covered by a separate agreement.                                    **
-- **                                                                     **
-- ** Xilinx is providing this design, code, or information               **
-- ** "as-is" solely for use in developing programs and                   **
-- ** solutions for Xilinx devices, with no obligation on the             **
-- ** part of Xilinx to provide support. By providing this design,        **
-- ** code, or information as one possible implementation of              **
-- ** this feature, application or standard, Xilinx is making no          **
-- ** representation that this implementation is free from any            **
-- ** claims of infringement. You are responsible for obtaining           **
-- ** any rights you may require for your implementation.                 **
-- ** Xilinx expressly disclaims any warranty whatsoever with             **
-- ** respect to the adequacy of the implementation, including            **
-- ** but not limited to any warranties or representations that this      **
-- ** implementation is free from claims of infringement, implied         **
-- ** warranties of merchantability or fitness for a particular           **
-- ** purpose.                                                            **
-- **                                                                     **
-- ** Xilinx products are not intended for use in life support            **
-- ** appliances, devices, or systems. Use in such applications is        **
-- ** expressly prohibited.                                               **
-- **                                                                     **
-- ** Any modifications that are made to the Source Code are              **
-- ** done at the user�s sole risk and will be unsupported.               **
-- ** The Xilinx Support Hotline does not have access to source           **
-- ** code and therefore cannot answer specific questions related         **
-- ** to source HDL. The Xilinx Hotline support of original source        **
-- ** code IP shall only address issues and questions related             **
-- ** to the standard Netlist version of the core (and thus               **
-- ** indirectly, the original core source).                              **
-- **                                                                     **
-- ** Copyright (c) 2001-2013 Xilinx, Inc. All rights reserved.           **
-- **                                                                     **
-- ** This copyright and support notice must be retained as part          **
-- ** of this text at all times.                                          **
-- **                                                                     **
-- *************************************************************************
--
-------------------------------------------------------------------------------
-- Filename:        srl_fifo.vhd
--
-- Description:     
--                  
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--              srl_fifo.vhd
--
-------------------------------------------------------------------------------
-- Author:          goran
-- Revision:        $Revision: 1.1.4.1 $
-- Date:            $Date: 2010/09/14 22:35:47 $
--
-- History:
--   goran  2001-05-11    First Version
--   KC     2001-06-20    Added Addr as an output port, for use as an occupancy
--                        value
--
--   DCW    2002-03-12    Structural implementation of synchronous reset for
--                        Data_Exists DFF (using FDR)
--   jam    2002-04-12    added C_XON generic for mixed vhdl/verilog sims
--
--   als    2002-04-18    added default for XON generic in SRL16E, FDRE, and FDR
--                        component declarations
--
--     DET     1/17/2008     v4_00_a
-- ~~~~~~
--     - Incorporated new disclaimer header
-- ^^^^^^
--
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x" 
--      reset signals:                          "rst", "rst_n" 
--      generics:                               "C_*" 
--      user defined types:                     "*_TYPE" 
--      state machine next state:               "*_ns" 
--      state machine current state:            "*_cs" 
--      combinatorial signals:                  "*_com" 
--      pipelined or register delay signals:    "*_d#" 
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce" 
--      internal version of output port         "*_i"
--      device pins:                            "*_pin" 
--      ports:                                  - Names begin with Uppercase 
--      processes:                              "*_PROCESS" 
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
library unisim;
use unisim.all;

entity SRL_FIFO is
  generic (
    C_DATA_BITS : natural := 8;
    C_DEPTH     : natural := 16;
    C_XON       : boolean := false
    );
  port (
    Clk         : in  std_logic;
    Reset       : in  std_logic;
    FIFO_Write  : in  std_logic;
    Data_In     : in  std_logic_vector(0 to C_DATA_BITS-1);
    FIFO_Read   : in  std_logic;
    Data_Out    : out std_logic_vector(0 to C_DATA_BITS-1);
    FIFO_Full   : out std_logic;
    Data_Exists : out std_logic;
    Addr        : out std_logic_vector(0 to 3) -- Added Addr as a port
    );

end entity SRL_FIFO;

architecture IMP of SRL_FIFO is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of IMP : architecture is "yes";

  component SRL16E is
      -- pragma translate_off
    generic (
      INIT : bit_vector := X"0000"
      );
      -- pragma translate_on    
    port (
      CE  : in  std_logic;
      D   : in  std_logic;
      Clk : in  std_logic;
      A0  : in  std_logic;
      A1  : in  std_logic;
      A2  : in  std_logic;
      A3  : in  std_logic;
      Q   : out std_logic);
  end component SRL16E;

  component LUT4
    generic(
      INIT : bit_vector := X"0000"
      );
    port (
      O  : out std_logic;
      I0 : in  std_logic;
      I1 : in  std_logic;
      I2 : in  std_logic;
      I3 : in  std_logic);
  end component;

  component MULT_AND
    port (
      I0 : in  std_logic;
      I1 : in  std_logic;
      LO : out std_logic);
  end component;

  component MUXCY_L
    port (
      DI : in  std_logic;
      CI : in  std_logic;
      S  : in  std_logic;
      LO : out std_logic);
  end component;

  component XORCY
    port (
      LI : in  std_logic;
      CI : in  std_logic;
      O  : out std_logic);
  end component;

  component FDRE is
    port (
      Q  : out std_logic;
      C  : in  std_logic;
      CE : in  std_logic;
      D  : in  std_logic;
      R  : in  std_logic);
  end component FDRE;

  component FDR is
    port (
      Q  : out std_logic;
      C  : in  std_logic;
      D  : in  std_logic;
      R  : in  std_logic);
  end component FDR;

  signal addr_i       : std_logic_vector(0 to 3);  
  signal buffer_Full  : std_logic;
  signal buffer_Empty : std_logic;

  signal next_Data_Exists : std_logic;
  signal data_Exists_I    : std_logic;

  signal valid_Write : std_logic;

  signal hsum_A  : std_logic_vector(0 to 3);
  signal sum_A   : std_logic_vector(0 to 3);
  signal addr_cy : std_logic_vector(0 to 4);
  
begin  -- architecture IMP

  buffer_Full <= '1' when (addr_i = "1111") else '0';
  FIFO_Full   <= buffer_Full;

  buffer_Empty <= '1' when (addr_i = "0000") else '0';

  next_Data_Exists <= (data_Exists_I and not buffer_Empty) or
                      (buffer_Empty and FIFO_Write) or
                      (data_Exists_I and not FIFO_Read);

  Data_Exists_DFF : FDR
    port map (
      Q  => data_Exists_I,            -- [out std_logic]
      C  => Clk,                      -- [in  std_logic]
      D  => next_Data_Exists,         -- [in  std_logic]
      R  => Reset);                   -- [in std_logic]

  Data_Exists <= data_Exists_I;
  
  valid_Write <= FIFO_Write and (FIFO_Read or not buffer_Full);

  addr_cy(0) <= valid_Write;

  Addr_Counters : for I in 0 to 3 generate

    hsum_A(I) <= (FIFO_Read xor addr_i(I)) and (FIFO_Write or not buffer_Empty);

    MUXCY_L_I : MUXCY_L
      port map (
        DI => addr_i(I),                  -- [in  std_logic]
        CI => addr_cy(I),               -- [in  std_logic]
        S  => hsum_A(I),                -- [in  std_logic]
        LO => addr_cy(I+1));            -- [out std_logic]

    XORCY_I : XORCY
      port map (
        LI => hsum_A(I),                -- [in  std_logic]
        CI => addr_cy(I),               -- [in  std_logic]
        O  => sum_A(I));                -- [out std_logic]

    FDRE_I : FDRE
      port map (
        Q  => addr_i(I),                  -- [out std_logic]
        C  => Clk,                      -- [in  std_logic]
        CE => data_Exists_I,            -- [in  std_logic]
        D  => sum_A(I),                 -- [in  std_logic]
        R  => Reset);                   -- [in std_logic]

  end generate Addr_Counters;

  FIFO_RAM : for I in 0 to C_DATA_BITS-1 generate
    SRL16E_I : SRL16E
      -- pragma translate_off
      generic map (
        INIT => x"0000")
      -- pragma translate_on
      port map (
        CE  => valid_Write,             -- [in  std_logic]
        D   => Data_In(I),              -- [in  std_logic]
        Clk => Clk,                     -- [in  std_logic]
        A0  => addr_i(0),                 -- [in  std_logic]
        A1  => addr_i(1),                 -- [in  std_logic]
        A2  => addr_i(2),                 -- [in  std_logic]
        A3  => addr_i(3),                 -- [in  std_logic]
        Q   => Data_Out(I));            -- [out std_logic]
  end generate FIFO_RAM;
  
-------------------------------------------------------------------------------
-- INT_ADDR_PROCESS
-------------------------------------------------------------------------------
-- This process assigns the internal address to the output port
-------------------------------------------------------------------------------
  INT_ADDR_PROCESS:process (addr_i)
  begin   -- process
    Addr <= addr_i;
  end process;
  

end architecture IMP;


-------------------------------------------------------------------------------
-- axi_bram_ctrl_funcs.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
------------------------------------------------------------------------------
-- Filename:        axi_bram_ctrl_funcs.vhd
--
-- Description:     Support functions for axi_bram_ctrl library modules.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
--
--
-- History:
--
-- ^^^^^^
-- JLJ      2/1/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
-- JLJ      2/16/2011      v1.03a
-- ~~~~~~
--  Update ECC size on 128-bit data width configuration.
-- ^^^^^^
-- JLJ      2/23/2011      v1.03a
-- ~~~~~~
--  Add MIG functions for Hsiao ECC.
-- ^^^^^^
-- JLJ      2/24/2011      v1.03a
-- ~~~~~~
--  Add Find_ECC_Size function.
-- ^^^^^^
-- JLJ      3/15/2011      v1.03a
-- ~~~~~~
--  Add REDUCTION_OR function.
-- ^^^^^^
-- JLJ      3/17/2011      v1.03a
-- ~~~~~~
--  Recode Create_Size_Max with a case statement.
-- ^^^^^^
-- JLJ      3/31/2011      v1.03a
-- ~~~~~~
--  Add coverage tags.
-- ^^^^^^
-- JLJ      5/6/2011      v1.03a
-- ~~~~~~
--  Remove usage of C_FAMILY.  
--  Remove Family_To_LUT_Size function.
--  Remove String_To_Family function.
-- ^^^^^^
--
--
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x"
--      reset signals:                          "rst", "rst_n"
--      generics:                               "C_*"
--      user defined types:                     "*_TYPE"
--      state machine next state:               "*_ns"
--      state machine current state:            "*_cs"
--      combinatorial signals:                  "*_com"
--      pipelined or register delay signals:    "*_d#"
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce"
--      internal version of output port         "*_i"
--      device pins:                            "*_pin"
--      ports:                                  - Names begin with Uppercase
--      processes:                              "*_PROCESS"
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

package axi_bram_ctrl_funcs is

  type TARGET_FAMILY_TYPE is (
                              -- pragma xilinx_rtl_off
                              SPARTAN3,
                              VIRTEX4,
                              VIRTEX5,
                              SPARTAN3E,
                              SPARTAN3A,
                              SPARTAN3AN,
                              SPARTAN3Adsp,
                              SPARTAN6,
                              VIRTEX6,
                              VIRTEX7,
                              KINTEX7,
                              -- pragma xilinx_rtl_on
                              RTL
                             );

  -- function String_To_Family (S : string; Select_RTL : boolean) return TARGET_FAMILY_TYPE;

  -- Get the maximum number of inputs to a LUT.
  -- function Family_To_LUT_Size(Family : TARGET_FAMILY_TYPE) return integer;

  function Equal_String( str1, str2 : STRING ) RETURN BOOLEAN;
  function log2(x : natural) return integer;
  function Int_ECC_Size (i: integer) return integer;
  function Find_ECC_Size (i: integer; j: integer) return integer;
  function Find_ECC_Full_Bit_Size (i: integer; j: integer) return integer;
  function Create_Size_Max (i: integer) return std_logic_vector;
  function REDUCTION_OR (A: in std_logic_vector) return std_logic;
  function REDUCTION_XOR (A: in std_logic_vector) return std_logic;
  function REDUCTION_NOR (A: in std_logic_vector) return std_logic;
  function BOOLEAN_TO_STD_LOGIC (A: in BOOLEAN) return std_logic;
    

end package axi_bram_ctrl_funcs;




library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;



package body axi_bram_ctrl_funcs is


-------------------------------------------------------------------------------
-- Function:    Int_ECC_Size
-- Purpose:     Determine internal size of ECC when enabled.
-------------------------------------------------------------------------------

function Int_ECC_Size (i: integer) return integer is
begin  

--coverage off

    if (i = 32) then
        return 7;   -- 7-bits ECC for 32-bit data
                    -- ECC port size fixed @ 8-bits
    elsif (i = 64) then
        return 8;
    elsif (i = 128) then
        return 9;   -- Hsiao is 9-bits for 128-bit data.
    else
        return 0;
    end if;

--coverage on
    
end Int_ECC_Size;

-------------------------------------------------------------------------------
-- Function:    Find_ECC_Size
-- Purpose:     Determine external size of ECC signals when enabled.
-------------------------------------------------------------------------------

function Find_ECC_Size (i: integer; j: integer) return integer is
begin  

--coverage off

    if (i = 1) then
        if (j = 32) then
            return 8;   -- Keep at 8 for port size matchings
                        -- Only 7-bits ECC per 32-bit data
        elsif (j = 64) then
            return 8;
        elsif (j = 128) then
            return 9;
        else
            return 0;
        end if;
    else
        return 0;
        -- ECC data width = 0 when C_ECC = 0 (disabled)
    end if;

--coverage on
    
end Find_ECC_Size;

-------------------------------------------------------------------------------
-- Function:    Find_ECC_Full_Bit_Size
-- Purpose:     Determine external size of ECC signals when enabled in bytes.
-------------------------------------------------------------------------------

function Find_ECC_Full_Bit_Size (i: integer; j: integer) return integer is
begin  

--coverage off

    if (i = 1) then
        if (j = 32) then
            return 8;
        elsif (j = 64) then
            return 8;
        elsif (j = 128) then
            return 16;
        else
            return 0;
        end if;
    else
        return 0;
        -- ECC data width = 0 when C_ECC = 0 (disabled)
    end if;

--coverage on
    
end Find_ECC_Full_Bit_Size;


-------------------------------------------------------------------------------
-- Function:    Create_Size_Max
-- Purpose:     Create maximum value for AxSIZE based on AXI data bus width.
-------------------------------------------------------------------------------

function Create_Size_Max (i: integer)
    return std_logic_vector is

variable size_vector : std_logic_vector (2 downto 0);
begin

    case (i) is
        when 32 =>      size_vector := "010";           -- 2h (4 bytes)
        when 64 =>      size_vector := "011";           -- 3h (8 bytes)    
        when 128 =>     size_vector := "100";           -- 4h (16 bytes)
        when 256 =>     size_vector := "101";           -- 5h (32 bytes)
        when 512 =>     size_vector := "110";           -- 5h (32 bytes)
        when 1024 =>    size_vector := "111";           -- 5h (32 bytes)
--coverage off
        when others =>  size_vector := "000";           -- 0h    
--coverage on

    end case;

    return (size_vector);

end function Create_Size_Max;





-------------------------------------------------------------------------------
-- Function:    REDUCTION_OR
-- Purpose:     New in v1.03a
-------------------------------------------------------------------------------

function REDUCTION_OR (A: in std_logic_vector) return std_logic is
variable tmp : std_logic := '0';
begin
    for i in A'range loop
       tmp := tmp or A(i);
    end loop;
    return tmp;
end function REDUCTION_OR;




-------------------------------------------------------------------------------
-- Function:    REDUCTION_XOR
-- Purpose:     Derived from MIG v3.7 ecc_gen module for use by Hsiao ECC.
--              New in v1.03a
-------------------------------------------------------------------------------

function REDUCTION_XOR (A: in std_logic_vector) return std_logic is
  variable tmp : std_logic := '0';
begin
  for i in A'range loop
       tmp := tmp xor A(i);
  end loop;
  return tmp;
end function REDUCTION_XOR;




-------------------------------------------------------------------------------
-- Function:    REDUCTION_NOR
-- Purpose:     Derived from MIG v3.7 ecc_dec_fix module for use by Hsiao ECC.
--              New in v1.03a
-------------------------------------------------------------------------------

function REDUCTION_NOR (A: in std_logic_vector) return std_logic is
  variable tmp : std_logic := '0';
begin
  for i in A'range loop
       tmp := tmp or A(i);
  end loop;
  return not tmp;
end function REDUCTION_NOR;




-------------------------------------------------------------------------------
-- Function:    BOOLEAN_TO_STD_LOGIC
-- Purpose:     Derived from MIG v3.7 ecc_dec_fix module for use by Hsiao ECC.
--              New in v1.03a
-------------------------------------------------------------------------------

function BOOLEAN_TO_STD_LOGIC (A : in BOOLEAN) return std_logic is
begin
   if A = true then
       return '1';
   else
       return '0';
   end if;
end function BOOLEAN_TO_STD_LOGIC;


-------------------------------------------------------------------------------

function LowerCase_Char(char : character) return character is
begin

--coverage off

    -- If char is not an upper case letter then return char
    if char < 'A' or char > 'Z' then
      return char;
    end if;
    -- Otherwise map char to its corresponding lower case character and
    -- return that
    case char is
      when 'A'    => return 'a'; when 'B' => return 'b'; when 'C' => return 'c'; when 'D' => return 'd';
      when 'E'    => return 'e'; when 'F' => return 'f'; when 'G' => return 'g'; when 'H' => return 'h';
      when 'I'    => return 'i'; when 'J' => return 'j'; when 'K' => return 'k'; when 'L' => return 'l';
      when 'M'    => return 'm'; when 'N' => return 'n'; when 'O' => return 'o'; when 'P' => return 'p';
      when 'Q'    => return 'q'; when 'R' => return 'r'; when 'S' => return 's'; when 'T' => return 't';
      when 'U'    => return 'u'; when 'V' => return 'v'; when 'W' => return 'w'; when 'X' => return 'x';
      when 'Y'    => return 'y'; when 'Z' => return 'z';
      when others => return char;
    end case;

--coverage on

end LowerCase_Char;


-------------------------------------------------------------------------------


-- Returns true if case insensitive string comparison determines that
-- str1 and str2 are equal
function Equal_String ( str1, str2 : STRING ) RETURN BOOLEAN IS
  CONSTANT len1 : INTEGER := str1'length;
  CONSTANT len2 : INTEGER := str2'length;
  VARIABLE equal : BOOLEAN := TRUE;
BEGIN

--coverage off

    IF NOT (len1=len2) THEN
      equal := FALSE;
    ELSE
      FOR i IN str1'range LOOP
        IF NOT (LowerCase_Char(str1(i)) = LowerCase_Char(str2(i))) THEN
          equal := FALSE;
        END IF;
      END LOOP;
    END IF;

--coverage on

    RETURN equal;
    
END Equal_String;


-------------------------------------------------------------------------------


-- Remove usage of C_FAMILY.
-- Remove usage of String_To_Family function.
--
--    
--    function String_To_Family (S : string; Select_RTL : boolean) return TARGET_FAMILY_TYPE is
--    begin  -- function String_To_Family
--    
--    --coverage off
--    
--        if ((Select_RTL) or Equal_String(S, "rtl")) then
--          return RTL;
--        elsif Equal_String(S, "spartan3") or Equal_String(S, "aspartan3") then
--          return SPARTAN3;
--        elsif Equal_String(S, "spartan3E") or Equal_String(S, "aspartan3E") then
--          return SPARTAN3E;
--        elsif Equal_String(S, "spartan3A") or Equal_String(S, "aspartan3A") then
--          return SPARTAN3A;
--        elsif Equal_String(S, "spartan3AN") then
--          return SPARTAN3AN;
--        elsif Equal_String(S, "spartan3Adsp") or Equal_String(S, "aspartan3Adsp") then
--          return SPARTAN3Adsp;
--        elsif Equal_String(S, "spartan6")  or Equal_String(S, "spartan6l") or
--              Equal_String(S, "qspartan6") or Equal_String(S, "aspartan6") or Equal_String(S, "qspartan6l") then
--          return SPARTAN6;
--        elsif Equal_String(S, "virtex4") or Equal_String(S, "qvirtex4")
--           or Equal_String(S, "qrvirtex4") then
--          return VIRTEX4;
--        elsif Equal_String(S, "virtex5") or Equal_String(S, "qrvirtex5") then
--          return VIRTEX5;
--        elsif Equal_String(S, "virtex6") or Equal_String(S, "virtex6l") or Equal_String(S, "qvirtex6") then
--          return VIRTEX6;
--        elsif Equal_String(S, "virtex7") then
--          return VIRTEX7;
--        elsif Equal_String(S, "kintex7") then
--          return KINTEX7;
--    
--    --coverage on
--    
--        else
--          -- assert (false) report "No known target family" severity failure;
--          return RTL;
--        end if;
--        
--    end function String_To_Family;


-------------------------------------------------------------------------------

-- Remove usage of C_FAMILY.
-- Remove usage of Family_To_LUT_Size function.
--
--    function Family_To_LUT_Size (Family : TARGET_FAMILY_TYPE) return integer is
--    begin
--    
--    --coverage off
--    
--        if (Family = SPARTAN3) or (Family = SPARTAN3E) or (Family = SPARTAN3A) or
--           (Family = SPARTAN3AN) or (Family = SPARTAN3Adsp) or (Family = VIRTEX4) then
--          return 4;
--        end if;
--    
--        return 6;
--    
--    --coverage on
--    
--    end function Family_To_LUT_Size;


-------------------------------------------------------------------------------
-- Function log2 -- returns number of bits needed to encode x choices
--   x = 0  returns 0
--   x = 1  returns 0
--   x = 2  returns 1
--   x = 4  returns 2, etc.
-------------------------------------------------------------------------------

function log2(x : natural) return integer is
  variable i  : integer := 0; 
  variable val: integer := 1;
begin 

--coverage off

    if x = 0 then return 0;
    else
      for j in 0 to 29 loop -- for loop for XST 
        if val >= x then null; 
        else
          i := i+1;
          val := val*2;
        end if;
      end loop;
    -- Fix per CR520627  XST was ignoring this anyway and printing a  
    -- Warning in SRP file. This will get rid of the warning and not
    -- impact simulation.  
    -- synthesis translate_off
      assert val >= x
        report "Function log2 received argument larger" &
               " than its capability of 2^30. "
        severity failure;
    -- synthesis translate_on
      return i;
    end if;  

--coverage on

end function log2; 


-------------------------------------------------------------------------------


  

end package body axi_bram_ctrl_funcs;


-------------------------------------------------------------------------------
-- coregen_comp_defs - entity/architecture pair
-------------------------------------------------------------------------------
--
-- *************************************************************************
-- **                                                                     **
-- ** DISCLAIMER OF LIABILITY                                             **
-- **                                                                     **
-- ** This text/file contains proprietary, confidential                   **
-- ** information of Xilinx, Inc., is distributed under                   **
-- ** license from Xilinx, Inc., and may be used, copied                  **
-- ** and/or disclosed only pursuant to the terms of a valid              **
-- ** license agreement with Xilinx, Inc. Xilinx hereby                   **
-- ** grants you a license to use this text/file solely for               **
-- ** design, simulation, implementation and creation of                  **
-- ** design files limited to Xilinx devices or technologies.             **
-- ** Use with non-Xilinx devices or technologies is expressly            **
-- ** prohibited and immediately terminates your license unless           **
-- ** covered by a separate agreement.                                    **
-- **                                                                     **
-- ** Xilinx is providing this design, code, or information               **
-- ** "as-is" solely for use in developing programs and                   **
-- ** solutions for Xilinx devices, with no obligation on the             **
-- ** part of Xilinx to provide support. By providing this design,        **
-- ** code, or information as one possible implementation of              **
-- ** this feature, application or standard, Xilinx is making no          **
-- ** representation that this implementation is free from any            **
-- ** claims of infringement. You are responsible for obtaining           **
-- ** any rights you may require for your implementation.                 **
-- ** Xilinx expressly disclaims any warranty whatsoever with             **
-- ** respect to the adequacy of the implementation, including            **
-- ** but not limited to any warranties or representations that this      **
-- ** implementation is free from claims of infringement, implied         **
-- ** warranties of merchantability or fitness for a particular           **
-- ** purpose.                                                            **
-- **                                                                     **
-- ** Xilinx products are not intended for use in life support            **
-- ** appliances, devices, or systems. Use in such applications is        **
-- ** expressly prohibited.                                               **
-- **                                                                     **
-- ** Any modifications that are made to the Source Code are              **
-- ** done at the user�s sole risk and will be unsupported.               **
-- ** The Xilinx Support Hotline does not have access to source           **
-- ** code and therefore cannot answer specific questions related         **
-- ** to source HDL. The Xilinx Hotline support of original source        **
-- ** code IP shall only address issues and questions related             **
-- ** to the standard Netlist version of the core (and thus               **
-- ** indirectly, the original core source).                              **
-- **                                                                     **
-- ** Copyright (c) 2008-2013 Xilinx, Inc. All rights reserved.           **
-- **                                                                     **
-- ** This copyright and support notice must be retained as part          **
-- ** of this text at all times.                                          **
-- **                                                                     **
-- *************************************************************************
--
-------------------------------------------------------------------------------
-- Filename:        coregen_comp_defs.vhd
-- Version:         initial
-- Description:     
--   Component declarations for all black box netlists generated by
--   running COREGEN and AXI BRAM CTRL when XST elaborated the client core
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:   
--                      -- coregen_comp_defs.vhd
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

PACKAGE coregen_comp_defs IS

-------------------------------------------------------------------------------------
-- Start Block Memory Generator Component for blk_mem_gen_v8_3_4
-- Component declaration for blk_mem_gen_v8_3_4 pulled from the  blk_mem_gen_v8_3_4.v
-- Verilog file used to match paramter order for NCSIM compatibility
-------------------------------------------------------------------------------------
component blk_mem_gen_v8_3_4
  generic (
  ----------------------------------------------------------------------------
  -- Generic Declarations
  ----------------------------------------------------------------------------
  --Device Family & Elaboration Directory Parameters:
    C_FAMILY                    : STRING  := "virtex4";
    C_XDEVICEFAMILY             : STRING  := "virtex4";
--    C_ELABORATION_DIR           : STRING  := "";
  
    C_INTERFACE_TYPE            : INTEGER := 0;
    C_AXI_TYPE                  : INTEGER := 1;
    C_AXI_SLAVE_TYPE            : INTEGER := 0;
    C_HAS_AXI_ID                : INTEGER := 0;

    C_AXI_ID_WIDTH                : INTEGER := 4;
  --General Memory Parameters:  
    C_MEM_TYPE                  : INTEGER := 2;
    C_BYTE_SIZE                 : INTEGER := 9;
    C_ALGORITHM                 : INTEGER := 0;
    C_PRIM_TYPE                 : INTEGER := 3;
  
  --Memory Initialization Parameters:
    C_LOAD_INIT_FILE            : INTEGER := 0;
    C_INIT_FILE_NAME            : STRING  := "";
    C_USE_DEFAULT_DATA          : INTEGER := 0;
    C_DEFAULT_DATA              : STRING  := "111111111";
    C_RST_TYPE                  : STRING  := "SYNC";
  
  --Port A Parameters:
    --Reset Parameters:
    C_HAS_RSTA                  : INTEGER := 0;
    C_RST_PRIORITY_A            : STRING  := "CE";
    C_RSTRAM_A                  : INTEGER := 0;
    C_INITA_VAL                 : STRING  := "0";
  
    --Enable Parameters:
    C_HAS_ENA                   : INTEGER := 1;
    C_HAS_REGCEA                : INTEGER := 0;
  
    --Byte Write Enable Parameters:
    C_USE_BYTE_WEA              : INTEGER := 0;
    C_WEA_WIDTH                 : INTEGER := 1;
  
    --Write Mode:
    C_WRITE_MODE_A              : STRING  := "WRITE_FIRST";
  
    --Data-Addr Width Parameters:
    C_WRITE_WIDTH_A             : INTEGER := 4;
    C_READ_WIDTH_A              : INTEGER := 4;
    C_WRITE_DEPTH_A             : INTEGER := 4096;
    C_READ_DEPTH_A              : INTEGER := 4096;
    C_ADDRA_WIDTH               : INTEGER := 12;
  
  --Port B Parameters:
    --Reset Parameters:
    C_HAS_RSTB                  : INTEGER := 0;
    C_RST_PRIORITY_B            : STRING  := "CE";
    C_RSTRAM_B                  : INTEGER := 0;
    C_INITB_VAL                 : STRING  := "0";
  
    --Enable Parameters:
    C_HAS_ENB                   : INTEGER := 1;
    C_HAS_REGCEB                : INTEGER := 0;
  
    --Byte Write Enable Parameters:
    C_USE_BYTE_WEB              : INTEGER := 0;
    C_WEB_WIDTH                 : INTEGER := 1;
  
    --Write Mode:
    C_WRITE_MODE_B              : STRING  := "WRITE_FIRST";
  
    --Data-Addr Width Parameters:
    C_WRITE_WIDTH_B             : INTEGER := 4;
    C_READ_WIDTH_B              : INTEGER := 4;
    C_WRITE_DEPTH_B             : INTEGER := 4096;
    C_READ_DEPTH_B              : INTEGER := 4096;
    C_ADDRB_WIDTH               : INTEGER := 12;
  
  --Output Registers/ Pipelining Parameters:
    C_HAS_MEM_OUTPUT_REGS_A     : INTEGER := 0;
    C_HAS_MEM_OUTPUT_REGS_B     : INTEGER := 0;
    C_HAS_MUX_OUTPUT_REGS_A     : INTEGER := 0;
    C_HAS_MUX_OUTPUT_REGS_B     : INTEGER := 0;
    C_MUX_PIPELINE_STAGES       : INTEGER := 0;

   --Input/Output Registers for SoftECC :
    C_HAS_SOFTECC_INPUT_REGS_A  : INTEGER := 0;
    C_HAS_SOFTECC_OUTPUT_REGS_B : INTEGER := 0;
  
  --ECC Parameters
    C_USE_ECC                   : INTEGER := 0;
    C_USE_SOFTECC               : INTEGER := 0;
    C_HAS_INJECTERR             : INTEGER := 0;
    
  --Simulation Model Parameters:
    C_SIM_COLLISION_CHECK       : STRING  := "NONE";
    C_COMMON_CLK                : INTEGER := 0;
    C_DISABLE_WARN_BHV_COLL     : INTEGER := 0;
    C_DISABLE_WARN_BHV_RANGE    : INTEGER := 0
  );
  PORT (
  ----------------------------------------------------------------------------
  -- Input and Output Declarations
  ----------------------------------------------------------------------------
  -- Native BMG Input and Output Port Declarations
  --Port A:
    CLKA                             : IN  STD_LOGIC := '0';
    RSTA                             : IN  STD_LOGIC := '0';
    ENA                              : IN  STD_LOGIC := '0';
    REGCEA                           : IN  STD_LOGIC := '0';
    WEA                              : IN  STD_LOGIC_VECTOR(C_WEA_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    ADDRA                            : IN  STD_LOGIC_VECTOR(C_ADDRA_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    DINA                             : IN  STD_LOGIC_VECTOR(C_WRITE_WIDTH_A-1 DOWNTO 0) := (OTHERS => '0');
    DOUTA                            : OUT STD_LOGIC_VECTOR(C_READ_WIDTH_A-1 DOWNTO 0);
  
  --Port B:
    CLKB                             : IN  STD_LOGIC := '0';
    RSTB                             : IN  STD_LOGIC := '0';
    ENB                              : IN  STD_LOGIC := '0';
    REGCEB                           : IN  STD_LOGIC := '0';
    WEB                              : IN  STD_LOGIC_VECTOR(C_WEB_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    ADDRB                            : IN  STD_LOGIC_VECTOR(C_ADDRB_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    DINB                             : IN  STD_LOGIC_VECTOR(C_WRITE_WIDTH_B-1 DOWNTO 0) := (OTHERS => '0');
    DOUTB                            : OUT STD_LOGIC_VECTOR(C_READ_WIDTH_B-1 DOWNTO 0);
  
  --ECC:
    INJECTSBITERR                    : IN  STD_LOGIC := '0';
    INJECTDBITERR                    : IN  STD_LOGIC := '0';
    SBITERR                          : OUT STD_LOGIC;
    DBITERR                          : OUT STD_LOGIC;
    RDADDRECC                        : OUT STD_LOGIC_VECTOR(C_ADDRB_WIDTH-1 DOWNTO 0);
  -- AXI BMG Input and Output Port Declarations

    -- AXI Global Signals
    S_AClk                         : IN  STD_LOGIC := '0';
    S_ARESETN                      : IN  STD_LOGIC := '0'; 

    -- AXI Full/Lite Slave Write (write side)
    S_AXI_AWID                     : IN  STD_LOGIC_VECTOR(C_AXI_ID_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    S_AXI_AWADDR                   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    S_AXI_AWLEN                    : IN  STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    S_AXI_AWSIZE                   : IN  STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    S_AXI_AWBURST                  : IN  STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '0');
    S_AXI_AWVALID                  : IN  STD_LOGIC := '0';
    S_AXI_AWREADY                  : OUT STD_LOGIC;
    S_AXI_WDATA                    : IN  STD_LOGIC_VECTOR(C_WRITE_WIDTH_A-1 DOWNTO 0) := (OTHERS => '0');
    S_AXI_WSTRB                    : IN  STD_LOGIC_VECTOR(C_WEA_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    S_AXI_WLAST                    : IN  STD_LOGIC := '0';
    S_AXI_WVALID                   : IN  STD_LOGIC := '0';
    S_AXI_WREADY                   : OUT STD_LOGIC;
    S_AXI_BID                      : OUT  STD_LOGIC_VECTOR(C_AXI_ID_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    S_AXI_BRESP                    : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    S_AXI_BVALID                   : OUT STD_LOGIC;
    S_AXI_BREADY                   : IN  STD_LOGIC := '0';

    -- AXI Full/Lite Slave Read (Write side)
    S_AXI_ARID                     : IN  STD_LOGIC_VECTOR(C_AXI_ID_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    S_AXI_ARADDR                   : IN  STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    S_AXI_ARLEN                    : IN  STD_LOGIC_VECTOR(8-1 DOWNTO 0) := (OTHERS => '0');
    S_AXI_ARSIZE                   : IN  STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    S_AXI_ARBURST                  : IN  STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '0');
    S_AXI_ARVALID                  : IN  STD_LOGIC := '0';
    S_AXI_ARREADY                  : OUT STD_LOGIC;
    S_AXI_RID                      : OUT  STD_LOGIC_VECTOR(C_AXI_ID_WIDTH-1 DOWNTO 0) := (OTHERS => '0');
    S_AXI_RDATA                    : OUT STD_LOGIC_VECTOR(C_WRITE_WIDTH_B-1 DOWNTO 0); 
    S_AXI_RRESP                    : OUT STD_LOGIC_VECTOR(2-1 DOWNTO 0);
    S_AXI_RLAST                    : OUT STD_LOGIC;
    S_AXI_RVALID                   : OUT STD_LOGIC;
    S_AXI_RREADY                   : IN  STD_LOGIC := '0';

    -- AXI Full/Lite Sideband Signals
    S_AXI_INJECTSBITERR              : IN  STD_LOGIC := '0';
    S_AXI_INJECTDBITERR              : IN  STD_LOGIC := '0';
    S_AXI_SBITERR                    : OUT STD_LOGIC;
    S_AXI_DBITERR                    : OUT STD_LOGIC;
    S_AXI_RDADDRECC                  : OUT STD_LOGIC_VECTOR(C_ADDRB_WIDTH-1 DOWNTO 0)

  );

  END COMPONENT; --blk_mem_gen_v8_3_4

END coregen_comp_defs;


-------------------------------------------------------------------------------
-- axi_lite_if.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
-------------------------------------------------------------------------------
-- Filename:        axi_lite_if.vhd
--
-- Description:     Derived AXI-Lite interface module.
--                  
-- VHDL-Standard:   VHDL'93
--
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- checkbit_handler_64.vhd
--                      |       -- (same helper components as checkbit_handler)
--                      |   -- correct_one_bit.vhd
--                      |   -- correct_one_bit_64.vhd
--
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/1/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
--                            
--
-- 
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x" 
--      reset signals:                          "rst", "rst_n" 
--      generics:                               "C_*" 
--      user defined types:                     "*_TYPE" 
--      state machine next state:               "*_ns" 
--      state machine current state:            "*_cs" 
--      combinatorial signals:                  "*_com" 
--      pipelined or register delay signals:    "*_d#" 
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce" 
--      internal version of output port         "*_i"
--      device pins:                            "*_pin" 
--      ports:                                  - Names begin with Uppercase 
--      processes:                              "*_PROCESS" 
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;

entity axi_lite_if is
  generic (
    -- AXI4-Lite slave generics
    -- C_S_AXI_BASEADDR        : std_logic_vector       := X"FFFF_FFFF";
    -- C_S_AXI_HIGHADDR        : std_logic_vector       := X"0000_0000";
    C_S_AXI_ADDR_WIDTH      : integer                := 32;
    C_S_AXI_DATA_WIDTH      : integer                := 32;
    C_REGADDR_WIDTH         : integer                := 4;    -- Address bits including register offset.
    C_DWIDTH                : integer                := 32);  -- Width of data bus.
  port (
    LMB_Clk : in std_logic;
    LMB_Rst : in std_logic;

    -- AXI4-Lite SLAVE SINGLE INTERFACE
    S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_AWVALID : in  std_logic;
    S_AXI_AWREADY : out std_logic;
    S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    S_AXI_WVALID  : in  std_logic;
    S_AXI_WREADY  : out std_logic;
    S_AXI_BRESP   : out std_logic_vector(1 downto 0);
    S_AXI_BVALID  : out std_logic;
    S_AXI_BREADY  : in  std_logic;
    S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_ARVALID : in  std_logic;
    S_AXI_ARREADY : out std_logic;
    S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_RRESP   : out std_logic_vector(1 downto 0);
    S_AXI_RVALID  : out std_logic;
    S_AXI_RREADY  : in  std_logic;
    
    -- lmb_bram_if_cntlr signals
    RegWr         : out std_logic;
    RegWrData     : out std_logic_vector(0 to C_DWIDTH - 1);
    RegAddr       : out std_logic_vector(0 to C_REGADDR_WIDTH-1);  
    RegRdData     : in  std_logic_vector(0 to C_DWIDTH - 1));
end entity axi_lite_if;

library unisim;
use unisim.vcomponents.all;

architecture IMP of axi_lite_if is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of IMP : architecture is "yes";

  -----------------------------------------------------------------------------
  -- Signal declaration
  -----------------------------------------------------------------------------
  signal new_write_access       : std_logic;
  signal new_read_access        : std_logic;
  signal ongoing_write          : std_logic;
  signal ongoing_read           : std_logic;

  signal S_AXI_RVALID_i         : std_logic;

  signal RegRdData_i            : std_logic_vector(C_DWIDTH - 1 downto 0);

begin  -- architecture IMP

  -----------------------------------------------------------------------------
  -- Handling the AXI4-Lite bus interface (AR/AW/W)
  -----------------------------------------------------------------------------
  
  -- Detect new transaction.
  -- Only allow one access at a time
  new_write_access  <= not (ongoing_read or ongoing_write) and S_AXI_AWVALID and S_AXI_WVALID;
  new_read_access   <= not (ongoing_read or ongoing_write) and S_AXI_ARVALID and not new_write_access;

  -- Acknowledge new transaction.
  S_AXI_AWREADY <= new_write_access;
  S_AXI_WREADY  <= new_write_access;
  S_AXI_ARREADY <= new_read_access;

  -- Store register address and write data 
  Reg: process (LMB_Clk) is
  begin
    if LMB_Clk'event and LMB_Clk = '1' then
      if LMB_Rst = '1' then
        RegAddr   <= (others => '0');
        RegWrData <= (others => '0');
      elsif new_write_access = '1' then
        RegAddr   <= S_AXI_AWADDR(C_REGADDR_WIDTH-1+2 downto 2);
        RegWrData <= S_AXI_WDATA(C_DWIDTH-1 downto 0);
      elsif new_read_access = '1' then
        RegAddr   <= S_AXI_ARADDR(C_REGADDR_WIDTH-1+2 downto 2);
      end if;
    end if;
  end process Reg;
  
  -- Handle write access.
  WriteAccess: process (LMB_Clk) is
  begin
    if LMB_Clk'event and LMB_Clk = '1' then
      if LMB_Rst = '1' then
        ongoing_write <= '0';
      elsif new_write_access = '1' then
        ongoing_write <= '1';
      elsif ongoing_write = '1' and S_AXI_BREADY = '1' then
        ongoing_write <= '0';
      end if;
      RegWr <= new_write_access;
    end if;
  end process WriteAccess;

  S_AXI_BVALID <= ongoing_write;
  S_AXI_BRESP  <= (others => '0');

  -- Handle read access
  ReadAccess: process (LMB_Clk) is
  begin
    if LMB_Clk'event and LMB_Clk = '1' then
      if LMB_Rst = '1' then
        ongoing_read   <= '0';
        S_AXI_RVALID_i <= '0';
      elsif new_read_access = '1' then
        ongoing_read   <= '1';
        S_AXI_RVALID_i <= '0';
      elsif ongoing_read = '1' then
        if S_AXI_RREADY = '1' and S_AXI_RVALID_i = '1' then
          ongoing_read   <= '0';
          S_AXI_RVALID_i <= '0';
        else
          S_AXI_RVALID_i <= '1'; -- Asserted one cycle after ongoing_read to match S_AXI_RDDATA
        end if;
      end if;
    end if;
  end process ReadAccess;

  S_AXI_RVALID <= S_AXI_RVALID_i;
  S_AXI_RRESP  <= (others => '0');
  
  Not_All_Bits_Are_Used: if (C_DWIDTH < C_S_AXI_DATA_WIDTH) generate
  begin
    S_AXI_RDATA(C_S_AXI_DATA_WIDTH-1 downto C_S_AXI_DATA_WIDTH - C_DWIDTH)  <= (others=>'0');
  end generate Not_All_Bits_Are_Used;

  RegRdData_i <= RegRdData;             -- Swap to - downto
  
  S_AXI_RDATA_DFF : for I in C_DWIDTH - 1 downto 0 generate
  begin
    S_AXI_RDATA_FDRE : FDRE
      port map (
        Q  => S_AXI_RDATA(I),
        C  => LMB_Clk,
        CE => ongoing_read,
        D  => RegRdData_i(I),
        R  => LMB_Rst);
  end generate S_AXI_RDATA_DFF;
  
end architecture IMP;


-------------------------------------------------------------------------------
-- checkbit_handler_64.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
-------------------------------------------------------------------------------
-- Filename:        checkbit_handler_64.vhd
--
-- Description:     Generates the ECC checkbits for the input vector of 
--                  64-bit data widths.
--                  
-- VHDL-Standard:   VHDL'93/02
--
-------------------------------------------------------------------------------
-- Structure:   
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- checkbit_handler_64.vhd
--                      |       -- (same helper components as checkbit_handler)
--                      |   -- correct_one_bit.vhd
--                      |   -- correct_one_bit_64.vhd
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/2/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
--
--
--
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x" 
--      reset signals:                          "rst", "rst_n" 
--      generics:                               "C_*" 
--      user defined types:                     "*_TYPE" 
--      state machine next state:               "*_ns" 
--      state machine current state:            "*_cs" 
--      combinatorial signals:                  "*_com" 
--      pipelined or register delay signals:    "*_d#" 
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce" 
--      internal version of output port         "*_i"
--      device pins:                            "*_pin" 
--      ports:                                  - Names begin with Uppercase 
--      processes:                              "*_PROCESS" 
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity checkbit_handler_64 is
  generic (
    C_ENCODE   : boolean := true;
    C_REG      : boolean := false;
    C_USE_LUT6 : boolean := true);
  port (

    Clk             : in    std_logic;

    DataIn          : in  std_logic_vector (63 downto 0);
    CheckIn         : in  std_logic_vector (7 downto 0);
    CheckOut        : out std_logic_vector (7 downto 0);
    Syndrome        : out std_logic_vector (7 downto 0);
    Syndrome_7      : out std_logic_vector (11 downto 0);
    Syndrome_Chk    : in  std_logic_vector (0 to 7);    

    Enable_ECC : in  std_logic;
    UE_Q       : in  std_logic;
    CE_Q       : in  std_logic;
    UE         : out std_logic;
    CE         : out std_logic
    );
    
end entity checkbit_handler_64;

library unisim;
use unisim.vcomponents.all;

-- library axi_bram_ctrl_v1_02_a;
-- use axi_bram_ctrl_v1_02_a.all;

architecture IMP of checkbit_handler_64 is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of IMP : architecture is "yes";

  component XOR18 is
    generic (
      C_USE_LUT6 : boolean);
    port (
      InA : in  std_logic_vector(0 to 17);
      res : out std_logic);
  end component XOR18;
  
  component Parity is
    generic (
      C_USE_LUT6 : boolean;
      C_SIZE     : integer);
    port (
      InA : in  std_logic_vector(0 to C_SIZE - 1);
      Res : out std_logic);
  end component Parity;

 --    component ParityEnable
 --      generic (
 --        C_USE_LUT6 : boolean;
 --        C_SIZE     : integer);
 --      port (
 --        InA    : in  std_logic_vector(0 to C_SIZE - 1);
 --        Enable : in  std_logic;
 --        Res    : out std_logic);
 --    end component ParityEnable;
  
  
  signal data_chk0          : std_logic_vector(0 to 34);
  signal data_chk1          : std_logic_vector(0 to 34);
  signal data_chk2          : std_logic_vector(0 to 34);
  signal data_chk3          : std_logic_vector(0 to 30);
  signal data_chk4          : std_logic_vector(0 to 30);
  signal data_chk5          : std_logic_vector(0 to 30);
  
  signal data_chk6          : std_logic_vector(0 to 6);
  signal data_chk6_xor      : std_logic;
  
  -- signal data_chk7_a        : std_logic_vector(0 to 17);
  -- signal data_chk7_b        : std_logic_vector(0 to 17);
  -- signal data_chk7_i        : std_logic;
  -- signal data_chk7_xor      : std_logic;
  -- signal data_chk7_i_xor    : std_logic;
  -- signal data_chk7_a_xor      : std_logic;
  -- signal data_chk7_b_xor    : std_logic;
 
  
begin  -- architecture IMP


    -- Add bits for 64-bit ECC
    
    -- 0 <= 0 1 3 4 6 8 10 11 13 17 19 21 23 25 26 28 30 
    --      32 34 36 38 40 42 44 46 48 50 52 54 56 57 59 61 63 

  data_chk0 <= DataIn(0) & DataIn(1) & DataIn(3) & DataIn(4) & DataIn(6) & DataIn(8) & DataIn(10) &
               DataIn(11) & DataIn(13) & DataIn(15) & DataIn(17) & DataIn(19) & DataIn(21) &
               DataIn(23) & DataIn(25) & DataIn(26) & DataIn(28) & DataIn(30) &
               
               DataIn(32) & DataIn(34) & DataIn(36) & DataIn(38) & DataIn(40) & 
               DataIn(42) & DataIn(44) & DataIn(46) & DataIn(48) & DataIn(50) & 
               DataIn(52) & DataIn(54) & DataIn(56) & DataIn(57) & DataIn(59) & 
               DataIn(61) & DataIn(63) ;

    -- 18 + 17 = 35

    ---------------------------------------------------------------------------


    -- 1 <= 0 2 3 5 6 9 10 12 13 16 17 20 21 24 25 27 28 31
    --      32 35 36 39 40 43 44 47 48 51 52 55 56 58 59 62 63


  data_chk1 <= DataIn(0) & DataIn(2) & DataIn(3) & DataIn(5) & DataIn(6) & DataIn(9) & DataIn(10) &
               DataIn(12) & DataIn(13) & DataIn(16) & DataIn(17) & DataIn(20) & DataIn(21) &
               DataIn(24) & DataIn(25) & DataIn(27) & DataIn(28) & DataIn(31) &
               
                 DataIn(32) & DataIn(35) & DataIn(36) & DataIn(39) & DataIn(40) &
                 DataIn(43) & DataIn(44) & DataIn(47) & DataIn(48) & DataIn(51) &
                 DataIn(52) & DataIn(55) & DataIn(56) & DataIn(58) & DataIn(59) &
                 DataIn(62) & DataIn(63) ;

    -- 18 + 17 = 35

    ---------------------------------------------------------------------------
               
               
    -- 2 <=   1 2 3 7 8 9 10 14 15 16 17 22 23 24 25 29 30 31
    --        32 37 38 39 40 45 46 47 48 53 54 55 56 60 61 62 63 
               
  data_chk2 <= DataIn(1) & DataIn(2) & DataIn(3) & DataIn(7) & DataIn(8) & DataIn(9) & DataIn(10) &
               DataIn(14) & DataIn(15) & DataIn(16) & DataIn(17) & DataIn(22) & DataIn(23) & DataIn(24) &
               DataIn(25) & DataIn(29) & DataIn(30) & DataIn(31) &
               
               DataIn(32) & DataIn(37) & DataIn(38) & DataIn(39) & DataIn(40) & DataIn(45) &
               DataIn(46) & DataIn(47) & DataIn(48) & DataIn(53) & DataIn(54) & DataIn(55) &
               DataIn(56) & DataIn(60) & DataIn(61) & DataIn(62) & DataIn(63) ;

    -- 18 + 17 = 35

    ---------------------------------------------------------------------------


    -- 3 <= 4 5 6 7 8 9 10 18 19 20 21 22 23 24 25
    --      33 34 35 36 37 38 39 40 49 50 51 52 53 54 55 56

  data_chk3 <= DataIn(4) & DataIn(5) & DataIn(6) & DataIn(7) & DataIn(8) & DataIn(9) & DataIn(10) &
               DataIn(18) & DataIn(19) & DataIn(20) & DataIn(21) & DataIn(22) & DataIn(23) & DataIn(24) &
               DataIn(25) &
               
               DataIn(33) & DataIn(34) & DataIn(35) & DataIn(36) & DataIn(37) & DataIn(38) & DataIn(39) &
               DataIn(40) & DataIn(49) & DataIn(50) & DataIn(51) & DataIn(52) & DataIn(53) & DataIn(54) &
               DataIn(55) & DataIn(56) ;

    -- 15 + 16 = 31

    ---------------------------------------------------------------------------


    -- 4 <= 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25
    --      41-56

  data_chk4 <= DataIn(11) & DataIn(12) & DataIn(13) & DataIn(14) & DataIn(15) & DataIn(16) & DataIn(17) &
               DataIn(18) & DataIn(19) & DataIn(20) & DataIn(21) & DataIn(22) & DataIn(23) & DataIn(24) &
               DataIn(25) &
               
               DataIn(41) & DataIn(42) & DataIn(43) & DataIn(44) & DataIn(45) & DataIn(46) & DataIn(47) &
               DataIn(48) & DataIn(49) & DataIn(50) & DataIn(51) & DataIn(52) & DataIn(53) & DataIn(54) &
               DataIn(55) & DataIn(56) ;

    -- 15 + 16 = 31

    ---------------------------------------------------------------------------


    -- 5 <= 26 - 31
    --      32 - 56

  data_chk5   <= DataIn(26) & DataIn(27) & DataIn(28) & DataIn(29) & DataIn(30) & DataIn(31) &  
                 DataIn(32) & DataIn(33) & DataIn(34) & DataIn(35) & DataIn(36) & DataIn(37) & 
                 DataIn(38) & DataIn(39) & DataIn(40) & DataIn(41) & DataIn(42) & DataIn(43) &
               
                 DataIn(44) & DataIn(45) & DataIn(46) & DataIn(47) & DataIn(48) & DataIn(49) & 
                 DataIn(50) & DataIn(51) & DataIn(52) & DataIn(53) & DataIn(54) & DataIn(55) & 
                 DataIn(56) ;


    -- 18 + 13 = 31

    ---------------------------------------------------------------------------


    -- New additional checkbit for 64-bit data
    -- 6 <= 57 - 63

  data_chk6   <= DataIn(57) & DataIn(58) & DataIn(59) & DataIn(60) & DataIn(61) & DataIn(62) &
               DataIn(63) ;




  -- Encode bits for writing data
  Encode_Bits : if (C_ENCODE) generate

  -- signal data_chk0_i        : std_logic_vector(0 to 17);
  -- signal data_chk0_xor      : std_logic;
  -- signal data_chk0_i_xor    : std_logic;

  -- signal data_chk1_i        : std_logic_vector(0 to 17);
  -- signal data_chk1_xor      : std_logic;
  -- signal data_chk1_i_xor    : std_logic;

  -- signal data_chk2_i        : std_logic_vector(0 to 17);
  -- signal data_chk2_xor      : std_logic;
  -- signal data_chk2_i_xor    : std_logic;

  -- signal data_chk3_i        : std_logic_vector(0 to 17);
  -- signal data_chk3_xor      : std_logic;
  -- signal data_chk3_i_xor    : std_logic;

  -- signal data_chk4_i        : std_logic_vector(0 to 17);
  -- signal data_chk4_xor      : std_logic;
  -- signal data_chk4_i_xor    : std_logic;

  -- signal data_chk5_i        : std_logic_vector(0 to 17);
  -- signal data_chk5_xor      : std_logic;
  -- signal data_chk5_i_xor    : std_logic;
  
  -- signal data_chk6_i        : std_logic;


  -- signal data_chk0_xor_reg    : std_logic;          
  -- signal data_chk0_i_xor_reg  : std_logic;          
  -- signal data_chk1_xor_reg    : std_logic;          
  -- signal data_chk1_i_xor_reg  : std_logic;          
  -- signal data_chk2_xor_reg    : std_logic;          
  -- signal data_chk2_i_xor_reg  : std_logic;          
  -- signal data_chk3_xor_reg    : std_logic;          
  -- signal data_chk3_i_xor_reg  : std_logic;          
  -- signal data_chk4_xor_reg    : std_logic;          
  -- signal data_chk4_i_xor_reg  : std_logic;          
  -- signal data_chk5_xor_reg    : std_logic;          
  -- signal data_chk5_i_xor_reg  : std_logic;          
  -- signal data_chk6_i_reg      : std_logic;          
  -- signal data_chk7_a_xor_reg  : std_logic;          
  -- signal data_chk7_b_xor_reg  : std_logic;          


  -- Checkbit (0)
  signal data_chk0_a           : std_logic_vector (0 to 5);  
  signal data_chk0_b           : std_logic_vector (0 to 5);  
  signal data_chk0_c           : std_logic_vector (0 to 5);  
  signal data_chk0_d           : std_logic_vector (0 to 5);  
  signal data_chk0_e           : std_logic_vector (0 to 5);  
  signal data_chk0_f           : std_logic_vector (0 to 4);  
  
  signal data_chk0_a_xor       : std_logic;  
  signal data_chk0_b_xor       : std_logic;  
  signal data_chk0_c_xor       : std_logic;  
  signal data_chk0_d_xor       : std_logic;  
  signal data_chk0_e_xor       : std_logic;  
  signal data_chk0_f_xor       : std_logic;  

  signal data_chk0_a_xor_reg   : std_logic;  
  signal data_chk0_b_xor_reg   : std_logic;  
  signal data_chk0_c_xor_reg   : std_logic;  
  signal data_chk0_d_xor_reg   : std_logic;  
  signal data_chk0_e_xor_reg   : std_logic;  
  signal data_chk0_f_xor_reg   : std_logic;  
  
  
  -- Checkbit (1)
  signal data_chk1_a           : std_logic_vector (0 to 5);  
  signal data_chk1_b           : std_logic_vector (0 to 5);  
  signal data_chk1_c           : std_logic_vector (0 to 5);  
  signal data_chk1_d           : std_logic_vector (0 to 5);  
  signal data_chk1_e           : std_logic_vector (0 to 5);  
  signal data_chk1_f           : std_logic_vector (0 to 4);  
  
  signal data_chk1_a_xor       : std_logic;  
  signal data_chk1_b_xor       : std_logic;  
  signal data_chk1_c_xor       : std_logic;  
  signal data_chk1_d_xor       : std_logic;  
  signal data_chk1_e_xor       : std_logic;  
  signal data_chk1_f_xor       : std_logic;  

  signal data_chk1_a_xor_reg   : std_logic;  
  signal data_chk1_b_xor_reg   : std_logic;  
  signal data_chk1_c_xor_reg   : std_logic;  
  signal data_chk1_d_xor_reg   : std_logic;  
  signal data_chk1_e_xor_reg   : std_logic;  
  signal data_chk1_f_xor_reg   : std_logic;  


  -- Checkbit (2)
  signal data_chk2_a           : std_logic_vector (0 to 5);  
  signal data_chk2_b           : std_logic_vector (0 to 5);  
  signal data_chk2_c           : std_logic_vector (0 to 5);  
  signal data_chk2_d           : std_logic_vector (0 to 5);  
  signal data_chk2_e           : std_logic_vector (0 to 5);  
  signal data_chk2_f           : std_logic_vector (0 to 4);  
  
  signal data_chk2_a_xor       : std_logic;  
  signal data_chk2_b_xor       : std_logic;  
  signal data_chk2_c_xor       : std_logic;  
  signal data_chk2_d_xor       : std_logic;  
  signal data_chk2_e_xor       : std_logic;  
  signal data_chk2_f_xor       : std_logic;  

  signal data_chk2_a_xor_reg   : std_logic;  
  signal data_chk2_b_xor_reg   : std_logic;  
  signal data_chk2_c_xor_reg   : std_logic;  
  signal data_chk2_d_xor_reg   : std_logic;  
  signal data_chk2_e_xor_reg   : std_logic;  
  signal data_chk2_f_xor_reg   : std_logic;  


  -- Checkbit (3)
  signal data_chk3_a           : std_logic_vector (0 to 5);  
  signal data_chk3_b           : std_logic_vector (0 to 5);  
  signal data_chk3_c           : std_logic_vector (0 to 5);  
  signal data_chk3_d           : std_logic_vector (0 to 5);  
  signal data_chk3_e           : std_logic_vector (0 to 5);  
  
  signal data_chk3_a_xor       : std_logic;  
  signal data_chk3_b_xor       : std_logic;  
  signal data_chk3_c_xor       : std_logic;  
  signal data_chk3_d_xor       : std_logic;  
  signal data_chk3_e_xor       : std_logic;  
  signal data_chk3_f_xor       : std_logic;  
  
  signal data_chk3_a_xor_reg   : std_logic;  
  signal data_chk3_b_xor_reg   : std_logic;  
  signal data_chk3_c_xor_reg   : std_logic;  
  signal data_chk3_d_xor_reg   : std_logic;  
  signal data_chk3_e_xor_reg   : std_logic;  
  signal data_chk3_f_xor_reg   : std_logic;  


  -- Checkbit (4)
  signal data_chk4_a           : std_logic_vector (0 to 5);  
  signal data_chk4_b           : std_logic_vector (0 to 5);  
  signal data_chk4_c           : std_logic_vector (0 to 5);  
  signal data_chk4_d           : std_logic_vector (0 to 5);  
  signal data_chk4_e           : std_logic_vector (0 to 5);  
  
  signal data_chk4_a_xor       : std_logic;  
  signal data_chk4_b_xor       : std_logic;  
  signal data_chk4_c_xor       : std_logic;  
  signal data_chk4_d_xor       : std_logic;  
  signal data_chk4_e_xor       : std_logic;  
  signal data_chk4_f_xor       : std_logic;  
  
  signal data_chk4_a_xor_reg   : std_logic;  
  signal data_chk4_b_xor_reg   : std_logic;  
  signal data_chk4_c_xor_reg   : std_logic;  
  signal data_chk4_d_xor_reg   : std_logic;  
  signal data_chk4_e_xor_reg   : std_logic;  
  signal data_chk4_f_xor_reg   : std_logic;  

  
  -- Checkbit (5)
  signal data_chk5_a           : std_logic_vector (0 to 5);  
  signal data_chk5_b           : std_logic_vector (0 to 5);  
  signal data_chk5_c           : std_logic_vector (0 to 5);  
  signal data_chk5_d           : std_logic_vector (0 to 5);  
  signal data_chk5_e           : std_logic_vector (0 to 5);  
  
  signal data_chk5_a_xor       : std_logic;  
  signal data_chk5_b_xor       : std_logic;  
  signal data_chk5_c_xor       : std_logic;  
  signal data_chk5_d_xor       : std_logic;  
  signal data_chk5_e_xor       : std_logic;  
  signal data_chk5_f_xor       : std_logic;  
  
  signal data_chk5_a_xor_reg   : std_logic;  
  signal data_chk5_b_xor_reg   : std_logic;  
  signal data_chk5_c_xor_reg   : std_logic;  
  signal data_chk5_d_xor_reg   : std_logic;  
  signal data_chk5_e_xor_reg   : std_logic;  
  signal data_chk5_f_xor_reg   : std_logic;  
  

  -- Checkbit (6)
  signal data_chk6_a            : std_logic; 
  signal data_chk6_b            : std_logic; 

  signal data_chk6_a_reg        : std_logic; 
  signal data_chk6_b_reg        : std_logic; 


  -- Checkbit (7)
  signal data_chk7_a            : std_logic_vector (0 to 5);     
  signal data_chk7_b            : std_logic_vector (0 to 5);     
  signal data_chk7_c            : std_logic_vector (0 to 5);     
  signal data_chk7_d            : std_logic_vector (0 to 5);     
  signal data_chk7_e            : std_logic_vector (0 to 5);     
  signal data_chk7_f            : std_logic_vector (0 to 4);     

  signal data_chk7_a_xor        : std_logic;     
  signal data_chk7_b_xor        : std_logic;     
  signal data_chk7_c_xor        : std_logic;     
  signal data_chk7_d_xor        : std_logic;     
  signal data_chk7_e_xor        : std_logic;     
  signal data_chk7_f_xor        : std_logic;     

  signal data_chk7_a_xor_reg   : std_logic;  
  signal data_chk7_b_xor_reg   : std_logic;  
  signal data_chk7_c_xor_reg   : std_logic;  
  signal data_chk7_d_xor_reg   : std_logic;  
  signal data_chk7_e_xor_reg   : std_logic;  
  signal data_chk7_f_xor_reg   : std_logic;  



  begin
  
      -----------------------------------------------------------------------------
      -- For timing improvements, if check bit XOR logic
      -- needs to be pipelined.  Add register level here
      -- after 1st LUT level.
  
      REG_BITS : if (C_REG) generate
      begin
          REG_CHK: process (Clk)
          begin    
              if (Clk'event and Clk = '1' ) then
                -- Checkbit (0)
                -- data_chk0_xor_reg   <= data_chk0_xor;
                -- data_chk0_i_xor_reg <= data_chk0_i_xor;
                
                data_chk0_a_xor_reg <= data_chk0_a_xor;
                data_chk0_b_xor_reg <= data_chk0_b_xor;
                data_chk0_c_xor_reg <= data_chk0_c_xor;
                data_chk0_d_xor_reg <= data_chk0_d_xor;
                data_chk0_e_xor_reg <= data_chk0_e_xor;
                data_chk0_f_xor_reg <= data_chk0_f_xor;
                
                
                
                -- Checkbit (1)
                -- data_chk1_xor_reg   <= data_chk1_xor;
                -- data_chk1_i_xor_reg <= data_chk1_i_xor;

                data_chk1_a_xor_reg <= data_chk1_a_xor;
                data_chk1_b_xor_reg <= data_chk1_b_xor;
                data_chk1_c_xor_reg <= data_chk1_c_xor;
                data_chk1_d_xor_reg <= data_chk1_d_xor;
                data_chk1_e_xor_reg <= data_chk1_e_xor;
                data_chk1_f_xor_reg <= data_chk1_f_xor;


                -- Checkbit (2)
                -- data_chk2_xor_reg   <= data_chk2_xor;
                -- data_chk2_i_xor_reg <= data_chk2_i_xor;
                
                data_chk2_a_xor_reg <= data_chk2_a_xor;
                data_chk2_b_xor_reg <= data_chk2_b_xor;
                data_chk2_c_xor_reg <= data_chk2_c_xor;
                data_chk2_d_xor_reg <= data_chk2_d_xor;
                data_chk2_e_xor_reg <= data_chk2_e_xor;
                data_chk2_f_xor_reg <= data_chk2_f_xor;

                
                
                
                -- Checkbit (3)
                -- data_chk3_xor_reg   <= data_chk3_xor;
                -- data_chk3_i_xor_reg <= data_chk3_i_xor;
                
                data_chk3_a_xor_reg <= data_chk3_a_xor;
                data_chk3_b_xor_reg <= data_chk3_b_xor;
                data_chk3_c_xor_reg <= data_chk3_c_xor;
                data_chk3_d_xor_reg <= data_chk3_d_xor;
                data_chk3_e_xor_reg <= data_chk3_e_xor;
                data_chk3_f_xor_reg <= data_chk3_f_xor;
                
                
                
                
                -- Checkbit (4)
                -- data_chk4_xor_reg   <= data_chk4_xor;
                -- data_chk4_i_xor_reg <= data_chk4_i_xor;
                
                data_chk4_a_xor_reg <= data_chk4_a_xor;
                data_chk4_b_xor_reg <= data_chk4_b_xor;
                data_chk4_c_xor_reg <= data_chk4_c_xor;
                data_chk4_d_xor_reg <= data_chk4_d_xor;
                data_chk4_e_xor_reg <= data_chk4_e_xor;
                data_chk4_f_xor_reg <= data_chk4_f_xor;
                
                
                -- Checkbit (5)
                -- data_chk5_xor_reg   <= data_chk5_xor;
                -- data_chk5_i_xor_reg <= data_chk5_i_xor;
 
                 data_chk5_a_xor_reg <= data_chk5_a_xor;
                 data_chk5_b_xor_reg <= data_chk5_b_xor;
                 data_chk5_c_xor_reg <= data_chk5_c_xor;
                 data_chk5_d_xor_reg <= data_chk5_d_xor;
                 data_chk5_e_xor_reg <= data_chk5_e_xor;
                 data_chk5_f_xor_reg <= data_chk5_f_xor;

                
                -- Checkbit (6)
                -- data_chk6_i_reg     <= data_chk6_i;
                data_chk6_a_reg <= data_chk6_a;
                data_chk6_b_reg <= data_chk6_b;
                

                -- Checkbit (7)
                -- data_chk7_a_xor_reg <= data_chk7_a_xor;
                -- data_chk7_b_xor_reg <= data_chk7_b_xor;

                data_chk7_a_xor_reg <= data_chk7_a_xor;
                data_chk7_b_xor_reg <= data_chk7_b_xor;
                data_chk7_c_xor_reg <= data_chk7_c_xor;
                data_chk7_d_xor_reg <= data_chk7_d_xor;
                data_chk7_e_xor_reg <= data_chk7_e_xor;
                data_chk7_f_xor_reg <= data_chk7_f_xor;
                
              end if;
              
          end process REG_CHK;


          -- Perform the last XOR after the register stage
          -- CheckOut(0) <= data_chk0_xor_reg xor data_chk0_i_xor_reg;
          
          CheckOut(0) <= data_chk0_a_xor_reg xor 
                         data_chk0_b_xor_reg xor
                         data_chk0_c_xor_reg xor 
                         data_chk0_d_xor_reg xor 
                         data_chk0_e_xor_reg xor 
                         data_chk0_f_xor_reg;
          
          
          -- CheckOut(1) <= data_chk1_xor_reg xor data_chk1_i_xor_reg;
          
          CheckOut(1) <= data_chk1_a_xor_reg xor 
                         data_chk1_b_xor_reg xor
                         data_chk1_c_xor_reg xor 
                         data_chk1_d_xor_reg xor 
                         data_chk1_e_xor_reg xor 
                         data_chk1_f_xor_reg;
          
          
          
          
          -- CheckOut(2) <= data_chk2_xor_reg xor data_chk2_i_xor_reg;

          CheckOut(2) <= data_chk2_a_xor_reg xor 
                         data_chk2_b_xor_reg xor
                         data_chk2_c_xor_reg xor 
                         data_chk2_d_xor_reg xor 
                         data_chk2_e_xor_reg xor 
                         data_chk2_f_xor_reg;
          
          
          -- CheckOut(3) <= data_chk3_xor_reg xor data_chk3_i_xor_reg;
          
          CheckOut(3) <= data_chk3_a_xor_reg xor 
                         data_chk3_b_xor_reg xor
                         data_chk3_c_xor_reg xor 
                         data_chk3_d_xor_reg xor 
                         data_chk3_e_xor_reg xor 
                         data_chk3_f_xor_reg;
          
          
          -- CheckOut(4) <= data_chk4_xor_reg xor data_chk4_i_xor_reg;

          CheckOut(4) <= data_chk4_a_xor_reg xor 
                         data_chk4_b_xor_reg xor
                         data_chk4_c_xor_reg xor 
                         data_chk4_d_xor_reg xor 
                         data_chk4_e_xor_reg xor 
                         data_chk4_f_xor_reg;

          -- CheckOut(5) <= data_chk5_xor_reg xor data_chk5_i_xor_reg;

          CheckOut(5) <= data_chk5_a_xor_reg xor 
                         data_chk5_b_xor_reg xor
                         data_chk5_c_xor_reg xor 
                         data_chk5_d_xor_reg xor 
                         data_chk5_e_xor_reg xor 
                         data_chk5_f_xor_reg;
          
          
          -- CheckOut(6) <= data_chk6_i_reg;
          CheckOut(6) <= data_chk6_a_reg xor data_chk6_b_reg;
          
          -- CheckOut(7) <= data_chk7_a_xor_reg xor data_chk7_b_xor_reg;
          CheckOut(7) <= data_chk7_a_xor_reg xor 
                         data_chk7_b_xor_reg xor
                         data_chk7_c_xor_reg xor 
                         data_chk7_d_xor_reg xor 
                         data_chk7_e_xor_reg xor 
                         data_chk7_f_xor_reg;

      
      end generate REG_BITS;
  
      NO_REG_BITS: if (not C_REG) generate
      begin
          -- CheckOut(0) <= data_chk0_xor xor data_chk0_i_xor;
          
          CheckOut(0) <= data_chk0_a_xor xor 
                         data_chk0_b_xor xor
                         data_chk0_c_xor xor 
                         data_chk0_d_xor xor 
                         data_chk0_e_xor xor 
                         data_chk0_f_xor;         
          
          -- CheckOut(1) <= data_chk1_xor xor data_chk1_i_xor;

          CheckOut(1) <= data_chk1_a_xor xor 
                         data_chk1_b_xor xor
                         data_chk1_c_xor xor 
                         data_chk1_d_xor xor 
                         data_chk1_e_xor xor 
                         data_chk1_f_xor;         


          -- CheckOut(2) <= data_chk2_xor xor data_chk2_i_xor;

          CheckOut(2) <= data_chk2_a_xor xor 
                         data_chk2_b_xor xor
                         data_chk2_c_xor xor 
                         data_chk2_d_xor xor 
                         data_chk2_e_xor xor 
                         data_chk2_f_xor;         

          -- CheckOut(3) <= data_chk3_xor xor data_chk3_i_xor;

          CheckOut(3) <= data_chk3_a_xor xor 
                         data_chk3_b_xor xor
                         data_chk3_c_xor xor 
                         data_chk3_d_xor xor 
                         data_chk3_e_xor xor 
                         data_chk3_f_xor;         


          -- CheckOut(4) <= data_chk4_xor xor data_chk4_i_xor;

          CheckOut(4) <= data_chk4_a_xor xor 
                         data_chk4_b_xor xor
                         data_chk4_c_xor xor 
                         data_chk4_d_xor xor 
                         data_chk4_e_xor xor 
                         data_chk4_f_xor;         

          -- CheckOut(5) <= data_chk5_xor xor data_chk5_i_xor;
          
          CheckOut(5) <= data_chk5_a_xor xor 
                         data_chk5_b_xor xor
                         data_chk5_c_xor xor 
                         data_chk5_d_xor xor 
                         data_chk5_e_xor xor 
                         data_chk5_f_xor;         
          
          
          
          -- CheckOut(6) <= data_chk6_i;
          CheckOut(6) <= data_chk6_a xor data_chk6_b;
          
          -- CheckOut(7) <= data_chk7_a_xor xor data_chk7_b_xor;
          CheckOut(7) <= data_chk7_a_xor xor 
                         data_chk7_b_xor xor
                         data_chk7_c_xor xor 
                         data_chk7_d_xor xor 
                         data_chk7_e_xor xor 
                         data_chk7_f_xor;


      end generate NO_REG_BITS;
  
      -----------------------------------------------------------------------------

  
  
    -------------------------------------------------------------------------------
    -- Checkbit 0 built up using 2x XOR18
    -------------------------------------------------------------------------------

    --     XOR18_I0_A : XOR18
    --       generic map (
    --         C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --       port map (
    --         InA => data_chk0 (0 to 17),         -- [in  std_logic_vector(0 to 17)]
    --         res => data_chk0_xor);              -- [out std_logic]
    --     
    --     data_chk0_i <= data_chk0 (18 to 34) & '0';
    --     
    --     XOR18_I0_B : XOR18
    --       generic map (
    --         C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --       port map (
    --         InA => data_chk0_i,                 -- [in  std_logic_vector(0 to 17)]
    --         res => data_chk0_i_xor);            -- [out std_logic]
    --     
    --     -- CheckOut(0) <= data_chk0_xor xor data_chk0_i_xor;
    
    -- Push register stage to earlier in ECC XOR logic stages (when enabled, C_REG)
    
    data_chk0_a <= data_chk0 (0 to 5);
    data_chk0_b <= data_chk0 (6 to 11);
    data_chk0_c <= data_chk0 (12 to 17);
    data_chk0_d <= data_chk0 (18 to 23);
    data_chk0_e <= data_chk0 (24 to 29);
    data_chk0_f <= data_chk0 (30 to 34);
    
    PARITY_CHK0_A : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk0_a (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk0_a_xor );           -- [out std_logic]
    
    PARITY_CHK0_B : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk0_b (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk0_b_xor );           -- [out std_logic]
    
    PARITY_CHK0_C : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk0_c (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk0_c_xor );           -- [out std_logic]
    
    PARITY_CHK0_D : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk0_d (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk0_d_xor );           -- [out std_logic]
    
    PARITY_CHK0_E : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk0_e (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk0_e_xor );           -- [out std_logic]
    
    PARITY_CHK0_F : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 5)
    port map (
        InA => data_chk0_f (0 to 4),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk0_f_xor );           -- [out std_logic]
    
    


    -------------------------------------------------------------------------------
    -- Checkbit 1 built up using 2x XOR18
    -------------------------------------------------------------------------------
    
    --     XOR18_I1_A : XOR18
    --      generic map (
    --        C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --      port map (
    --        InA => data_chk1 (0 to 17),         -- [in  std_logic_vector(0 to 17)]
    --        res => data_chk1_xor);              -- [out std_logic]
    --     
    --     data_chk1_i <= data_chk1 (18 to 34) & '0';
    --     
    --     XOR18_I1_B : XOR18
    --      generic map (
    --        C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --      port map (
    --        InA => data_chk1_i,                 -- [in  std_logic_vector(0 to 17)]
    --        res => data_chk1_i_xor);            -- [out std_logic]
    --     
    --     -- CheckOut(1) <= data_chk1_xor xor data_chk1_i_xor;


    -- Push register stage to earlier in ECC XOR logic stages (when enabled, C_REG)
    
    data_chk1_a <= data_chk1 (0 to 5);
    data_chk1_b <= data_chk1 (6 to 11);
    data_chk1_c <= data_chk1 (12 to 17);
    data_chk1_d <= data_chk1 (18 to 23);
    data_chk1_e <= data_chk1 (24 to 29);
    data_chk1_f <= data_chk1 (30 to 34);
    
    PARITY_chk1_A : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk1_a (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk1_a_xor );           -- [out std_logic]
    
    PARITY_chk1_B : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk1_b (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk1_b_xor );           -- [out std_logic]
    
    PARITY_chk1_C : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk1_c (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk1_c_xor );           -- [out std_logic]
    
    PARITY_chk1_D : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk1_d (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk1_d_xor );           -- [out std_logic]
    
    PARITY_chk1_E : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk1_e (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk1_e_xor );           -- [out std_logic]
    
    PARITY_chk1_F : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 5)
    port map (
        InA => data_chk1_f (0 to 4),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk1_f_xor );           -- [out std_logic]
    
    




    ------------------------------------------------------------------------------------------------
    -- Checkbit 2 built up using 2x XOR18
    ------------------------------------------------------------------------------------------------
    
    --     XOR18_I2_A : XOR18
    --       generic map (
    --         C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --       port map (
    --         InA => data_chk2 (0 to 17),         -- [in  std_logic_vector(0 to 17)]
    --         res => data_chk2_xor);              -- [out std_logic]
    --     
    --     data_chk2_i <= data_chk2 (18 to 34) & '0';
    --     
    --     XOR18_I2_B : XOR18
    --       generic map (
    --         C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --       port map (
    --         InA => data_chk2_i,                   -- [in  std_logic_vector(0 to 17)]
    --         res => data_chk2_i_xor);            -- [out std_logic]
    --     
    --     -- CheckOut(2) <= data_chk2_xor xor data_chk2_i_xor;



    -- Push register stage to earlier in ECC XOR logic stages (when enabled, C_REG)
    
    data_chk2_a <= data_chk2 (0 to 5);
    data_chk2_b <= data_chk2 (6 to 11);
    data_chk2_c <= data_chk2 (12 to 17);
    data_chk2_d <= data_chk2 (18 to 23);
    data_chk2_e <= data_chk2 (24 to 29);
    data_chk2_f <= data_chk2 (30 to 34);
    
    PARITY_chk2_A : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk2_a (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk2_a_xor );           -- [out std_logic]
    
    PARITY_chk2_B : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk2_b (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk2_b_xor );           -- [out std_logic]
    
    PARITY_chk2_C : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk2_c (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk2_c_xor );           -- [out std_logic]
    
    PARITY_chk2_D : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk2_d (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk2_d_xor );           -- [out std_logic]
    
    PARITY_chk2_E : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk2_e (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk2_e_xor );           -- [out std_logic]
    
    PARITY_chk2_F : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 5)
    port map (
        InA => data_chk2_f (0 to 4),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk2_f_xor );           -- [out std_logic]
    
    



    ------------------------------------------------------------------------------------------------
    -- Checkbit 3 built up using 2x XOR18
    ------------------------------------------------------------------------------------------------   

    --     XOR18_I3_A : XOR18
    --       generic map (
    --         C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --       port map (
    --         InA => data_chk3 (0 to 17),         -- [in  std_logic_vector(0 to 17)]
    --         res => data_chk3_xor);              -- [out std_logic]
    --     
    --     data_chk3_i <= data_chk3 (18 to 30) & "00000";
    --     
    --     XOR18_I3_B : XOR18
    --       generic map (
    --         C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --       port map (
    --         InA => data_chk3_i,                 -- [in  std_logic_vector(0 to 17)]
    --         res => data_chk3_i_xor);            -- [out std_logic]
    --     
    --     -- CheckOut(3) <= data_chk3_xor xor data_chk3_i_xor;


    -- Push register stage to earlier in ECC XOR logic stages (when enabled, C_REG)
    
    data_chk3_a <= data_chk3 (0 to 5);
    data_chk3_b <= data_chk3 (6 to 11);
    data_chk3_c <= data_chk3 (12 to 17);
    data_chk3_d <= data_chk3 (18 to 23);
    data_chk3_e <= data_chk3 (24 to 29);
    
    data_chk3_f_xor <= data_chk3 (30);
    
    PARITY_chk3_A : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk3_a (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk3_a_xor );           -- [out std_logic]
    
    PARITY_chk3_B : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk3_b (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk3_b_xor );           -- [out std_logic]
    
    PARITY_chk3_C : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk3_c (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk3_c_xor );           -- [out std_logic]
    
    PARITY_chk3_D : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk3_d (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk3_d_xor );           -- [out std_logic]
    
    PARITY_chk3_E : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk3_e (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk3_e_xor );           -- [out std_logic]
        
    


    ------------------------------------------------------------------------------------------------
    -- Checkbit 4 built up using 2x XOR18
    ------------------------------------------------------------------------------------------------
    
    --     XOR18_I4_A : XOR18
    --       generic map (
    --         C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --       port map (
    --         InA => data_chk4 (0 to 17),         -- [in  std_logic_vector(0 to 17)]
    --         res => data_chk4_xor);              -- [out std_logic]
    --     
    --     data_chk4_i <= data_chk4 (18 to 30) & "00000";
    --     
    --     XOR18_I4_B : XOR18
    --       generic map (
    --         C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --       port map (
    --         InA => data_chk4_i,                 -- [in  std_logic_vector(0 to 17)]
    --         res => data_chk4_i_xor);            -- [out std_logic]
    --     
    --     -- CheckOut(4) <= data_chk4_xor xor data_chk4_i_xor;



    -- Push register stage to earlier in ECC XOR logic stages (when enabled, C_REG)
    
    data_chk4_a <= data_chk4 (0 to 5);
    data_chk4_b <= data_chk4 (6 to 11);
    data_chk4_c <= data_chk4 (12 to 17);
    data_chk4_d <= data_chk4 (18 to 23);
    data_chk4_e <= data_chk4 (24 to 29);
    
    data_chk4_f_xor <= data_chk4 (30);
    
    PARITY_chk4_A : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk4_a (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk4_a_xor );           -- [out std_logic]
    
    PARITY_chk4_B : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk4_b (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk4_b_xor );           -- [out std_logic]
    
    PARITY_chk4_C : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk4_c (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk4_c_xor );           -- [out std_logic]
    
    PARITY_chk4_D : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk4_d (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk4_d_xor );           -- [out std_logic]
    
    PARITY_chk4_E : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk4_e (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk4_e_xor );           -- [out std_logic]
        
    



    ------------------------------------------------------------------------------------------------
    -- Checkbit 5 built up using 2x XOR18
    ------------------------------------------------------------------------------------------------   

    --     XOR18_I5_A : XOR18
    --       generic map (
    --         C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --       port map (
    --         InA => data_chk5 (0 to 17),         -- [in  std_logic_vector(0 to 17)]
    --         res => data_chk5_xor);              -- [out std_logic]
    --     
    --     data_chk5_i <= data_chk5 (18 to 30) & "00000";
    --     
    --     XOR18_I5_B : XOR18
    --       generic map (
    --         C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --       port map (
    --         InA => data_chk5_i,                 -- [in  std_logic_vector(0 to 17)]
    --         res => data_chk5_i_xor);            -- [out std_logic]
    --     
    --     -- CheckOut(5) <= data_chk5_xor xor data_chk5_i_xor;


    -- Push register stage to earlier in ECC XOR logic stages (when enabled, C_REG)
    
    data_chk5_a <= data_chk5 (0 to 5);
    data_chk5_b <= data_chk5 (6 to 11);
    data_chk5_c <= data_chk5 (12 to 17);
    data_chk5_d <= data_chk5 (18 to 23);
    data_chk5_e <= data_chk5 (24 to 29);
    
    data_chk5_f_xor <= data_chk5 (30);
    
    PARITY_chk5_A : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk5_a (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk5_a_xor );           -- [out std_logic]
    
    PARITY_chk5_B : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk5_b (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk5_b_xor );           -- [out std_logic]
    
    PARITY_chk5_C : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk5_c (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk5_c_xor );           -- [out std_logic]
    
    PARITY_chk5_D : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk5_d (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk5_d_xor );           -- [out std_logic]
    
    PARITY_chk5_E : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk5_e (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk5_e_xor );           -- [out std_logic]
        
    





    ------------------------------------------------------------------------------------------------
    -- Checkbit 6 built up from 1 LUT6 + 1 XOR
    ------------------------------------------------------------------------------------------------
    Parity_chk6_I : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk6 (0 to 5),              -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk6_xor);                  -- [out std_logic]
    
    -- data_chk6_i <= data_chk6_xor xor data_chk6(6);
    -- Push register stage to 1st ECC XOR logic stage (when enabled, C_REG)
    data_chk6_a <= data_chk6_xor;
    data_chk6_b <= data_chk6(6);


    -- CheckOut(6) <= data_chk6_xor xor data_chk6(6);
    -- CheckOut(6) <= data_chk6_i;
    
    
    
    
    
    
    -- Overall checkbit 
    -- New checkbit (7) for 64-bit ECC
    
    -- 7 <= 0 1 2 4 5 7 10 11 12 14 17 18 21 23 24 26 27 29
    --      32 33 36 38 39 41 44 46 47 50 51 53 56 57 58 60 63
                 
    
    
    
    ------------------------------------------------------------------------------------------------
    -- Checkbit 6 built up from 2x XOR18
    ------------------------------------------------------------------------------------------------
    
    --     data_chk7_a <= DataIn(0) & DataIn(1) & DataIn(2) & DataIn(4) & DataIn(5) & DataIn(7) & DataIn(10) &
    --                    DataIn(11) & DataIn(12) & DataIn(14) & DataIn(17) & DataIn(18) & DataIn(21) &
    --                    DataIn(23) & DataIn(24) & DataIn(26) & DataIn(27) & DataIn(29) ;
    --                  
    --     data_chk7_b <= DataIn(32) & DataIn(33) & DataIn(36) & DataIn(38) & DataIn(39) &
    --                    DataIn(41) & DataIn(44) & DataIn(46) & DataIn(47) & DataIn(50) &
    --                    DataIn(51) & DataIn(53) & DataIn(56) & DataIn(57) & DataIn(58) &
    --                    DataIn(60) & DataIn(63) & '0';
    --                  
    --     XOR18_I7_A : XOR18
    --       generic map (
    --         C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --       port map (
    --         InA => data_chk7_a,                   -- [in  std_logic_vector(0 to 17)]
    --         res => data_chk7_a_xor);              -- [out std_logic]
    --     
    --     
    --     XOR18_I7_B : XOR18
    --       generic map (
    --         C_USE_LUT6 => C_USE_LUT6)           -- [boolean]
    --       port map (
    --         InA => data_chk7_b,                 -- [in  std_logic_vector(0 to 17)]
    --         res => data_chk7_b_xor);            -- [out std_logic]


    -- Move register stage to earlier in LUT XOR logic when enabled (for C_ENCODE only)    
    -- Break up data_chk7_a & data_chk7_b into the following 6-input LUT XOR combinations.
    
    data_chk7_a <= DataIn(0) & DataIn(1) & DataIn(2) & DataIn(4) & DataIn(5) & DataIn(7);
    data_chk7_b <= DataIn(10) & DataIn(11) & DataIn(12) & DataIn(14) & DataIn(17) & DataIn(18);
    data_chk7_c <= DataIn(21) & DataIn(23) & DataIn(24) & DataIn(26) & DataIn(27) & DataIn(29);
    data_chk7_d <= DataIn(32) & DataIn(33) & DataIn(36) & DataIn(38) & DataIn(39) & DataIn(41);
    data_chk7_e <= DataIn(44) & DataIn(46) & DataIn(47) & DataIn(50) & DataIn(51) & DataIn(53);
    data_chk7_f <= DataIn(56) & DataIn(57) & DataIn(58) & DataIn(60) & DataIn(63);


    PARITY_CHK7_A : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk7_a (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk7_a_xor );           -- [out std_logic]
    
    PARITY_CHK7_B : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk7_b (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk7_b_xor );           -- [out std_logic]
    
    PARITY_CHK7_C : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk7_c (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk7_c_xor );           -- [out std_logic]
    
    PARITY_CHK7_D : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk7_d (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk7_d_xor );           -- [out std_logic]
    
    PARITY_CHK7_E : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    port map (
        InA => data_chk7_e (0 to 5),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk7_e_xor );           -- [out std_logic]
    
    PARITY_CHK7_F : Parity
    generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 5)
    port map (
        InA => data_chk7_f (0 to 4),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => data_chk7_f_xor );           -- [out std_logic]
    

    
    -- Merge all data bits
    -- CheckOut(7) <= data_chk7_xor xor data_chk7_i_xor;
    
    -- data_chk7_i <= data_chk7_a_xor xor data_chk7_b_xor;

    -- CheckOut(7) <= data_chk7_i;    
    
    
  end generate Encode_Bits;








  --------------------------------------------------------------------------------------------------
  -- Decode bits to get syndrome and UE/CE signals
  --------------------------------------------------------------------------------------------------
  Decode_Bits : if (not C_ENCODE) generate
    signal syndrome_i  : std_logic_vector(0 to 7) := (others => '0');
    -- Unused   signal syndrome_int_7   : std_logic;
    signal chk0_1 : std_logic_vector(0 to 6);    
    signal chk1_1 : std_logic_vector(0 to 6);
    signal chk2_1 : std_logic_vector(0 to 6);
    signal data_chk3_i : std_logic_vector(0 to 31);    
    signal chk3_1 : std_logic_vector(0 to 3);    
    signal data_chk4_i : std_logic_vector(0 to 31);
    signal chk4_1 : std_logic_vector(0 to 3);
    signal data_chk5_i : std_logic_vector(0 to 31);
    signal chk5_1 : std_logic_vector(0 to 3);
    
    signal data_chk6_i : std_logic_vector(0 to 7);
    
    signal data_chk7   : std_logic_vector(0 to 71);
    signal chk7_1 : std_logic_vector(0 to 11);
    -- signal syndrome7_a : std_logic;
    -- signal syndrome7_b : std_logic;

    signal syndrome_0_to_2       : std_logic_vector(0 to 2);
    signal syndrome_3_to_6       : std_logic_vector(3 to 6);
    signal syndrome_3_to_6_multi : std_logic;
    signal syndrome_3_to_6_zero  : std_logic;
    signal ue_i_0 : std_logic;
    signal ue_i_1 : std_logic;

  begin
  
    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 0 built up from 5 LUT6, 1 LUT5 and 1 7-bit XOR
    ------------------------------------------------------------------------------------------------
--    chk0_1(3) <= CheckIn(0);
    chk0_1(6) <= CheckIn(0);    -- 64-bit ECC
    
    Parity_chk0_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA                   => data_chk0(0 to 5),         -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res                   => chk0_1(0));                -- [out std_logic]
        
    Parity_chk0_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA                   => data_chk0(6 to 11),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res                   => chk0_1(1));                -- [out std_logic]
        
    Parity_chk0_3 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA                   => data_chk0(12 to 17),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res                   => chk0_1(2));                -- [out std_logic]
        
    -- Checkbit 0
    -- 18-bit for 32-bit data
    -- 35-bit for 64-bit data
    
    Parity_chk0_4 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA                   => data_chk0(18 to 23),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res                   => chk0_1(3));                -- [out std_logic]
    
    Parity_chk0_5 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA                   => data_chk0(24 to 29),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res                   => chk0_1(4));                -- [out std_logic]

    Parity_chk0_6 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 5)
      port map (
        InA                   => data_chk0(30 to 34),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res                   => chk0_1(5));                -- [out std_logic]
        
    --    Parity_chk0_7 : ParityEnable
    --      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
    --      port map (
    --        InA                   => chk0_1,            -- [in  std_logic_vector(0 to C_SIZE - 1)]
    --        Enable                => Enable_ECC,        -- [in  std_logic]
    --        Res                   => syndrome_i(0));    -- [out std_logic]

    Parity_chk0_7 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
      port map (
        InA                   => chk0_1,            -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res                   => syndrome_i(0));    -- [out std_logic]




    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 1 built up from 5 LUT6, 1 LUT5 and 1 7-bit XOR
    ------------------------------------------------------------------------------------------------
--    chk1_1(3) <= CheckIn(1);
    chk1_1(6) <= CheckIn(1);    -- 64-bit ECC
    
    Parity_chk1_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk1(0 to 5),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk1_1(0));              -- [out std_logic]
    
    Parity_chk1_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk1(6 to 11),      -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk1_1(1));              -- [out std_logic]
    
    Parity_chk1_3 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk1(12 to 17),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk1_1(2));              -- [out std_logic]

        
    -- Checkbit 1
    -- 18-bit for 32-bit data
    -- 35-bit for 64-bit data

    Parity_chk1_4 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk1(18 to 23),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk1_1(3));              -- [out std_logic]

    Parity_chk1_5 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk1(24 to 29),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk1_1(4));              -- [out std_logic]

    Parity_chk1_6 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 5)
      port map (
        InA => data_chk1(30 to 34),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk1_1(5));              -- [out std_logic]

    --    Parity_chk1_7 : ParityEnable      
    --      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
    --      port map (
    --        InA => chk1_1,                  -- [in  std_logic_vector(0 to C_SIZE - 1)]
    --        Enable => Enable_ECC,           -- [in  std_logic]
    --        Res => syndrome_i(1));          -- [out std_logic]

    Parity_chk1_7 : Parity      
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
      port map (
        InA => chk1_1,                  -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => syndrome_i(1));          -- [out std_logic]










    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 2 built up from 5 LUT6, 1 LUT5 and 1 7-bit XOR
    ------------------------------------------------------------------------------------------------
--    chk2_1(3) <= CheckIn(2);
    chk2_1(6) <= CheckIn(2);        -- 64-bit ECC
    
    Parity_chk2_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk2(0 to 5),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk2_1(0));              -- [out std_logic]
    
    Parity_chk2_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk2(6 to 11),      -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk2_1(1));              -- [out std_logic]
    
    Parity_chk2_3 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk2(12 to 17),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk2_1(2));              -- [out std_logic]

    -- Checkbit 2
    -- 18-bit for 32-bit data
    -- 35-bit for 64-bit data
    

    Parity_chk2_4 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk2(18 to 23),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk2_1(3));              -- [out std_logic]

    Parity_chk2_5 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk2(24 to 29),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk2_1(4));              -- [out std_logic]

    Parity_chk2_6 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 5)
      port map (
        InA => data_chk2(30 to 34),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk2_1(5));              -- [out std_logic]
    
    --    Parity_chk2_7 : ParityEnable
    --      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
    --      port map (
    --        InA => chk2_1,             -- [in  std_logic_vector(0 to C_SIZE - 1)]
    --        Enable => Enable_ECC,  -- [in  std_logic]
    --        Res => syndrome_i(2));          -- [out std_logic]

    Parity_chk2_7 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
      port map (
        InA => chk2_1,             -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => syndrome_i(2));          -- [out std_logic]








    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 3 built up from 4 LUT8 and 1 LUT4
    ------------------------------------------------------------------------------------------------
    data_chk3_i <= data_chk3 & CheckIn(3);
    
    Parity_chk3_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk3_i(0 to 7),         -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk3_1(0));                  -- [out std_logic]
    
    Parity_chk3_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk3_i(8 to 15),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk3_1(1));                  -- [out std_logic]
    
    -- 15-bit for 32-bit ECC
    -- 31-bit for 64-bit ECC

    Parity_chk3_3 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk3_i(16 to 23),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk3_1(2));                  -- [out std_logic]
    
    Parity_chk3_4 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk3_i(24 to 31),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk3_1(3));                  -- [out std_logic]
    
    --    Parity_chk3_5 : ParityEnable
    --      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 4)
    --      port map (
    --        InA => chk3_1,                      -- [in  std_logic_vector(0 to C_SIZE - 1)]
    --        Enable => Enable_ECC,               -- [in  std_logic]
    --        Res => syndrome_i(3));              -- [out std_logic]

    Parity_chk3_5 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 4)
      port map (
        InA => chk3_1,                      -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => syndrome_i(3));              -- [out std_logic]



    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 4 built up from 4 LUT8 and 1 LUT4
    ------------------------------------------------------------------------------------------------
    data_chk4_i <= data_chk4 & CheckIn(4);
    
    -- 15-bit for 32-bit ECC
    -- 31-bit for 64-bit ECC
    
    Parity_chk4_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk4_i(0 to 7),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk4_1(0));              -- [out std_logic]

    Parity_chk4_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk4_i(8 to 15),      -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk4_1(1));              -- [out std_logic]

    Parity_chk4_3 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk4_i(16 to 23),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk4_1(2));              -- [out std_logic]

    Parity_chk4_4 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk4_i(24 to 31),      -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk4_1(3));              -- [out std_logic]


    Parity_chk4_5 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 4)
      port map (
        InA => chk4_1,                  -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => syndrome_i(4));              -- [out std_logic]




    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 5 built up from 4 LUT8 and 1 LUT4
    ------------------------------------------------------------------------------------------------
    data_chk5_i <= data_chk5 & CheckIn(5);
    
    -- 15-bit for 32-bit ECC
    -- 31-bit for 64-bit ECC
    
    Parity_chk5_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk5_i(0 to 7),         -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk5_1(0));                  -- [out std_logic]

    Parity_chk5_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk5_i(8 to 15),        -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk5_1(1));                  -- [out std_logic]

    Parity_chk5_3 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk5_i(16 to 23),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk5_1(2));                  -- [out std_logic]

    Parity_chk5_4 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk5_i(24 to 31),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk5_1(3));                  -- [out std_logic]


    Parity_chk5_5 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 4)
      port map (
        InA => chk5_1,                  -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => syndrome_i(5));              -- [out std_logic]





    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 6 built up from 1 LUT8
    ------------------------------------------------------------------------------------------------
    data_chk6_i <= data_chk6 & CheckIn(6);
    
    Parity_chk6_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk6_i,             -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => syndrome_i(6));          -- [out std_logic]
    
    
    
    
    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 7 built up from 3 LUT7 and 8 LUT6 and 1 LUT3 (12 total) + 2 LUT6 + 1 2-bit XOR
    ------------------------------------------------------------------------------------------------
    -- 32-bit ECC uses DataIn(0:31) and Checkin (0 to 6)
    -- 64-bit ECC will use DataIn(0:63) and Checkin (0 to 7)
    
    data_chk7 <= DataIn(0) & DataIn(1) & DataIn(2) & DataIn(3) & DataIn(4) & DataIn(5) & DataIn(6) & DataIn(7) &
                 DataIn(8) & DataIn(9) & DataIn(10) & DataIn(11) & DataIn(12) & DataIn(13) & DataIn(14) &
                 DataIn(15) & DataIn(16) & DataIn(17) & DataIn(18) & DataIn(19) & DataIn(20) & DataIn(21) &
                 DataIn(22) & DataIn(23) & DataIn(24) & DataIn(25) & DataIn(26) & DataIn(27) & DataIn(28) &
                 DataIn(29) & DataIn(30) & DataIn(31) & 
                 
                 DataIn(32) & DataIn(33) & DataIn(34) & DataIn(35) & DataIn(36) & DataIn(37) & 
                 DataIn(38) & DataIn(39) & DataIn(40) & DataIn(41) & DataIn(42) & DataIn(43) &                 
                 DataIn(44) & DataIn(45) & DataIn(46) & DataIn(47) & DataIn(48) & DataIn(49) & 
                 DataIn(50) & DataIn(51) & DataIn(52) & DataIn(53) & DataIn(54) & DataIn(55) & 
                 DataIn(56) & DataIn(57) & DataIn(58) & DataIn(59) & DataIn(60) & DataIn(61) & 
                 DataIn(62) & DataIn(63) &                  
                 
                 CheckIn(6) & CheckIn(5) & CheckIn(4) & CheckIn(3) & CheckIn(2) &
                 CheckIn(1) & CheckIn(0) & CheckIn(7);
                 
                 
    Parity_chk7_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk7(0 to 5),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk7_1(0));              -- [out std_logic]
    
    Parity_chk7_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk7(6 to 11),      -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk7_1(1));              -- [out std_logic]
    
    Parity_chk7_3 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk7(12 to 17),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk7_1(2));              -- [out std_logic]
    
    Parity_chk7_4 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
      port map (
        InA => data_chk7(18 to 24),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk7_1(3));              -- [out std_logic]
    
    Parity_chk7_5 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
      port map (
        InA => data_chk7(25 to 31),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk7_1(4));              -- [out std_logic]
    
    Parity_chk7_6 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
      port map (
        InA => data_chk7(32 to 38),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk7_1(5));              -- [out std_logic]
        
    Parity_chk7_7 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk7(39 to 44),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk7_1(6));              -- [out std_logic]

    Parity_chk7_8 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk7(45 to 50),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk7_1(7));              -- [out std_logic]

    Parity_chk7_9 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk7(51 to 56),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk7_1(8));              -- [out std_logic]

    Parity_chk7_10 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk7(57 to 62),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk7_1(9));              -- [out std_logic]

    Parity_chk7_11 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk7(63 to 68),         -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk7_1(10));                 -- [out std_logic]

    Parity_chk7_12 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 3)
      port map (
        InA => data_chk7(69 to 71),         -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk7_1(11));                 -- [out std_logic]
        
        
    -- Unused    
    --     Parity_chk7_13 : Parity
    --       generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    --       port map (
    --         InA => chk7_1 (0 to 5),             -- [in  std_logic_vector(0 to C_SIZE - 1)]
    --         Res => syndrome7_a);                -- [out std_logic]
    --     
    --     
    --     Parity_chk7_14 : Parity
    --       generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
    --       port map (
    --         InA => chk7_1 (6 to 11),             -- [in  std_logic_vector(0 to C_SIZE - 1)]
    --         Res => syndrome7_b);                 -- [out std_logic]

    -- Unused   syndrome_i(7) <= syndrome7_a xor syndrome7_b;
    -- Unused   syndrome_i (7) <= syndrome7_a;

    -- syndrome_i (7) is not used here.  Final XOR stage is done outside this module with Syndrome_7 vector output.
    -- Clean up this statement.
    syndrome_i (7) <= '0';

    -- Unused   syndrome_int_7 <= syndrome7_a xor syndrome7_b;
    -- Unused   Syndrome_7_b <= syndrome7_b;


    Syndrome <= syndrome_i;
    
    -- Bring out seperate output to do final XOR stage on Syndrome (7) after
    -- the pipeline stage.
    Syndrome_7 <= chk7_1 (0 to 11);
    
    
    
    ---------------------------------------------------------------------------
    
    -- With final syndrome registered outside this module for pipeline balancing
    -- Use registered syndrome to generate any error flags.
    -- Use input signal, Syndrome_Chk which is the registered Syndrome used to
    -- correct any single bit errors.
        
    syndrome_0_to_2 <= Syndrome_Chk(0) & Syndrome_Chk(1) & Syndrome_Chk(2);
       
    -- syndrome_3_to_6 <= syndrome_i(3) & syndrome_i(4) & syndrome_i(5) & syndrome_i(6);
    syndrome_3_to_6 <= Syndrome_Chk(3) & Syndrome_Chk(4) & Syndrome_Chk(5) & Syndrome_Chk(6);
    
    syndrome_3_to_6_zero <= '1' when syndrome_3_to_6 = "0000" else '0';
    
    -- Syndrome bits (3:6) can indicate a double bit error if
    -- Syndrome (6) = '1' AND any bits of Syndrome(3:5) are equal to a '1'.
    syndrome_3_to_6_multi <= '1' when (syndrome_3_to_6 = "1111" or      -- 15
                                       syndrome_3_to_6 = "1101" or      -- 13
                                       syndrome_3_to_6 = "1011" or      -- 11
                                       syndrome_3_to_6 = "1001" or      -- 9
                                       syndrome_3_to_6 = "0111" or      -- 7
                                       syndrome_3_to_6 = "0101" or      -- 5
                                       syndrome_3_to_6 = "0011")        -- 3
                             else '0';

    -- A single bit error is detectable if
    -- Syndrome (7) = '1' and a double bit error is not detectable in Syndrome (3:6)
    -- CE <= Enable_ECC and (syndrome_i(7) or CE_Q) when (syndrome_3_to_6_multi = '0')
    -- CE <= Enable_ECC and (syndrome_int_7 or CE_Q) when (syndrome_3_to_6_multi = '0')
    -- CE <= Enable_ECC and (Syndrome_Chk(7) or CE_Q) when (syndrome_3_to_6_multi = '0')
    --       else CE_Q and Enable_ECC;


    -- Ensure that CE flag is only asserted for a single clock cycle (and does not keep
    -- registered output value)
    CE <= (Enable_ECC and Syndrome_Chk(7)) when (syndrome_3_to_6_multi = '0') else '0';




    -- Uncorrectable error if Syndrome(7) = '0' and any other bits are = '1'.
    -- ue_i_0 <= Enable_ECC when (syndrome_3_to_6_zero = '0') or (syndrome_i(0 to 2) /= "000")
    --           else UE_Q and Enable_ECC;

    --      ue_i_0 <= Enable_ECC when (syndrome_3_to_6_zero = '0') or (syndrome_0_to_2 /= "000")
    --                else UE_Q and Enable_ECC;
    --                
    --      ue_i_1 <= Enable_ECC and (syndrome_3_to_6_multi or UE_Q);


    -- Similar edit from CE flag.  Ensure that UE flags are only asserted for a single
    -- clock cycle.  The flags are registered outside this module for detection in
    -- register module.

    ue_i_0 <= Enable_ECC when (syndrome_3_to_6_zero = '0') or (syndrome_0_to_2 /= "000") else '0';
    ue_i_1 <= Enable_ECC and (syndrome_3_to_6_multi);




    Use_LUT6: if (C_USE_LUT6) generate
      UE_MUXF7 : MUXF7
        port map (
          I0 => ue_i_0,
          I1 => ue_i_1,
--          S  => syndrome_i(7),
--          S  => syndrome_int_7,
          S  => Syndrome_Chk(7),
          O  => UE );      
          
    end generate Use_LUT6;

    Use_RTL: if (not C_USE_LUT6) generate
    -- bit 6 in 32-bit ECC
    -- bit 7 in 64-bit ECC
--      UE <= ue_i_1 when syndrome_i(7) = '1' else ue_i_0;
--      UE <= ue_i_1 when syndrome_int_7 = '1' else ue_i_0;
      UE <= ue_i_1 when Syndrome_Chk(7) = '1' else ue_i_0;
    end generate Use_RTL;
    
    
  end generate Decode_Bits;

end architecture IMP;


-------------------------------------------------------------------------------
-- checkbit_handler.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
-------------------------------------------------------------------------------
-- Filename:        checkbit_handler.vhd
--
-- Description:     Generates the ECC checkbits for the input vector of data bits.
--                  
-- VHDL-Standard:   VHDL'93/02
-------------------------------------------------------------------------------
-- Structure:   
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- checkbit_handler_64.vhd
--                      |       -- (same helper components as checkbit_handler)
--                      |   -- correct_one_bit.vhd
--                      |   -- correct_one_bit_64.vhd
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/1/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
--
--
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x" 
--      reset signals:                          "rst", "rst_n" 
--      generics:                               "C_*" 
--      user defined types:                     "*_TYPE" 
--      state machine next state:               "*_ns" 
--      state machine current state:            "*_cs" 
--      combinatorial signals:                  "*_com" 
--      pipelined or register delay signals:    "*_d#" 
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce" 
--      internal version of output port         "*_i"
--      device pins:                            "*_pin" 
--      ports:                                  - Names begin with Uppercase 
--      processes:                              "*_PROCESS" 
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity checkbit_handler is
  generic (
    C_ENCODE   : boolean := true;
    C_USE_LUT6 : boolean := true 
  );
  port (
    DataIn     : in  std_logic_vector(0 to 31);  --- changed from 31 downto 0 to  0 to 31 to make it compatabile with LMB Controller's hamming code.
    CheckIn    : in  std_logic_vector(0 to 6);
    CheckOut   : out std_logic_vector(0 to 6);
    Syndrome   : out std_logic_vector(0 to 6);
    Syndrome_4      : out std_logic_vector (0 to 1);   
    Syndrome_6      : out std_logic_vector (0 to 5);
 
    Syndrome_Chk    : in  std_logic_vector (0 to 6);    
    Enable_ECC      : in  std_logic;    
    UE_Q            : in  std_logic;
    CE_Q            : in  std_logic;
    UE              : out std_logic;
    CE              : out std_logic
    );
    
end entity checkbit_handler;

library unisim;
use unisim.vcomponents.all;


architecture IMP of checkbit_handler is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of IMP : architecture is "yes";

  component XOR18 is
    generic (
      C_USE_LUT6 : boolean);
    port (
      InA : in  std_logic_vector(0 to 17);
      res : out std_logic);
  end component XOR18;
  
  component Parity is
    generic (
      C_USE_LUT6 : boolean;
      C_SIZE     : integer);
    port (
      InA : in  std_logic_vector(0 to C_SIZE - 1);
      Res : out std_logic);
  end component Parity;
  
  signal data_chk0 : std_logic_vector(0 to 17);
  signal data_chk1 : std_logic_vector(0 to 17);
  signal data_chk2 : std_logic_vector(0 to 17);
  signal data_chk3 : std_logic_vector(0 to 14);
  signal data_chk4 : std_logic_vector(0 to 14);
  signal data_chk5 : std_logic_vector(0 to 5);
  
begin  -- architecture IMP

  data_chk0 <= DataIn(0) & DataIn(1) & DataIn(3) & DataIn(4) & DataIn(6) & DataIn(8) & DataIn(10) &
               DataIn(11) & DataIn(13) & DataIn(15) & DataIn(17) & DataIn(19) & DataIn(21) &
               DataIn(23) & DataIn(25) & DataIn(26) & DataIn(28) & DataIn(30);

  data_chk1 <= DataIn(0) & DataIn(2) & DataIn(3) & DataIn(5) & DataIn(6) & DataIn(9) & DataIn(10) &
               DataIn(12) & DataIn(13) & DataIn(16) & DataIn(17) & DataIn(20) & DataIn(21) &
               DataIn(24) & DataIn(25) & DataIn(27) & DataIn(28) & DataIn(31);

  data_chk2 <= DataIn(1) & DataIn(2) & DataIn(3) & DataIn(7) & DataIn(8) & DataIn(9) & DataIn(10) &
               DataIn(14) & DataIn(15) & DataIn(16) & DataIn(17) & DataIn(22) & DataIn(23) & DataIn(24) &
               DataIn(25) & DataIn(29) & DataIn(30) & DataIn(31);

  data_chk3 <= DataIn(4) & DataIn(5) & DataIn(6) & DataIn(7) & DataIn(8) & DataIn(9) & DataIn(10) &
               DataIn(18) & DataIn(19) & DataIn(20) & DataIn(21) & DataIn(22) & DataIn(23) & DataIn(24) &
               DataIn(25);

  data_chk4 <= DataIn(11) & DataIn(12) & DataIn(13) & DataIn(14) & DataIn(15) & DataIn(16) & DataIn(17) &
               DataIn(18) & DataIn(19) & DataIn(20) & DataIn(21) & DataIn(22) & DataIn(23) & DataIn(24) &
               DataIn(25);

  data_chk5   <= DataIn(26) & DataIn(27) & DataIn(28) & DataIn(29) & DataIn(30) & DataIn(31);


  -- Encode bits for writing data
  Encode_Bits : if (C_ENCODE) generate
    signal data_chk3_i : std_logic_vector(0 to 17);
    signal data_chk4_i : std_logic_vector(0 to 17);
    signal data_chk6   : std_logic_vector(0 to 17);

  begin
    ------------------------------------------------------------------------------------------------
    -- Checkbit 0 built up using XOR18
    ------------------------------------------------------------------------------------------------
    XOR18_I0 : XOR18
      generic map (
        C_USE_LUT6 => C_USE_LUT6)       -- [boolean]
      port map (
        InA => data_chk0,               -- [in  std_logic_vector(0 to 17)]
        res => CheckOut(0));            -- [out std_logic]

    ------------------------------------------------------------------------------------------------
    -- Checkbit 1 built up using XOR18
    ------------------------------------------------------------------------------------------------
    XOR18_I1 : XOR18
      generic map (
        C_USE_LUT6 => C_USE_LUT6)       -- [boolean]
      port map (
        InA => data_chk1,               -- [in  std_logic_vector(0 to 17)]
        res => CheckOut(1));            -- [out std_logic]

    ------------------------------------------------------------------------------------------------
    -- Checkbit 2 built up using XOR18
    ------------------------------------------------------------------------------------------------
    XOR18_I2 : XOR18
      generic map (
        C_USE_LUT6 => C_USE_LUT6)       -- [boolean]
      port map (
        InA => data_chk2,               -- [in  std_logic_vector(0 to 17)]
        res => CheckOut(2));            -- [out std_logic]

    ------------------------------------------------------------------------------------------------
    -- Checkbit 3 built up using XOR18
    ------------------------------------------------------------------------------------------------
    data_chk3_i <= data_chk3 & "000";

    XOR18_I3 : XOR18
      generic map (
        C_USE_LUT6 => C_USE_LUT6)       -- [boolean]
      port map (
        InA => data_chk3_i,             -- [in  std_logic_vector(0 to 17)]
        res => CheckOut(3));            -- [out std_logic]

    ------------------------------------------------------------------------------------------------
    -- Checkbit 4 built up using XOR18
    ------------------------------------------------------------------------------------------------
    data_chk4_i <= data_chk4 & "000";

    XOR18_I4 : XOR18
      generic map (
        C_USE_LUT6 => C_USE_LUT6)       -- [boolean]
      port map (
        InA => data_chk4_i,             -- [in  std_logic_vector(0 to 17)]
        res => CheckOut(4));            -- [out std_logic]

    ------------------------------------------------------------------------------------------------
    -- Checkbit 5 built up from 1 LUT6
    ------------------------------------------------------------------------------------------------
    Parity_chk5_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk5,             -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => CheckOut(5));          -- [out std_logic]
    
    ------------------------------------------------------------------------------------------------
    -- Checkbit 6 built up from 3 LUT7 and 4 LUT6
    ------------------------------------------------------------------------------------------------
    data_chk6 <= DataIn(0) & DataIn(1) & DataIn(2) & DataIn(4) & DataIn(5) & DataIn(7) & DataIn(10) &
                 DataIn(11) & DataIn(12) & DataIn(14) & DataIn(17) & DataIn(18) & DataIn(21) &
                 DataIn(23) & DataIn(24) & DataIn(26) & DataIn(27) & DataIn(29);

    XOR18_I6 : XOR18
      generic map (
        C_USE_LUT6 => C_USE_LUT6)       -- [boolean]
      port map (
        InA => data_chk6,             -- [in  std_logic_vector(0 to 17)]
        res => CheckOut(6));            -- [out std_logic]
    
  end generate Encode_Bits;

  --------------------------------------------------------------------------------------------------
  -- Decode bits to get syndrome and UE/CE signals
  --------------------------------------------------------------------------------------------------
  Decode_Bits : if (not C_ENCODE) generate
    signal syndrome_i   : std_logic_vector(0 to 6) := (others => '0');
    signal chk0_1       : std_logic_vector(0 to 3);
    signal chk1_1       : std_logic_vector(0 to 3);
    signal chk2_1       : std_logic_vector(0 to 3);
    signal data_chk3_i  : std_logic_vector(0 to 15);
    signal chk3_1       : std_logic_vector(0 to 1);
    signal data_chk4_i  : std_logic_vector(0 to 15);
    signal chk4_1       : std_logic_vector(0 to 1);
    signal data_chk5_i  : std_logic_vector(0 to 6);
    signal data_chk6    : std_logic_vector(0 to 38);
    signal chk6_1       : std_logic_vector(0 to 5);

    signal syndrome_0_to_2       : std_logic_vector (0 to 2);
    signal syndrome_3_to_5       : std_logic_vector (3 to 5);
    signal syndrome_3_to_5_multi : std_logic;
    signal syndrome_3_to_5_zero  : std_logic;
    signal ue_i_0 : std_logic;
    signal ue_i_1 : std_logic;

  begin
    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 0 built up from 3 LUT6 and 1 LUT4
    ------------------------------------------------------------------------------------------------
    chk0_1(3) <= CheckIn(0);
    
    Parity_chk0_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA                   => data_chk0(0 to 5),  -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res                   => chk0_1(0));  -- [out std_logic]

    Parity_chk0_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA                   => data_chk0(6 to 11),  -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res                   => chk0_1(1));  -- [out std_logic]

    Parity_chk0_3 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA                   => data_chk0(12 to 17),  -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res                   => chk0_1(2));  -- [out std_logic]
    
    Parity_chk0_4 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 4)
      port map (
        InA                   => chk0_1,            -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res                   => syndrome_i(0));    -- [out std_logic]
        

    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 1 built up from 3 LUT6 and 1 LUT4
    ------------------------------------------------------------------------------------------------
    chk1_1(3) <= CheckIn(1);

    Parity_chk1_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk1(0 to 5),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk1_1(0));              -- [out std_logic]

    Parity_chk1_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk1(6 to 11),      -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk1_1(1));              -- [out std_logic]

    Parity_chk1_3 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk1(12 to 17),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk1_1(2));              -- [out std_logic]

    Parity_chk1_4 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 4)
      port map (
        InA => chk1_1,                  -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => syndrome_i(1));          -- [out std_logic]


    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 2 built up from 3 LUT6 and 1 LUT4
    ------------------------------------------------------------------------------------------------
    chk2_1(3) <= CheckIn(2);

    Parity_chk2_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk2(0 to 5),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk2_1(0));              -- [out std_logic]

    Parity_chk2_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk2(6 to 11),      -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk2_1(1));              -- [out std_logic]

    Parity_chk2_3 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk2(12 to 17),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk2_1(2));              -- [out std_logic]
    
    Parity_chk2_4 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 4)
      port map (
        InA => chk2_1,                  -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => syndrome_i(2));          -- [out std_logic]

    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 3 built up from 2 LUT8 and 1 LUT2
    ------------------------------------------------------------------------------------------------
    data_chk3_i <= data_chk3 & CheckIn(3);

    Parity_chk3_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk3_i(0 to 7),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk3_1(0));              -- [out std_logic]

    Parity_chk3_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk3_i(8 to 15),      -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk3_1(1));              -- [out std_logic]
        

    -- For improved timing, remove Enable_ECC signal in this LUT level
    Parity_chk3_3 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 2)
      port map (
        InA => chk3_1,                      -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => syndrome_i(3));              -- [out std_logic]



    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 4 built up from 2 LUT8 and 1 LUT2
    ------------------------------------------------------------------------------------------------
    data_chk4_i <= data_chk4 & CheckIn(4);
    
    Parity_chk4_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk4_i(0 to 7),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk4_1(0));              -- [out std_logic]
        
    Parity_chk4_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 8)
      port map (
        InA => data_chk4_i(8 to 15),      -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk4_1(1));              -- [out std_logic]
    
    

    -- Set bit 4 output with default. Real ECC XOR value will be determined post register
    -- stage.
    syndrome_i (4) <= '0';

    -- For improved timing, move last LUT level XOR to next side of pipeline
    -- stage in read path.
    Syndrome_4 <= chk4_1;



    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 5 built up from 1 LUT7
    ------------------------------------------------------------------------------------------------
    data_chk5_i <= data_chk5 & CheckIn(5);
    Parity_chk5_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
      port map (
        InA => data_chk5_i,             -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => syndrome_i(5));          -- [out std_logic]
    

    ------------------------------------------------------------------------------------------------
    -- Syndrome bit 6 built up from 3 LUT7 and 4 LUT6
    ------------------------------------------------------------------------------------------------
    data_chk6 <= DataIn(0) & DataIn(1) & DataIn(2) & DataIn(3) & DataIn(4) & DataIn(5) & DataIn(6) & DataIn(7) &
                 DataIn(8) & DataIn(9) & DataIn(10) & DataIn(11) & DataIn(12) & DataIn(13) & DataIn(14) &
                 DataIn(15) & DataIn(16) & DataIn(17) & DataIn(18) & DataIn(19) & DataIn(20) & DataIn(21) &
                 DataIn(22) & DataIn(23) & DataIn(24) & DataIn(25) & DataIn(26) & DataIn(27) & DataIn(28) &
                 DataIn(29) & DataIn(30) & DataIn(31) & CheckIn(5) & CheckIn(4) & CheckIn(3) & CheckIn(2) &
                 CheckIn(1) & CheckIn(0) & CheckIn(6);

    Parity_chk6_1 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk6(0 to 5),       -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk6_1(0));              -- [out std_logic]

    Parity_chk6_2 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk6(6 to 11),      -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk6_1(1));              -- [out std_logic]

    Parity_chk6_3 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
      port map (
        InA => data_chk6(12 to 17),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk6_1(2));              -- [out std_logic]

    Parity_chk6_4 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
      port map (
        InA => data_chk6(18 to 24),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk6_1(3));              -- [out std_logic]

    Parity_chk6_5 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
      port map (
        InA => data_chk6(25 to 31),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk6_1(4));              -- [out std_logic]

    Parity_chk6_6 : Parity
      generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 7)
      port map (
        InA => data_chk6(32 to 38),     -- [in  std_logic_vector(0 to C_SIZE - 1)]
        Res => chk6_1(5));              -- [out std_logic]
    

    -- No internal use for MSB of syndrome (it is created after the 
    -- register stage, outside of this block)
    syndrome_i(6) <= '0';

    Syndrome <= syndrome_i;
    -- (N:0) <= (0:N)
    
    
    -- Bring out seperate output to do final XOR stage on Syndrome (6) after
    -- the pipeline stage.
    Syndrome_6 <= chk6_1 (0 to 5);
    
    
    
    
    
    ---------------------------------------------------------------------------
    
    -- With final syndrome registered outside this module for pipeline balancing
    -- Use registered syndrome to generate any error flags.
    -- Use input signal, Syndrome_Chk which is the registered Syndrome used to
    -- correct any single bit errors.
        
    syndrome_0_to_2 <= Syndrome_Chk(0) & Syndrome_Chk(1) & Syndrome_Chk(2);
    
    syndrome_3_to_5 <= Syndrome_Chk(3) & Syndrome_Chk(4) & Syndrome_Chk(5);

    syndrome_3_to_5_zero <= '1' when syndrome_3_to_5 = "000" else '0';
    syndrome_3_to_5_multi <= '1' when (syndrome_3_to_5 = "111" or
                                      syndrome_3_to_5 = "011" or
                                      syndrome_3_to_5 = "101")
                             else '0';

    -- Ensure that CE flag is only asserted for a single clock cycle (and does not keep
    -- registered output value)
    CE <= (Enable_ECC and Syndrome_Chk(6)) when (syndrome_3_to_5_multi = '0') else '0';


    -- Similar edit from CE flag.  Ensure that UE flags are only asserted for a single
    -- clock cycle.  The flags are registered outside this module for detection in
    -- register module.
    ue_i_0 <= Enable_ECC when (syndrome_3_to_5_zero = '0') or (syndrome_0_to_2 /= "000") else '0';
    ue_i_1 <= Enable_ECC and (syndrome_3_to_5_multi);



    Use_LUT6: if (C_USE_LUT6) generate
    begin
      UE_MUXF7 : MUXF7
        port map (
          I0 => ue_i_0,
          I1 => ue_i_1,
          S  => Syndrome_Chk(6),
          O  => UE);      
    end generate Use_LUT6;

    Use_RTL: if (not C_USE_LUT6) generate
    begin
        UE <= ue_i_1 when Syndrome_Chk(6) = '1' else ue_i_0;
    end generate Use_RTL;
    
  end generate Decode_Bits;

end architecture IMP;


-------------------------------------------------------------------------------
-- correct_one_bit_64.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
------------------------------------------------------------------------------
-- Filename:        correct_one_bit_64.vhd
--
-- Description:     Identifies single bit to correct in 64-bit word of
--                  data read from memory as indicated by the syndrome input
--                  vector.
--
-- VHDL-Standard:   VHDL'93
--
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- checkbit_handler_64.vhd
--                      |       -- (same helper components as checkbit_handler)
--                      |   -- correct_one_bit.vhd
--                      |   -- correct_one_bit_64.vhd
--
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/1/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
--
--
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x"
--      reset signals:                          "rst", "rst_n"
--      generics:                               "C_*"
--      user defined types:                     "*_TYPE"
--      state machine next state:               "*_ns"
--      state machine current state:            "*_cs"
--      combinatorial signals:                  "*_com"
--      pipelined or register delay signals:    "*_d#"
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce"
--      internal version of output port         "*_i"
--      device pins:                            "*_pin"
--      ports:                                  - Names begin with Uppercase
--      processes:                              "*_PROCESS"
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity Correct_One_Bit_64 is
  generic (
    C_USE_LUT6    : boolean := true;
    Correct_Value : std_logic_vector(0 to 7));
  port (
    DIn      : in  std_logic;
    Syndrome : in  std_logic_vector(0 to 7);
    DCorr    : out std_logic);
end entity Correct_One_Bit_64;

architecture IMP of Correct_One_Bit_64 is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of IMP : architecture is "yes";

  -----------------------------------------------------------------------------
  -- Find which bit that has a '1'
  -- There is always one bit which has a '1'
  -----------------------------------------------------------------------------
  function find_one (Syn : std_logic_vector(0 to 7)) return natural is
  begin  -- function find_one
    for I in 0 to 7 loop
      if (Syn(I) = '1') then
        return I;
      end if;
    end loop;  -- I
    return 0;                           -- Should never reach this statement
  end function find_one;

  constant di_index : natural := find_one(Correct_Value);

  signal corr_sel : std_logic;
  signal corr_c   : std_logic;
  signal lut_compare  : std_logic_vector(0 to 6);
  signal lut_corr_val : std_logic_vector(0 to 6);

begin  -- architecture IMP

  Remove_DI_Index : process (Syndrome) is
  begin  -- process Remove_DI_Index
    if (di_index = 0) then
      lut_compare  <= Syndrome(1 to 7);
      lut_corr_val <= Correct_Value(1 to 7);
    elsif (di_index = 6) then
      lut_compare  <= Syndrome(0 to 6);
      lut_corr_val <= Correct_Value(0 to 6);
    else
      lut_compare  <= Syndrome(0 to di_index-1) & Syndrome(di_index+1 to 7);
      lut_corr_val <= Correct_Value(0 to di_index-1) & Correct_Value(di_index+1 to 7);
    end if;
  end process Remove_DI_Index;

  corr_sel <= '0' when lut_compare = lut_corr_val else '1';
  
  Corr_MUXCY : MUXCY_L
    port map (
      DI => Syndrome(di_index),
      CI => '0',
      S  => corr_sel,
      LO => corr_c);

  Corr_XORCY : XORCY
    port map (
      LI => DIn,
      CI => corr_c,
      O  => DCorr);

end architecture IMP;


-------------------------------------------------------------------------------
-- correct_one_bit.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
------------------------------------------------------------------------------
-- Filename:        correct_one_bit.vhd
--
-- Description:     Identifies single bit to correct in 32-bit word of
--                  data read from memory as indicated by the syndrome input
--                  vector.
--
-- VHDL-Standard:   VHDL'93
--
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- checkbit_handler_64.vhd
--                      |       -- (same helper components as checkbit_handler)
--                      |   -- correct_one_bit.vhd
--                      |   -- correct_one_bit_64.vhd
--
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/1/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
--
--
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x"
--      reset signals:                          "rst", "rst_n"
--      generics:                               "C_*"
--      user defined types:                     "*_TYPE"
--      state machine next state:               "*_ns"
--      state machine current state:            "*_cs"
--      combinatorial signals:                  "*_com"
--      pipelined or register delay signals:    "*_d#"
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce"
--      internal version of output port         "*_i"
--      device pins:                            "*_pin"
--      ports:                                  - Names begin with Uppercase
--      processes:                              "*_PROCESS"
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity Correct_One_Bit is
  generic (
    C_USE_LUT6    : boolean := true;
    Correct_Value : std_logic_vector(0 to 6));
  port (
    DIn      : in  std_logic;
    Syndrome : in  std_logic_vector(0 to 6);
    DCorr    : out std_logic);
end entity Correct_One_Bit;

architecture IMP of Correct_One_Bit is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of IMP : architecture is "yes";

  -----------------------------------------------------------------------------
  -- Find which bit that has a '1'
  -- There is always one bit which has a '1'
  -----------------------------------------------------------------------------
  function find_one (Syn : std_logic_vector(0 to 6)) return natural is
  begin  -- function find_one
    for I in 0 to 6 loop
      if (Syn(I) = '1') then
        return I;
      end if;
    end loop;  -- I
    return 0;                           -- Should never reach this statement
  end function find_one;

  constant di_index : natural := find_one(Correct_Value);

  signal corr_sel : std_logic;
  signal corr_c   : std_logic;
  signal lut_compare  : std_logic_vector(0 to 5);
  signal lut_corr_val : std_logic_vector(0 to 5);
begin  -- architecture IMP

  Remove_DI_Index : process (Syndrome) is
  begin  -- process Remove_DI_Index
    if (di_index = 0) then
      lut_compare  <= Syndrome(1 to 6);
      lut_corr_val <= Correct_Value(1 to 6);
    elsif (di_index = 6) then
      lut_compare  <= Syndrome(0 to 5);
      lut_corr_val <= Correct_Value(0 to 5);
    else
      lut_compare  <= Syndrome(0 to di_index-1) & Syndrome(di_index+1 to 6);
      lut_corr_val <= Correct_Value(0 to di_index-1) & Correct_Value(di_index+1 to 6);
    end if;
  end process Remove_DI_Index;

--   Corr_LUT : LUT6
--     generic map(
--       INIT => X"6996966996696996"
--       )
--     port map(
--       O    => corr_sel,                 -- [out]
--       I0   => InA(5),                   -- [in]
--       I1   => InA(4),                   -- [in]
--       I2   => InA(3),                   -- [in]
--       I3   => InA(2),                   -- [in]
--       I4   => InA(1),                   -- [in]
--       I5   => InA(0)                    -- [in]
--       );

  corr_sel <= '0' when lut_compare = lut_corr_val else '1';
  
  Corr_MUXCY : MUXCY_L
    port map (
      DI => Syndrome(di_index),
      CI => '0',
      S  => corr_sel,
      LO => corr_c);

  Corr_XORCY : XORCY
    port map (
      LI => DIn,
      CI => corr_c,
      O  => DCorr);

end architecture IMP;


-------------------------------------------------------------------------------
-- xor18.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
------------------------------------------------------------------------------
-- Filename:        xor18.vhd
--
-- Description:     Basic 18-bit input XOR function.
--
-- VHDL-Standard:   VHDL'93
--
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- checkbit_handler_64.vhd
--                      |       -- (same helper components as checkbit_handler)
--                      |   -- correct_one_bit.vhd
--                      |   -- correct_one_bit_64.vhd
--
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/2/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
-- JLJ      3/17/2011         v1.03a
-- ~~~~~~
--  Add default on C_USE_LUT6 parameter.
-- ^^^^^^
--
--
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x"
--      reset signals:                          "rst", "rst_n"
--      generics:                               "C_*"
--      user defined types:                     "*_TYPE"
--      state machine next state:               "*_ns"
--      state machine current state:            "*_cs"
--      combinatorial signals:                  "*_com"
--      pipelined or register delay signals:    "*_d#"
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce"
--      internal version of output port         "*_i"
--      device pins:                            "*_pin"
--      ports:                                  - Names begin with Uppercase
--      processes:                              "*_PROCESS"
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity XOR18 is 
  generic (
    C_USE_LUT6 : boolean := FALSE );
  port (
    InA : in  std_logic_vector(0 to 17);
    res : out std_logic);
end entity XOR18;

architecture IMP of XOR18 is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of IMP : architecture is "yes";

begin  -- architecture IMP

  Using_LUT6: if (C_USE_LUT6) generate
    signal xor6_1   : std_logic;
    signal xor6_2   : std_logic;
    signal xor6_3   : std_logic;
    signal xor18_c1 : std_logic;
    signal xor18_c2 : std_logic;
  begin  -- generate Using_LUT6

    XOR6_1_LUT : LUT6
      generic map(
        INIT => X"6996966996696996")
      port map(
        O    => xor6_1,
        I0   => InA(17),
        I1   => InA(16),
        I2   => InA(15),
        I3   => InA(14),
        I4   => InA(13),
        I5   => InA(12));

    XOR_1st_MUXCY : MUXCY_L
      port map (
        DI => '1',
        CI => '0',
        S  => xor6_1,
        LO => xor18_c1);

    XOR6_2_LUT : LUT6
      generic map(
        INIT => X"6996966996696996")
      port map(
        O    => xor6_2,
        I0   => InA(11),
        I1   => InA(10),
        I2   => InA(9),
        I3   => InA(8),
        I4   => InA(7),
        I5   => InA(6));

    XOR_2nd_MUXCY : MUXCY_L
      port map (
        DI => xor6_1,
        CI => xor18_c1,
        S  => xor6_2,
        LO => xor18_c2);

    XOR6_3_LUT : LUT6
      generic map(
        INIT => X"6996966996696996")
      port map(
        O    => xor6_3,
        I0   => InA(5),
        I1   => InA(4),
        I2   => InA(3),
        I3   => InA(2),
        I4   => InA(1),
        I5   => InA(0));

    XOR18_XORCY : XORCY
      port map (
        LI => xor6_3,
        CI => xor18_c2,
        O  => res);
    
  end generate Using_LUT6;

  Not_Using_LUT6: if (not C_USE_LUT6) generate
  begin  -- generate Not_Using_LUT6

    res <= InA(17) xor InA(16) xor InA(15) xor InA(14) xor InA(13) xor InA(12) xor
           InA(11) xor InA(10) xor InA(9) xor InA(8) xor InA(7) xor InA(6) xor
           InA(5) xor InA(4) xor InA(3) xor InA(2) xor InA(1) xor InA(0);    

  end generate Not_Using_LUT6;
end architecture IMP;


-------------------------------------------------------------------------------
-- parity.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
------------------------------------------------------------------------------
-- Filename:        parity.vhd
--
-- Description:     Generate parity optimally for all target architectures.
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- checkbit_handler_64.vhd
--                      |       -- (same helper components as checkbit_handler)
--                      |   -- correct_one_bit.vhd
--                      |   -- correct_one_bit_64.vhd
--
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/2/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
--
--
-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x"
--      reset signals:                          "rst", "rst_n"
--      generics:                               "C_*"
--      user defined types:                     "*_TYPE"
--      state machine next state:               "*_ns"
--      state machine current state:            "*_cs"
--      combinatorial signals:                  "*_com"
--      pipelined or register delay signals:    "*_d#"
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce"
--      internal version of output port         "*_i"
--      device pins:                            "*_pin"
--      ports:                                  - Names begin with Uppercase
--      processes:                              "*_PROCESS"
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity Parity is
  generic (
    C_USE_LUT6 : boolean := true;
    C_SIZE     : integer := 6
    );
  port (
    InA : in  std_logic_vector(0 to C_SIZE - 1);
    Res : out std_logic
    );
end entity Parity;

library unisim;
use unisim.vcomponents.all;

architecture IMP of Parity is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of IMP : architecture is "yes";

  -- Non-recursive loop implementation
  function ParityGen (InA : std_logic_vector) return std_logic is
    variable result : std_logic;
  begin
    result := '0';
    for I in InA'range loop
      result := result xor InA(I);
    end loop;
    return result;
  end function ParityGen;

begin  -- architecture IMP

  Using_LUT6 : if (C_USE_LUT6) generate

    --------------------------------------------------------------------------------------------------
    -- Single LUT6
    --------------------------------------------------------------------------------------------------
    Single_LUT6 : if C_SIZE > 1 and C_SIZE <= 6 generate
      signal inA6 : std_logic_vector(0 to 5);
    begin

      Assign_InA : process (InA) is
      begin
        inA6                      <= (others => '0');
        inA6(0 to InA'length - 1) <= InA;
      end process Assign_InA;

      XOR6_LUT : LUT6
        generic map(
          INIT => X"6996966996696996")
        port map(
          O  => Res,
          I0 => inA6(5),
          I1 => inA6(4),
          I2 => inA6(3),
          I3 => inA6(2),
          I4 => inA6(1),
          I5 => inA6(0));
    end generate Single_LUT6;

    --------------------------------------------------------------------------------------------------
    -- Two LUT6 and one MUXF7
    --------------------------------------------------------------------------------------------------
    Use_MUXF7 : if C_SIZE = 7 generate
      signal inA7     : std_logic_vector(0 to 6);
      signal result6  : std_logic;
      signal result6n : std_logic;
    begin

      Assign_InA : process (InA) is
      begin
        inA7                      <= (others => '0');
        inA7(0 to InA'length - 1) <= InA;
      end process Assign_InA;

      XOR6_LUT : LUT6
        generic map(
          INIT => X"6996966996696996")
        port map(
          O  => result6,
          I0 => inA7(5),
          I1 => inA7(4),
          I2 => inA7(3),
          I3 => inA7(2),
          I4 => inA7(1),
          I5 => inA7(0));

      XOR6_LUT_N : LUT6
        generic map(
          INIT => X"9669699669969669") 
        port map(
          O  => result6n,
          I0 => inA7(5),
          I1 => inA7(4),
          I2 => inA7(3),
          I3 => inA7(2),
          I4 => inA7(1),
          I5 => inA7(0));

      MUXF7_LUT : MUXF7
        port map (
          O  => Res,
          I0 => result6,
          I1 => result6n,
          S  => inA7(6));
    end generate Use_MUXF7;

    --------------------------------------------------------------------------------------------------
    -- Four LUT6, two MUXF7 and one MUXF8
    --------------------------------------------------------------------------------------------------
    Use_MUXF8 : if C_SIZE = 8 generate
      signal inA8       : std_logic_vector(0 to 7);
      signal result6_1  : std_logic;
      signal result6_1n : std_logic;
      signal result6_2  : std_logic;
      signal result6_2n : std_logic;
      signal result7_1  : std_logic;
      signal result7_1n : std_logic;
    begin

      Assign_InA : process (InA) is
      begin
        inA8                      <= (others => '0');
        inA8(0 to InA'length - 1) <= InA;
      end process Assign_InA;

      XOR6_LUT1 : LUT6
        generic map(
          INIT => X"6996966996696996")
        port map(
          O  => result6_1,
          I0 => inA8(5),
          I1 => inA8(4),
          I2 => inA8(3),
          I3 => inA8(2),
          I4 => inA8(1),
          I5 => inA8(0));

      XOR6_LUT2_N : LUT6
        generic map(
          INIT => X"9669699669969669") 
        port map(
          O  => result6_1n,
          I0 => inA8(5),
          I1 => inA8(4),
          I2 => inA8(3),
          I3 => inA8(2),
          I4 => inA8(1),
          I5 => inA8(0));

      MUXF7_LUT1 : MUXF7
        port map (
          O  => result7_1,
          I0 => result6_1,
          I1 => result6_1n,
          S  => inA8(6));

      XOR6_LUT3 : LUT6
        generic map(
          INIT => X"6996966996696996")
        port map(
          O  => result6_2,
          I0 => inA8(5),
          I1 => inA8(4),
          I2 => inA8(3),
          I3 => inA8(2),
          I4 => inA8(1),
          I5 => inA8(0));

      XOR6_LUT4_N : LUT6
        generic map(
          INIT => X"9669699669969669") 
        port map(
          O  => result6_2n,
          I0 => inA8(5),
          I1 => inA8(4),
          I2 => inA8(3),
          I3 => inA8(2),
          I4 => inA8(1),
          I5 => inA8(0));

      MUXF7_LUT2 : MUXF7
        port map (
          O  => result7_1n,
          I0 => result6_2n,
          I1 => result6_2,
          S  => inA8(6));

      MUXF8_LUT : MUXF8
        port map (
          O  => res,
          I0 => result7_1,
          I1 => result7_1n,
          S  => inA8(7));

    end generate Use_MUXF8;
  end generate Using_LUT6;

  -- Fall-back implementation without LUT6
  Not_Using_LUT6 : if not C_USE_LUT6 or C_SIZE > 8 generate
  begin
    Res <= ParityGen(InA);
  end generate Not_Using_LUT6;

end architecture IMP;


----------------------------------------------------------------------------------------------
--
-- Generated by X-HDL Verilog Translator - Version 4.0.0 Apr. 30, 2006
-- Wed Jun 17 2009 01:03:24
--
--      Input file      : /home/samsonn/SandBox_LBranch_11.2/env/Databases/ip/src2/L/mig_v3_2/data/dlib/virtex6/ddr3_sdram/verilog/rtl/ecc/ecc_gen.v
--      Component name  : ecc_gen
--      Author          : 
--      Company         : 
--
--      Description     : 
--
--
----------------------------------------------------------------------------------------------

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.std_logic_unsigned.all;
   use ieee.std_logic_arith.all;


-- Generate the ecc code.  Note that the synthesizer should
-- generate this as a static logic.  Code in this block should
-- never run during simulation phase, or directly impact timing.
--
-- The code generated is a single correct, double detect code.
-- It is the classic Hamming code.  Instead, the code is
-- optimized for minimal/balanced tree depth and size.  See
-- Hsiao IBM Technial Journal 1970.
--
-- The code is returned as a single bit vector, h_rows.  This was
-- the only way to "subroutinize" this with the restrictions of
-- disallowed include files and that matrices cannot be passed
-- in ports.
--
-- Factorial and the combos functions are defined.  Combos
-- simply computes the number of combinations from the set
-- size and elements at a time.
--
-- The function next_combo computes the next combination in
-- lexicographical order given the "current" combination.  Its
-- output is undefined if given the last combination in the 
-- lexicographical order. 
-- 
-- next_combo is insensitive to the number of elements in the
-- combinations.
--
-- An H transpose matrix is generated because that's the easiest
-- way to do it. The H transpose matrix is generated by taking
-- the one at a time combinations, then the 3 at a time, then
-- the 5 at a time.  The number combinations used is equal to
-- the width of the code (CODE_WIDTH).  The boundaries between
-- the 1, 3 and 5 groups are hardcoded in the for loop.
--
-- At the same time the h_rows vector is generated from the
-- H transpose matrix.

entity ecc_gen is
   generic (
      CODE_WIDTH                 : integer := 72;
      ECC_WIDTH                  : integer := 8;
      DATA_WIDTH                 : integer := 64
   );
   port (
      -- Outputs
      
      -- function next_combo
      -- Given a combination, return the next combo in lexicographical
      -- order.  Scans from right to left.  Assumes the first combination
      -- is k ones all of the way to the left.
      --
      -- Upon entry, initialize seen0, trig1, and ones.  "seen0" means
      -- that a zero has been observed while scanning from right to left.
      -- "trig1" means that a one have been observed _after_ seen0 is set.
      -- "ones" counts the number of ones observed while scanning the input.
      --
      -- If trig1 is one, just copy the input bit to the output and increment
      -- to the next bit.  Otherwise  set the the output bit to zero, if the 
      -- input is a one, increment ones.  If the input bit is a one and seen0
      -- is true, dump out the accumulated ones.  Set seen0 to the complement
      -- of the input bit.  Note that seen0 is not used subsequent to trig1 
      -- getting set.
      
      -- The stuff above leads to excessive XST execution times.  For now, hardwire to 72/64 bit.
      
      h_rows                     : out std_logic_vector(CODE_WIDTH * ECC_WIDTH - 1 downto 0)
   );
end entity ecc_gen;

architecture trans of ecc_gen is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of trans : architecture is "yes";

  function factorial (ivar: integer) return integer is
    variable tmp   : integer;
  begin
    if (ivar = 1) then 
        return 1;
    else 
      tmp := 1;
      for i in ivar downto 2 loop
        tmp := tmp * i;
      end loop;
    end if;
    return tmp;
  end function factorial;

  function combos ( n, k: integer) return integer is
  begin
    return factorial(n)/(factorial(k)*factorial(n-k));
  end function combos;

  
  function next_combo (i: std_logic_vector) return std_logic_vector is
    variable seen0: std_logic;
    variable trig1: std_logic;
    variable ones: std_logic_vector (ECC_WIDTH-1 downto 0);
    variable tmp: std_logic_vector (ECC_WIDTH-1 downto 0);
    variable tmp_index : integer;
    begin
      seen0 := '0';
      trig1 := '0';
      ones := (others => '0');
      for index in ECC_WIDTH -1 downto 0 loop
          tmp_index := ECC_WIDTH -1 - index;
          if (trig1 = '1') then 
            tmp(tmp_index) := i(tmp_index);
          else
            tmp(tmp_index) := '0';
            ones := ones + i(tmp_index);
            if ((i(tmp_index) = '1') and (seen0 = '1')) then
              trig1 := '1';
              for dump_index in tmp_index-1 downto 0 loop
                if (dump_index >= (tmp_index- conv_integer(ones)) ) then
                    tmp(dump_index) := '1';  
                end if;
              end loop;
            end if;              
            seen0 := not(i(tmp_index));
          end if;
      end loop;
      return tmp;
  end function next_combo;
  
  constant COMBOS_3 : integer := combos(ECC_WIDTH, 3);
  constant COMBOS_5 : integer := combos(ECC_WIDTH, 5);

   type twoDarray is array (CODE_WIDTH -1 downto 0) of std_logic_vector (ECC_WIDTH-1 downto 0);
   signal ht_matrix               : twoDarray;
begin

   columns: for n in CODE_WIDTH - 1 downto 0 generate
   
      column0: if (n = 0) generate
         ht_matrix(n) <= "111" & conv_std_logic_vector(0,ECC_WIDTH-3);
      end generate;
      
      column_combos3: if ((n = COMBOS_3) and ( n < DATA_WIDTH) ) generate
         ht_matrix(n) <= "11111" & conv_std_logic_vector(0,ECC_WIDTH-5);
      end generate;
      
      column_combos5: if ((n = COMBOS_3 + COMBOS_5) and ( n < DATA_WIDTH) ) generate
         ht_matrix(n) <= "1111111" & conv_std_logic_vector(0,ECC_WIDTH-7);
      end generate;
      
      column_datawidth: if (n = DATA_WIDTH) generate
         ht_matrix(n) <= "1" & conv_std_logic_vector(0,ECC_WIDTH-1);
      end generate;
      
      column_gen: if ( (n /= 0 ) and ((n /= COMBOS_3) or (n > DATA_WIDTH)) and ((n /= COMBOS_3+COMBOS_5) or (n > DATA_WIDTH)) and (n /= DATA_WIDTH) ) generate
        ht_matrix(n) <= next_combo(ht_matrix(n-1));
      end generate;
      
      out_assign: for s in ECC_WIDTH-1 downto 0 generate
        h_rows(s*CODE_WIDTH+n) <= ht_matrix(n)(s);
      end generate;
      
   end generate;
   --h_row0 <= "100000000100100011101101001101001000110100100010000110100100010000100000";
   --h_row1 <= "010000001010010011011010101010100100101010010001000101010010001000010000";
   --h_row2 <= "001000001001001010110110010110010010011001001000100011001001000100001000";
   --h_row3 <= "000100000111000101110001110001110001000111000100010000111000100010000100";
   --h_row4 <= "000010000000111100001111110000001111000000111100001000000111100001000010";
   --h_row5 <= "000001001111111100000000001111111111000000000011111000000000011111000001";
   --h_row6 <= "000000101111111100000000000000000000111111111111111000000000000000111111";
   --h_row7 <= "000000011111111100000000000000000000000000000000000111111111111111111111";
   --h_rows <= (h_row7 & h_row6 & h_row5 & h_row4 & h_row3 & h_row2 & h_row1 & h_row0);
end architecture trans;


-------------------------------------------------------------------------------
-- lite_ecc_reg.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
-------------------------------------------------------------------------------
-- Filename:        lite_ecc_reg.vhd
--
-- Description:     This module contains the register components for the
--                  ECC status & control data when enabled.
--
-- VHDL-Standard:   VHDL'93
--
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- correct_one_bit.vhd
--
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/2/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
--  Remove library version # dependency.  Replace with work library.
-- ^^^^^^
-- JLJ      2/17/2011         v1.03a
-- ~~~~~~
--  Add ECC support for 128-bit BRAM data width.
--  Clean-up XST warnings.  Add C_BRAM_ADDR_ADJUST_FACTOR parameter and
--  modify BRAM address registers.
-- ^^^^^^
--
--  
-------------------------------------------------------------------------------

-- Library declarations

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.axi_lite_if;
use work.axi_bram_ctrl_funcs.all;


------------------------------------------------------------------------------


entity lite_ecc_reg is
generic (


    C_S_AXI_PROTOCOL : string := "AXI4";
        -- Used in this module to differentiate timing for error capture

    C_S_AXI_ADDR_WIDTH : integer := 32;
      -- Width of AXI address bus (in bits)
    
    C_S_AXI_DATA_WIDTH : integer := 32;
      -- Width of AXI data bus (in bits)

    C_SINGLE_PORT_BRAM : INTEGER := 1;
        -- Enable single port usage of BRAM
      
    C_BRAM_ADDR_ADJUST_FACTOR   : integer := 2;
      -- Adjust factor to BRAM address width based on data width (in bits)

    -- AXI-Lite Register Parameters
    
    C_S_AXI_CTRL_ADDR_WIDTH : integer := 32;
        -- Width of AXI-Lite address bus (in bits)

    C_S_AXI_CTRL_DATA_WIDTH  : integer := 32;
        -- Width of AXI-Lite data bus (in bits)
          
    -- ECC Parameters    
            
    C_ECC_WIDTH : integer := 8;
        -- Width of ECC data vector
        
    C_FAULT_INJECT : integer := 0;
        -- Enable fault injection registers
        
    C_ECC_ONOFF_RESET_VALUE : integer := 1;
        -- By default, ECC checking is on (can disable ECC @ reset by setting this to 0)


    -- Hard coded parameters at top level.
    -- Note: Kept in design for future enhancement.
    
    C_ENABLE_AXI_CTRL_REG_IF : integer := 0;
        -- By default the ECC AXI-Lite register interface is enabled    
    
    C_CE_FAILING_REGISTERS : integer := 0;
        -- Enable CE (correctable error) failing registers
        
    C_UE_FAILING_REGISTERS : integer := 0;
        -- Enable UE (uncorrectable error) failing registers
        
    C_ECC_STATUS_REGISTERS : integer := 0;
        -- Enable ECC status registers

    C_ECC_ONOFF_REGISTER : integer := 0;
        -- Enable ECC on/off control register

    C_CE_COUNTER_WIDTH : integer := 0
        -- Selects CE counter width/threshold to assert ECC_Interrupt
    


    );
  port (


    -- AXI Clock and Reset
    S_AXI_AClk                  : in    std_logic;
    S_AXI_AResetn               : in    std_logic;      

    -- AXI-Lite Clock and Reset
    -- Note: AXI-Lite Control IF and AXI IF share the same clock.
    -- S_AXI_CTRL_AClk         : in    std_logic;
    -- S_AXI_CTRL_AResetn      : in    std_logic;      

    Interrupt                   : out   std_logic := '0';
    ECC_UE                      : out   std_logic := '0';


    -- *** AXI-Lite ECC Register Interface Signals ***
    
    -- All synchronized to S_AXI_CTRL_AClk

    -- AXI-Lite Write Address Channel Signals (AW)
    AXI_CTRL_AWVALID          : in    std_logic;
    AXI_CTRL_AWREADY          : out   std_logic;
    AXI_CTRL_AWADDR           : in    std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);

    
    -- AXI-Lite Write Data Channel Signals (W)
    AXI_CTRL_WDATA            : in    std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    AXI_CTRL_WVALID           : in    std_logic;
    AXI_CTRL_WREADY           : out   std_logic;
    

    -- AXI-Lite Write Data Response Channel Signals (B)
    AXI_CTRL_BRESP            : out   std_logic_vector(1 downto 0);
    AXI_CTRL_BVALID           : out   std_logic;
    AXI_CTRL_BREADY           : in    std_logic;
    

    -- AXI-Lite Read Address Channel Signals (AR)
    AXI_CTRL_ARADDR           : in    std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);
    AXI_CTRL_ARVALID          : in    std_logic;
    AXI_CTRL_ARREADY          : out   std_logic;


    -- AXI-Lite Read Data Channel Signals (R)
    AXI_CTRL_RDATA             : out   std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    AXI_CTRL_RRESP             : out   std_logic_vector(1 downto 0);
    AXI_CTRL_RVALID            : out   std_logic;
    AXI_CTRL_RREADY            : in    std_logic;

        
    
    -- *** Memory Controller Interface Signals ***
    
    -- All synchronized to S_AXI_AClk
    
    Enable_ECC                  : out   std_logic;
        -- Indicates if and when ECC is enabled
    
    FaultInjectClr              : in    std_logic;
        -- Clear for Fault Inject Registers
    
    CE_Failing_We               : in    std_logic;
        -- WE for CE Failing Registers

    -- UE_Failing_We               : in    std_logic;
        -- WE for CE Failing Registers
        
    CE_CounterReg_Inc           : in    std_logic;
        -- Increment CE Counter Register    
    
    Sl_CE                       : in    std_logic;
        -- Correctable Error Flag
    Sl_UE                       : in    std_logic;
        -- Uncorrectable Error Flag
    
    BRAM_Addr_A                 : in    std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR);     -- v1.03a
    BRAM_Addr_B                 : in    std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR);     -- v1.03a
    BRAM_Addr_En                : in    std_logic;
    Active_Wr                   : in    std_logic;

    -- BRAM_RdData_A               : in    std_logic_vector (0 to C_S_AXI_DATA_WIDTH-1);     
    -- BRAM_RdData_B               : in    std_logic_vector (0 to C_S_AXI_DATA_WIDTH-1); 

    -- Outputs
    FaultInjectData             : out   std_logic_vector (0 to C_S_AXI_DATA_WIDTH-1); 
    FaultInjectECC              : out   std_logic_vector (0 to C_ECC_WIDTH-1)   
    

    );



end entity lite_ecc_reg;


-------------------------------------------------------------------------------

architecture implementation of lite_ecc_reg is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------



-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------


constant C_RESET_ACTIVE     : std_logic := '0';



constant IF_IS_AXI4      : boolean := (Equal_String (C_S_AXI_PROTOCOL, "AXI4"));
constant IF_IS_AXI4LITE  : boolean := (Equal_String (C_S_AXI_PROTOCOL, "AXI4LITE"));



-- Start LMB BRAM v3.00a HDL


constant C_HAS_FAULT_INJECT         : boolean := C_FAULT_INJECT = 1;
constant C_HAS_CE_FAILING_REGISTERS : boolean := C_CE_FAILING_REGISTERS = 1;
constant C_HAS_UE_FAILING_REGISTERS : boolean := C_UE_FAILING_REGISTERS = 1;
constant C_HAS_ECC_STATUS_REGISTERS : boolean := C_ECC_STATUS_REGISTERS = 1;
constant C_HAS_ECC_ONOFF            : boolean := C_ECC_ONOFF_REGISTER = 1;
constant C_HAS_CE_COUNTER           : boolean := C_CE_COUNTER_WIDTH /= 0;


-- Register accesses
-- Register addresses use word address, i.e 2 LSB don't care
-- Don't decode MSB, i.e. mirrorring of registers in address space of module
constant C_REGADDR_WIDTH                : integer          := 8;
constant C_ECC_StatusReg                : std_logic_vector := "00000000";  -- 0x0            =     00 0000 00
constant C_ECC_EnableIRQReg             : std_logic_vector := "00000001";  -- 0x4            =     00 0000 01
constant C_ECC_OnOffReg                 : std_logic_vector := "00000010";  -- 0x8            =     00 0000 10
constant C_CE_CounterReg                : std_logic_vector := "00000011";  -- 0xC            =     00 0000 11

constant C_CE_FailingData_31_0          : std_logic_vector := "01000000";  -- 0x100          =     01 0000 00
constant C_CE_FailingData_63_31         : std_logic_vector := "01000001";  -- 0x104          =     01 0000 01
constant C_CE_FailingData_95_64         : std_logic_vector := "01000010";  -- 0x108          =     01 0000 10
constant C_CE_FailingData_127_96        : std_logic_vector := "01000011";  -- 0x10C          =     01 0000 11

constant C_CE_FailingECC                : std_logic_vector := "01100000";  -- 0x180          =     01 1000 00

constant C_CE_FailingAddress_31_0       : std_logic_vector := "01110000";  -- 0x1C0          =     01 1100 00
constant C_CE_FailingAddress_63_32      : std_logic_vector := "01110001";  -- 0x1C4          =     01 1100 01

constant C_UE_FailingData_31_0          : std_logic_vector := "10000000";  -- 0x200          =     10 0000 00
constant C_UE_FailingData_63_31         : std_logic_vector := "10000001";  -- 0x204          =     10 0000 01
constant C_UE_FailingData_95_64         : std_logic_vector := "10000010";  -- 0x208          =     10 0000 10
constant C_UE_FailingData_127_96        : std_logic_vector := "10000011";  -- 0x20C          =     10 0000 11

constant C_UE_FailingECC                : std_logic_vector := "10100000";  -- 0x280          =     10 1000 00

constant C_UE_FailingAddress_31_0       : std_logic_vector := "10110000";  -- 0x2C0          =     10 1100 00
constant C_UE_FailingAddress_63_32      : std_logic_vector := "10110000";  -- 0x2C4          =     10 1100 00

constant C_FaultInjectData_31_0         : std_logic_vector := "11000000";  -- 0x300          =     11 0000 00
constant C_FaultInjectData_63_32        : std_logic_vector := "11000001";  -- 0x304          =     11 0000 01
constant C_FaultInjectData_95_64        : std_logic_vector := "11000010";  -- 0x308          =     11 0000 10
constant C_FaultInjectData_127_96       : std_logic_vector := "11000011";  -- 0x30C          =     11 0000 11

constant C_FaultInjectECC               : std_logic_vector := "11100000";  -- 0x380          =     11 1000 00




-- ECC Status register bit positions
constant C_ECC_STATUS_CE        : natural := 30;
constant C_ECC_STATUS_UE        : natural := 31;
constant C_ECC_STATUS_WIDTH     : natural := 2;
constant C_ECC_ENABLE_IRQ_CE    : natural := 30;
constant C_ECC_ENABLE_IRQ_UE    : natural := 31;
constant C_ECC_ENABLE_IRQ_WIDTH : natural := 2;
constant C_ECC_ON_OFF_WIDTH     : natural := 1;


-- End LMB BRAM v3.00a HDL

constant MSB_ZERO        : std_logic_vector (31 downto C_S_AXI_ADDR_WIDTH) := (others => '0');



-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------



signal S_AXI_AReset : std_logic;


-- Start LMB BRAM v3.00a HDL

-- Read and write data to internal registers
constant C_DWIDTH : integer := 32;
signal RegWrData        : std_logic_vector(0 to C_DWIDTH-1) := (others => '0');
signal RegWrData_i      : std_logic_vector(0 to C_DWIDTH-1) := (others => '0');
--signal RegWrData_d1     : std_logic_vector(0 to C_DWIDTH-1) := (others => '0');
--signal RegWrData_d2     : std_logic_vector(0 to C_DWIDTH-1) := (others => '0');

signal RegRdData        : std_logic_vector(0 to C_DWIDTH-1) := (others => '0');
signal RegRdData_i      : std_logic_vector(0 to C_DWIDTH-1) := (others => '0');
--signal RegRdData_d1     : std_logic_vector(0 to C_DWIDTH-1) := (others => '0');
--signal RegRdData_d2     : std_logic_vector(0 to C_DWIDTH-1) := (others => '0');

signal RegAddr          : std_logic_vector(0 to C_REGADDR_WIDTH-1) := (others => '0'); 
signal RegAddr_i        : std_logic_vector(0 to C_REGADDR_WIDTH-1) := (others => '0'); 
--signal RegAddr_d1       : std_logic_vector(0 to C_REGADDR_WIDTH-1) := (others => '0'); 
--signal RegAddr_d2       : std_logic_vector(0 to C_REGADDR_WIDTH-1) := (others => '0'); 

signal RegWr            : std_logic;
signal RegWr_i          : std_logic;
--signal RegWr_d1         : std_logic;
--signal RegWr_d2         : std_logic;

-- Fault Inject Register
signal FaultInjectData_WE_0    : std_logic := '0';
signal FaultInjectData_WE_1    : std_logic := '0';
signal FaultInjectData_WE_2    : std_logic := '0';
signal FaultInjectData_WE_3    : std_logic := '0';

signal FaultInjectECC_WE     : std_logic := '0';
--signal FaultInjectClr        : std_logic := '0';

-- Correctable Error First Failing Register
signal CE_FailingAddress : std_logic_vector(0 to 31) := (others => '0');
signal CE_Failing_We_i   : std_logic := '0';
-- signal CE_FailingData    : std_logic_vector(0 to C_S_AXI_DATA_WIDTH-1) := (others => '0');
-- signal CE_FailingECC     : std_logic_vector(32-C_ECC_WIDTH to 31);

-- Uncorrectable Error First Failing Register
-- signal UE_FailingAddress : std_logic_vector(0 to C_S_AXI_ADDR_WIDTH-1) := (others => '0');
-- signal UE_Failing_We_i   : std_logic := '0';
-- signal UE_FailingData    : std_logic_vector(0 to C_S_AXI_DATA_WIDTH-1) := (others => '0');
-- signal UE_FailingECC     : std_logic_vector(32-C_ECC_WIDTH to 31) := (others => '0');

-- ECC Status and Control register
signal ECC_StatusReg     : std_logic_vector(32-C_ECC_STATUS_WIDTH to 31) := (others => '0');
signal ECC_StatusReg_WE  : std_logic_vector(32-C_ECC_STATUS_WIDTH to 31) := (others => '0');
signal ECC_EnableIRQReg  : std_logic_vector(32-C_ECC_ENABLE_IRQ_WIDTH to 31) := (others => '0');
signal ECC_EnableIRQReg_WE  : std_logic := '0';

-- ECC On/Off Control register
signal ECC_OnOffReg     : std_logic_vector(32-C_ECC_ON_OFF_WIDTH to 31) := (others => '0');
signal ECC_OnOffReg_WE  : std_logic := '0';

-- Correctable Error Counter
signal CE_CounterReg            : std_logic_vector(32-C_CE_COUNTER_WIDTH to 31) := (others => '0');
signal CE_CounterReg_WE         : std_logic := '0';
signal CE_CounterReg_Inc_i      : std_logic := '0';
                         


-- End LMB BRAM v3.00a HDL


signal BRAM_Addr_A_d1   : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) := (others => '0');    -- v1.03a
signal BRAM_Addr_A_d2   : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) := (others => '0');    -- v1.03a
signal FailingAddr_Ld   : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');  

signal axi_lite_wstrb_int : std_logic_vector (C_S_AXI_CTRL_DATA_WIDTH/8-1 downto 0) := (others => '0');

signal Enable_ECC_i     : std_logic := '0';
signal ECC_UE_i         : std_logic := '0';


signal FaultInjectData_i    :  std_logic_vector (0 to C_S_AXI_DATA_WIDTH-1) := (others => '0'); 
signal FaultInjectECC_i     :  std_logic_vector (0 to C_ECC_WIDTH-1) := (others => '0');


-------------------------------------------------------------------------------
-- Architecture Body
-------------------------------------------------------------------------------

begin 


        FaultInjectData <= FaultInjectData_i;
        FaultInjectECC <= FaultInjectECC_i;


        -- Reserve for future support.
        -- S_AXI_CTRL_AReset <= not (S_AXI_CTRL_AResetn);
        
        S_AXI_AReset <= not (S_AXI_AResetn);
        

        ---------------------------------------------------------------------------
        -- Instance:    I_LITE_ECC_REG
        --
        -- Description:
        --              This module is for the AXI-Lite ECC registers. 
        --
        --              Responsible for all AXI-Lite communication to the 
        --              ECC register bank.  Provides user interface signals
        --              to rest of AXI BRAM controller IP core for ECC functionality
        --              and control.
        --
        --              Manages AXI-Lite write address (AW) and read address (AR),
        --              write data (W), write response (B), and read data (R) channels.
        --
        --              Synchronized to AXI-Lite clock and reset.  
        --              All RegWr, RegWrData, RegAddr, RegRdData must be synchronized to
        --              the AXI clock.
        --
        ---------------------------------------------------------------------------

        I_AXI_LITE_IF : entity work.axi_lite_if 
        generic map(
          C_S_AXI_ADDR_WIDTH    => C_S_AXI_CTRL_ADDR_WIDTH,
          C_S_AXI_DATA_WIDTH    => C_S_AXI_CTRL_DATA_WIDTH,
          C_REGADDR_WIDTH       => C_REGADDR_WIDTH,
          C_DWIDTH              => C_DWIDTH
          )
        port map (
                    -- Reserve for future support.
                    -- LMB_Clk           => S_AXI_CTRL_AClk,
                    -- LMB_Rst           => S_AXI_CTRL_AReset,
          LMB_Clk           => S_AXI_AClk,
          LMB_Rst           => S_AXI_AReset,
          S_AXI_AWADDR      => AXI_CTRL_AWADDR,
          S_AXI_AWVALID     => AXI_CTRL_AWVALID,
          S_AXI_AWREADY     => AXI_CTRL_AWREADY,
          S_AXI_WDATA       => AXI_CTRL_WDATA,
          S_AXI_WSTRB       => axi_lite_wstrb_int,
          S_AXI_WVALID      => AXI_CTRL_WVALID,
          S_AXI_WREADY      => AXI_CTRL_WREADY,
          S_AXI_BRESP       => AXI_CTRL_BRESP,
          S_AXI_BVALID      => AXI_CTRL_BVALID,
          S_AXI_BREADY      => AXI_CTRL_BREADY,
          S_AXI_ARADDR      => AXI_CTRL_ARADDR,
          S_AXI_ARVALID     => AXI_CTRL_ARVALID,
          S_AXI_ARREADY     => AXI_CTRL_ARREADY,
          S_AXI_RDATA       => AXI_CTRL_RDATA,
          S_AXI_RRESP       => AXI_CTRL_RRESP,
          S_AXI_RVALID      => AXI_CTRL_RVALID,
          S_AXI_RREADY      => AXI_CTRL_RREADY,
          RegWr             => RegWr_i,
          RegWrData         => RegWrData_i,
          RegAddr           => RegAddr_i,
          RegRdData         => RegRdData_i
          
          );
    
    
    -- Note: AXI-Lite Control IF and AXI IF share the same clock.
    --
    -- Save HDL
    -- If it is decided to go back and use seperate clock inputs
    -- One for AXI4 and one for AXI4-Lite on this core.
    -- For now, temporarily comment out and replace the *_i signal 
    -- assignments.
    
    RegWr <= RegWr_i;
    RegWrData <= RegWrData_i;
    RegAddr <= RegAddr_i;
    RegRdData_i <= RegRdData;
    
    
    -- Reserve for future support.
    --
    --        ---------------------------------------------------------------------------
    --        -- 
    --        -- All registers must be synchronized to the correct clock.
    --        -- RegWr must be synchronized to the S_AXI_Clk
    --        -- RegWrData must be synchronized to the S_AXI_Clk
    --        -- RegAddr must be synchronized to the S_AXI_Clk
    --        -- RegRdData must be synchronized to the S_AXI_CTRL_Clk
    --        --
    --        ---------------------------------------------------------------------------
    --    
    --        SYNC_AXI_CLK: process (S_AXI_AClk)
    --        begin
    --            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
    --                RegWr_d1 <= RegWr_i;
    --                RegWr_d2 <= RegWr_d1;
    --                RegWrData_d1 <= RegWrData_i;
    --                RegWrData_d2 <= RegWrData_d1;
    --                RegAddr_d1 <= RegAddr_i;
    --                RegAddr_d2 <= RegAddr_d1;
    --            end if;
    --        end process SYNC_AXI_CLK;
    --        
    --        RegWr <= RegWr_d2;
    --        RegWrData <= RegWrData_d2;
    --        RegAddr <= RegAddr_d2;
    --        
    --        
    --        SYNC_AXI_LITE_CLK: process (S_AXI_CTRL_AClk)
    --        begin
    --            if (S_AXI_CTRL_AClk'event and S_AXI_CTRL_AClk = '1' ) then
    --                RegRdData_d1 <= RegRdData;
    --                RegRdData_d2 <= RegRdData_d1;
    --            end if;
    --        end process SYNC_AXI_LITE_CLK;
    --    
    --        RegRdData_i <= RegRdData_d2;
    --        

    
    ---------------------------------------------------------------------------

    axi_lite_wstrb_int <= (others => '1');

        
    ---------------------------------------------------------------------------
    -- Generate:    GEN_ADDR_REG_SNG
    -- Purpose:     Generate two deep wrap-around address pipeline to store
    --              read address presented to BRAM.  Used to update ECC
    --              register value when ECC correctable or uncorrectable error
    --              is detected.
    --              
    --              If single port, only register Port A address.
    --
    --              With CE flag being registered, must account for one more
    --              pipeline stage in stored BRAM addresss that correlates to
    --              failing ECC.
    ---------------------------------------------------------------------------
    GEN_ADDR_REG_SNG: if (C_SINGLE_PORT_BRAM = 1) generate

    -- 3rd pipeline stage on Port A (used for reads in single port mode) ONLY
    signal BRAM_Addr_A_d3   : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) := (others => '0');    -- v1.03a

    begin

        BRAM_ADDR_REG: process (S_AXI_AClk)
        begin
            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then                
                if (BRAM_Addr_En = '1') then    
                    BRAM_Addr_A_d1 <= BRAM_Addr_A;
                    BRAM_Addr_A_d2 <= BRAM_Addr_A_d1;
                    BRAM_Addr_A_d3 <= BRAM_Addr_A_d2;
                else
                    BRAM_Addr_A_d1 <= BRAM_Addr_A_d1;
                    BRAM_Addr_A_d2 <= BRAM_Addr_A_d2;
                    BRAM_Addr_A_d3 <= BRAM_Addr_A_d3;
                end if;
            end if;
        end process BRAM_ADDR_REG;
        
        ---------------------------------------------------------------------------
        -- Generate:    GEN_L_ADDR
        -- Purpose:     Lower order BRAM address bits fixed @ zero depending
        --              on BRAM data width size.
        ---------------------------------------------------------------------------
        GEN_L_ADDR: for i in C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0 generate
        begin    
            FailingAddr_Ld (i) <= '0';
        end generate GEN_L_ADDR;

        ---------------------------------------------------------------------------
        -- Generate:    GEN_ADDR
        -- Purpose:     Assign valid BRAM address bits based on BRAM data width size.
        ---------------------------------------------------------------------------
        GEN_ADDR: for i in C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR generate
        begin    

            GEN_FA_LITE: if IF_IS_AXI4LITE generate
            begin
                FailingAddr_Ld (i) <= BRAM_Addr_A_d1(i); -- Only a single address active at a time.
            end generate GEN_FA_LITE;

            GEN_FA_AXI: if IF_IS_AXI4 generate
            begin
                -- During the RMW portion, only one active address (use _d1 pipeline).
                -- During read operaitons, use 3-deep address pipeline to store address values.
                FailingAddr_Ld (i) <= BRAM_Addr_A_d3 (i) when (Active_Wr = '0') else BRAM_Addr_A_d1 (i);
            end generate GEN_FA_AXI;

        end generate GEN_ADDR;

        
    end generate GEN_ADDR_REG_SNG;


    ---------------------------------------------------------------------------
    -- Generate:    GEN_ADDR_REG_DUAL
    -- Purpose:     Generate two deep wrap-around address pipeline to store
    --              read address presented to BRAM.  Used to update ECC
    --              register value when ECC correctable or uncorrectable error
    --              is detected.
    --
    --              If dual port BRAM, register Port A & Port B address.
    --
    --              Account for CE flag register delay, add 3rd BRAM address
    --              pipeline stage.
    --
    ---------------------------------------------------------------------------
    GEN_ADDR_REG_DUAL: if (C_SINGLE_PORT_BRAM = 0) generate

    -- Port B pipeline stages only used in a dual port mode configuration.
    signal BRAM_Addr_B_d1   : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) := (others => '0');    -- v1.03a
    signal BRAM_Addr_B_d2   : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) := (others => '0');    -- v1.03a
    signal BRAM_Addr_B_d3   : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) := (others => '0');    -- v1.03a

    begin
    
        BRAM_ADDR_REG: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
                if (BRAM_Addr_En = '1') then            
                    BRAM_Addr_A_d1 <= BRAM_Addr_A;
                    BRAM_Addr_B_d1 <= BRAM_Addr_B;
                    BRAM_Addr_B_d2 <= BRAM_Addr_B_d1;
                    BRAM_Addr_B_d3 <= BRAM_Addr_B_d2;
                else
                    BRAM_Addr_A_d1 <= BRAM_Addr_A_d1;
                    BRAM_Addr_B_d1 <= BRAM_Addr_B_d1;
                    BRAM_Addr_B_d2 <= BRAM_Addr_B_d2;
                    BRAM_Addr_B_d3 <= BRAM_Addr_B_d3;
                end if;
            end if;

        end process BRAM_ADDR_REG;

            
        ---------------------------------------------------------------------------
        -- Generate:    GEN_L_ADDR
        -- Purpose:     Lower order BRAM address bits fixed @ zero depending
        --              on BRAM data width size.
        ---------------------------------------------------------------------------
        GEN_L_ADDR: for i in C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0 generate
        begin    
            FailingAddr_Ld (i) <= '0';
        end generate GEN_L_ADDR;


        ---------------------------------------------------------------------------
        -- Generate:    GEN_ADDR
        -- Purpose:     Assign valid BRAM address bits based on BRAM data width size.
        ---------------------------------------------------------------------------
        GEN_ADDR: for i in C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR generate
        begin    

            GEN_FA_LITE: if IF_IS_AXI4LITE generate
            begin
                -- Only one active operation at a time.
                -- Use one deep address pipeline.  Determine if Port A or B based on active read or write.
                FailingAddr_Ld (i) <= BRAM_Addr_B_d1 (i) when (Active_Wr = '0') else BRAM_Addr_A_d1 (i);
            end generate GEN_FA_LITE;

            GEN_FA_AXI: if IF_IS_AXI4 generate
            begin
                -- During the RMW portion, only one active address (use _d1 pipeline) (and from Port A).
                -- During read operations, use 3-deep address pipeline to store address values (and from Port B).
                FailingAddr_Ld (i) <= BRAM_Addr_B_d3 (i) when (Active_Wr = '0') else BRAM_Addr_A_d1 (i);
            end generate GEN_FA_AXI;

        end generate GEN_ADDR;

    end generate GEN_ADDR_REG_DUAL;



    ---------------------------------------------------------------------------
    -- Generate:    FAULT_INJECT
    -- Purpose:     Implement fault injection registers
    --              Remove check for (C_WRITE_ACCESS /= NO_WRITES) (from LMB)
    ---------------------------------------------------------------------------
    FAULT_INJECT : if C_HAS_FAULT_INJECT generate
    begin
    

        -- FaultInjectClr added to top level port list.
        -- Original LMB BRAM HDL
        -- FaultInjectClr <= '1' when ((sl_ready_i = '1') and (write_access = '1')) else '0';
    

        ---------------------------------------------------------------------------
        -- Generate:    GEN_32_FAULT
        -- Purpose:     Create generates based on 32-bit C_S_AXI_DATA_WIDTH
        ---------------------------------------------------------------------------

        GEN_32_FAULT : if C_S_AXI_DATA_WIDTH = 32 generate
        begin
        
            FaultInjectData_WE_0 <= '1' when (RegWr = '1' and RegAddr = C_FaultInjectData_31_0) else '0';
            FaultInjectECC_WE <= '1' when (RegWr = '1' and RegAddr = C_FaultInjectECC) else '0';
            
            
            -- Create fault vector for 32-bit data widths
            FaultInjectDataReg : process(S_AXI_AClk) is
            begin
                if S_AXI_AClk'event and S_AXI_AClk = '1' then
                    if S_AXI_AResetn = C_RESET_ACTIVE then
                        FaultInjectData_i <= (others => '0');
                        FaultInjectECC_i <= (others => '0');
                        
                    elsif FaultInjectData_WE_0 = '1' then
                       FaultInjectData_i (0 to 31) <= RegWrData;
            
                    elsif FaultInjectECC_WE = '1' then
                        -- FaultInjectECC_i <= RegWrData(0 to C_DWIDTH-1);
                        -- FaultInjectECC_i <= RegWrData(0 to C_ECC_WIDTH-1);
                        -- (25:31)
                        FaultInjectECC_i <= RegWrData(C_S_AXI_CTRL_DATA_WIDTH-C_ECC_WIDTH to C_S_AXI_CTRL_DATA_WIDTH-1);
  
                    elsif FaultInjectClr = '1' then  -- One shoot, clear after first LMB write
                        FaultInjectData_i <= (others => '0');
                        FaultInjectECC_i <= (others => '0');
                    end if;
                end if;
            end process FaultInjectDataReg;
            
        end generate GEN_32_FAULT;


        ---------------------------------------------------------------------------
        -- Generate:    GEN_64_FAULT
        -- Purpose:     Create generates based on 64-bit C_S_AXI_DATA_WIDTH
        ---------------------------------------------------------------------------

        GEN_64_FAULT : if C_S_AXI_DATA_WIDTH = 64 generate
        begin
        
            FaultInjectData_WE_0 <= '1' when (RegWr = '1' and RegAddr = C_FaultInjectData_31_0) else '0';
            FaultInjectData_WE_1 <= '1' when (RegWr = '1' and RegAddr = C_FaultInjectData_63_32) else '0';
            FaultInjectECC_WE <= '1' when (RegWr = '1' and RegAddr = C_FaultInjectECC) else '0';

            -- Create fault vector for 64-bit data widths
            FaultInjectDataReg : process(S_AXI_AClk) is
            begin
                if S_AXI_AClk'event and S_AXI_AClk = '1' then
                    if S_AXI_AResetn = C_RESET_ACTIVE then
                        FaultInjectData_i <= (others => '0');
                        FaultInjectECC_i <= (others => '0');
                        
                    elsif FaultInjectData_WE_0 = '1' then
                        FaultInjectData_i (32 to 63) <= RegWrData;
                    elsif FaultInjectData_WE_1 = '1' then
                        FaultInjectData_i (0 to 31) <= RegWrData;
            
                    elsif FaultInjectECC_WE = '1' then
                        -- FaultInjectECC_i <= RegWrData(0 to C_DWIDTH-1);
                        -- FaultInjectECC_i <= RegWrData(0 to C_ECC_WIDTH-1);
                        -- (24:31)
                        FaultInjectECC_i <= RegWrData(C_S_AXI_CTRL_DATA_WIDTH-C_ECC_WIDTH to C_S_AXI_CTRL_DATA_WIDTH-1);
      
                    elsif FaultInjectClr = '1' then  -- One shoot, clear after first LMB write
                        FaultInjectData_i <= (others => '0');
                        FaultInjectECC_i <= (others => '0');
                    end if;
                end if;
            end process FaultInjectDataReg;

        end generate GEN_64_FAULT;


        -- v1.03a
        
        ---------------------------------------------------------------------------
        -- Generate:    GEN_128_FAULT
        -- Purpose:     Create generates based on 128-bit C_S_AXI_DATA_WIDTH
        ---------------------------------------------------------------------------
        
        GEN_128_FAULT : if C_S_AXI_DATA_WIDTH = 128 generate
        begin
        
            FaultInjectData_WE_0 <= '1' when (RegWr = '1' and RegAddr = C_FaultInjectData_31_0) else '0';
            FaultInjectData_WE_1 <= '1' when (RegWr = '1' and RegAddr = C_FaultInjectData_63_32) else '0';
            FaultInjectData_WE_2 <= '1' when (RegWr = '1' and RegAddr = C_FaultInjectData_95_64) else '0';
            FaultInjectData_WE_3 <= '1' when (RegWr = '1' and RegAddr = C_FaultInjectData_127_96) else '0';
            FaultInjectECC_WE <= '1' when (RegWr = '1' and RegAddr = C_FaultInjectECC) else '0';
            
            
            -- Create fault vector for 128-bit data widths
            FaultInjectDataReg : process(S_AXI_AClk) is
            begin
                if S_AXI_AClk'event and S_AXI_AClk = '1' then
                    if S_AXI_AResetn = C_RESET_ACTIVE then
                        FaultInjectData_i <= (others => '0');
                        FaultInjectECC_i <= (others => '0');
                        
                    elsif FaultInjectData_WE_0 = '1' then
                        FaultInjectData_i (96 to 127) <= RegWrData;
                    elsif FaultInjectData_WE_1 = '1' then
                        FaultInjectData_i (64 to 95) <= RegWrData;
                    elsif FaultInjectData_WE_2 = '1' then
                        FaultInjectData_i (32 to 63) <= RegWrData;
                    elsif FaultInjectData_WE_3 = '1' then
                        FaultInjectData_i (0 to 31) <= RegWrData;
            
                    elsif FaultInjectECC_WE = '1' then
                        FaultInjectECC_i <= RegWrData(C_S_AXI_CTRL_DATA_WIDTH-C_ECC_WIDTH to C_S_AXI_CTRL_DATA_WIDTH-1);
                        
                    elsif FaultInjectClr = '1' then  -- One shoot, clear after first LMB write
                        FaultInjectData_i <= (others => '0');
                        FaultInjectECC_i <= (others => '0');
                    end if;
                end if;
            end process FaultInjectDataReg;                   
        
        
        end generate GEN_128_FAULT;
        
        
    end generate FAULT_INJECT;
      

    ---------------------------------------------------------------------------
    -- Generate:    NO_FAULT_INJECT
    -- Purpose:     Set default outputs when no fault inject capabilities.
    --              Remove check from C_WRITE_ACCESS (from LMB)
    ---------------------------------------------------------------------------
    NO_FAULT_INJECT : if not C_HAS_FAULT_INJECT generate
    begin
        FaultInjectData_i <= (others => '0');
        FaultInjectECC_i  <= (others => '0');
    end generate NO_FAULT_INJECT;
    
     
    ---------------------------------------------------------------------------
    -- Generate:    CE_FAILING_REGISTERS
    -- Purpose:     Implement Correctable Error First Failing Register
    ---------------------------------------------------------------------------
     
      CE_FAILING_REGISTERS : if C_HAS_CE_FAILING_REGISTERS generate
      begin

        -- TBD (could come from axi_lite)
        -- CE_Failing_We <= '1' when (Sl_CE_i = '1' and Sl_Ready_i = '1' and ECC_StatusReg(C_ECC_STATUS_CE) = '0')
        --             else '0';
        
        
        CE_Failing_We_i <= '1' when (CE_Failing_We = '1' and ECC_StatusReg(C_ECC_STATUS_CE) = '0')
                        else '0';
        
        CE_FailingReg : process(S_AXI_AClk) is
        begin
          if S_AXI_AClk'event and S_AXI_AClk = '1' then
            if S_AXI_AResetn = C_RESET_ACTIVE then
                CE_FailingAddress <= (others => '0');
                
                -- Reserve for future support.
                -- CE_FailingData    <= (others => '0');
            elsif CE_Failing_We_i = '1' then
	 --As the AXI Addr Width can now be lesser than 32, the address is getting shifted
     --Eg: If addr width is 16, and Failing address is 0000_fffc, the o/p on RDATA is comming as fffc_0000
                CE_FailingAddress (0 to C_S_AXI_ADDR_WIDTH-1) <= FailingAddr_Ld (C_S_AXI_ADDR_WIDTH-1 downto 0); 
                --CE_FailingAddress <= MSB_ZERO & FailingAddr_Ld ;
                
                -- Reserve for future support.
                -- CE_FailingData (0 to C_S_AXI_DATA_WIDTH-1) <= FailingRdData(0 to C_DWIDTH-1);
            end if;
          end if;
        end process CE_FailingReg;            


        -- Note: Remove storage of CE_FFE & CE_FFD registers.
        -- Here for future support.
        --
        --         -----------------------------------------------------------------
        --         -- Generate:  GEN_CE_ECC_32
        --         -- Purpose:   Re-align ECC bits unique for 32-bit BRAM data width.
        --         -----------------------------------------------------------------
        --         GEN_CE_ECC_32: if C_S_AXI_DATA_WIDTH = 32 generate
        --         begin
        -- 
        --             CE_FailingECCReg : process(S_AXI_AClk) is
        --             begin
        --               if S_AXI_AClk'event and S_AXI_AClk = '1' then
        --                 if S_AXI_AResetn = C_RESET_ACTIVE then
        --                     CE_FailingECC     <= (others => '0');
        --                 elsif CE_Failing_We_i = '1' then
        --                     -- Data2Mem shifts ECC to lower data bits in remaining byte (when 32-bit data width) (33 to 39)
        --                     CE_FailingECC <= FailingRdData(C_S_AXI_DATA_WIDTH+1 to C_S_AXI_DATA_WIDTH+1+C_ECC_WIDTH-1);
        --                 end if;
        --               end if;
        --             end process CE_FailingECCReg;            
        -- 
        --         end generate GEN_CE_ECC_32;
        -- 
        --         -----------------------------------------------------------------
        --         -- Generate:  GEN_CE_ECC_64
        --         -- Purpose:   Re-align ECC bits unique for 64-bit BRAM data width.
        --         -----------------------------------------------------------------
        --         GEN_CE_ECC_64: if C_S_AXI_DATA_WIDTH = 64 generate
        --         begin
        -- 
        --             CE_FailingECCReg : process(S_AXI_AClk) is
        --             begin
        --               if S_AXI_AClk'event and S_AXI_AClk = '1' then
        --                 if S_AXI_AResetn = C_RESET_ACTIVE then
        --                     CE_FailingECC     <= (others => '0');
        --                 elsif CE_Failing_We_i = '1' then
        --                     CE_FailingECC <= FailingRdData(C_S_AXI_DATA_WIDTH to C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1);
        --                 end if;
        --               end if;
        --             end process CE_FailingECCReg;            
        -- 
        --         end generate GEN_CE_ECC_64;


    end generate CE_FAILING_REGISTERS;
      
      
    ---------------------------------------------------------------------------
    -- Generate:    NO_CE_FAILING_REGISTERS
    -- Purpose:     No Correctable Error Failing registers.
    ---------------------------------------------------------------------------
      
      NO_CE_FAILING_REGISTERS : if not C_HAS_CE_FAILING_REGISTERS generate
      begin
            CE_FailingAddress <= (others => '0');
            -- CE_FailingData    <= (others => '0');
            -- CE_FailingECC     <= (others => '0');
      end generate NO_CE_FAILING_REGISTERS;
      


    -- Note: C_HAS_UE_FAILING_REGISTERS will always be set to 0
    -- This generate clause will never be evaluated.
    -- Here for future support.
    --         
    --       ---------------------------------------------------------------------------
    --       -- Generate:    UE_FAILING_REGISTERS
    --       -- Purpose:     Implement Unorrectable Error First Failing Register
    --       ---------------------------------------------------------------------------
    --   
    --         UE_FAILING_REGISTERS : if C_HAS_UE_FAILING_REGISTERS generate
    --         begin
    --         
    --           -- TBD (could come from axi_lite)
    --           -- UE_Failing_We <= '1' when (Sl_UE_i = '1' and Sl_Ready_i = '1' and ECC_StatusReg(C_ECC_STATUS_UE) = '0')
    --           --             else '0';
    --           
    --           UE_Failing_We_i <= '1' when (UE_Failing_We = '1' and ECC_StatusReg(C_ECC_STATUS_UE) = '0')
    --                           else '0';
    --   
    --         
    --           UE_FailingReg : process(S_AXI_AClk) is
    --           begin
    --             if S_AXI_AClk'event and S_AXI_AClk = '1' then
    --               if S_AXI_AResetn = C_RESET_ACTIVE then
    --                 UE_FailingAddress <= (others => '0');
    --                 UE_FailingData    <= (others => '0');
    --               elsif UE_Failing_We = '1' then
    --                 UE_FailingAddress <= FailingAddr_Ld;
    --                 UE_FailingData    <= FailingRdData(0 to C_DWIDTH-1);                            
    --               end if;
    --             end if;
    --           end process UE_FailingReg;
    --   
    --           -----------------------------------------------------------------
    --           -- Generate:  GEN_UE_ECC_32
    --           -- Purpose:   Re-align ECC bits unique for 32-bit BRAM data width.
    --           -----------------------------------------------------------------
    --           GEN_UE_ECC_32: if C_S_AXI_DATA_WIDTH = 32 generate
    --           begin
    --   
    --               UE_FailingECCReg : process(S_AXI_AClk) is
    --               begin
    --                 if S_AXI_AClk'event and S_AXI_AClk = '1' then
    --                   if S_AXI_AResetn = C_RESET_ACTIVE then
    --                       UE_FailingECC     <= (others => '0');
    --                   elsif UE_Failing_We = '1' then
    --                       -- Data2Mem shifts ECC to lower data bits in remaining byte (when 32-bit data width) (33 to 39)
    --                       UE_FailingECC <= FailingRdData(C_S_AXI_DATA_WIDTH+1 to C_S_AXI_DATA_WIDTH+1+C_ECC_WIDTH-1);
    --                   end if;
    --                 end if;
    --               end process UE_FailingECCReg;
    --   
    --           end generate GEN_UE_ECC_32;
    --       
    --           -----------------------------------------------------------------
    --           -- Generate:  GEN_UE_ECC_64
    --           -- Purpose:   Re-align ECC bits unique for 64-bit BRAM data width.
    --           -----------------------------------------------------------------
    --           GEN_UE_ECC_64: if C_S_AXI_DATA_WIDTH = 64 generate
    --           begin
    --   
    --               UE_FailingECCReg : process(S_AXI_AClk) is
    --               begin
    --                 if S_AXI_AClk'event and S_AXI_AClk = '1' then
    --                   if S_AXI_AResetn = C_RESET_ACTIVE then
    --                       UE_FailingECC     <= (others => '0');
    --                   elsif UE_Failing_We = '1' then
    --                       UE_FailingECC <= FailingRdData(C_S_AXI_DATA_WIDTH to C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1);
    --                   end if;
    --                 end if;
    --               end process UE_FailingECCReg;
    --   
    --           end generate GEN_UE_ECC_64;
    --           
    --         end generate UE_FAILING_REGISTERS;
    --       
    -- 
    --     ---------------------------------------------------------------------------
    --     -- Generate:    NO_UE_FAILING_REGISTERS
    --     -- Purpose:     No Uncorrectable Error Failing registers.
    --     ---------------------------------------------------------------------------
    --
    --      NO_UE_FAILING_REGISTERS : if not C_HAS_UE_FAILING_REGISTERS generate
    --      begin
    --            UE_FailingAddress <= (others => '0');
    --            UE_FailingData    <= (others => '0');
    --            UE_FailingECC     <= (others => '0');
    --      end generate NO_UE_FAILING_REGISTERS;


    ---------------------------------------------------------------------------
    -- Generate:    ECC_STATUS_REGISTERS
    -- Purpose:     Enable ECC status and interrupt enable registers.
    ---------------------------------------------------------------------------

    ECC_STATUS_REGISTERS : if C_HAS_ECC_STATUS_REGISTERS generate
    begin

        
        ECC_StatusReg_WE (C_ECC_STATUS_CE) <= Sl_CE;
        ECC_StatusReg_WE (C_ECC_STATUS_UE) <= Sl_UE;

        StatusReg : process(S_AXI_AClk) is
        begin
          if S_AXI_AClk'event and S_AXI_AClk = '1' then
            if S_AXI_AResetn = C_RESET_ACTIVE then
              ECC_StatusReg <= (others => '0');
              
            elsif RegWr = '1' and RegAddr = C_ECC_StatusReg then
                -- CE Interrupt status bit
                if RegWrData(C_ECC_STATUS_CE) = '1' then
                    ECC_StatusReg(C_ECC_STATUS_CE) <= '0';  -- Clear when write '1'
                end if;
                -- UE Interrupt status bit
                if RegWrData(C_ECC_STATUS_UE) = '1' then
                    ECC_StatusReg(C_ECC_STATUS_UE) <= '0';  -- Clear when write '1'
                end if;
            else
                if Sl_CE = '1' then
                    ECC_StatusReg(C_ECC_STATUS_CE) <= '1';  -- Set when CE occurs
                end if;
                if Sl_UE = '1' then
                    ECC_StatusReg(C_ECC_STATUS_UE) <= '1';  -- Set when UE occurs
                end if;
            end if;
          end if;    
        end process StatusReg;


        ECC_EnableIRQReg_WE <= '1' when (RegWr = '1' and RegAddr = C_ECC_EnableIRQReg) else '0';

        EnableIRQReg : process(S_AXI_AClk) is
        begin
          if S_AXI_AClk'event and S_AXI_AClk = '1' then
                if S_AXI_AResetn = C_RESET_ACTIVE then
                    ECC_EnableIRQReg <= (others => '0');
                elsif ECC_EnableIRQReg_WE = '1' then
                    -- CE Interrupt enable bit
                    ECC_EnableIRQReg(C_ECC_ENABLE_IRQ_CE) <= RegWrData(C_ECC_ENABLE_IRQ_CE);
                    -- UE Interrupt enable bit
                    ECC_EnableIRQReg(C_ECC_ENABLE_IRQ_UE) <= RegWrData(C_ECC_ENABLE_IRQ_UE);
             end if;
          end if;    
        end process EnableIRQReg;
        
        Interrupt <= (ECC_StatusReg(C_ECC_STATUS_CE) and ECC_EnableIRQReg(C_ECC_ENABLE_IRQ_CE)) or 
                     (ECC_StatusReg(C_ECC_STATUS_UE) and ECC_EnableIRQReg(C_ECC_ENABLE_IRQ_UE));



        ---------------------------------------------------------------------------

        -- Generate output flag for UE sticky bit
        -- Modify order to ensure that ECC_UE gets set when Sl_UE is asserted.
        REG_UE : process (S_AXI_AClk) is
        begin
            if S_AXI_AClk'event and S_AXI_AClk = '1' then
                if S_AXI_AResetn = C_RESET_ACTIVE or 
                    (Enable_ECC_i = '0') then
                    ECC_UE_i <= '0';
                
                elsif Sl_UE = '1' then
                    ECC_UE_i <= '1';
                    
                elsif (ECC_StatusReg (C_ECC_STATUS_UE) = '0') then
                    ECC_UE_i <= '0';
                else
                    ECC_UE_i <= ECC_UE_i;
                end if;
            end if;    
        end process REG_UE;

        ECC_UE <= ECC_UE_i;
        
        ---------------------------------------------------------------------------

      end generate ECC_STATUS_REGISTERS;



    ---------------------------------------------------------------------------
    -- Generate:    NO_ECC_STATUS_REGISTERS
    -- Purpose:     No ECC status or interrupt registers enabled.
    ---------------------------------------------------------------------------

      NO_ECC_STATUS_REGISTERS : if not C_HAS_ECC_STATUS_REGISTERS generate
      begin
            ECC_EnableIRQReg <= (others => '0');
            ECC_StatusReg <= (others => '0');
            Interrupt <= '0';
            ECC_UE <= '0';            
      end generate NO_ECC_STATUS_REGISTERS;



    ---------------------------------------------------------------------------
    -- Generate:    GEN_ECC_ONOFF
    -- Purpose:     Implement ECC on/off control register.
    ---------------------------------------------------------------------------
    GEN_ECC_ONOFF : if C_HAS_ECC_ONOFF generate
    begin

        ECC_OnOffReg_WE <= '1' when (RegWr = '1' and RegAddr = C_ECC_OnOffReg) else '0';

        EnableIRQReg : process(S_AXI_AClk) is
        begin
            if S_AXI_AClk'event and S_AXI_AClk = '1' then
                if S_AXI_AResetn = C_RESET_ACTIVE then
                    
                    if (C_ECC_ONOFF_RESET_VALUE = 0) then
                        ECC_OnOffReg(32-C_ECC_ON_OFF_WIDTH) <= '0'; 
                    else
                        ECC_OnOffReg(32-C_ECC_ON_OFF_WIDTH) <= '1';                     
                    end if;
                        -- ECC on by default at reset (but can be disabled)
                elsif ECC_OnOffReg_WE = '1' then
                    ECC_OnOffReg(32-C_ECC_ON_OFF_WIDTH) <= RegWrData(32-C_ECC_ON_OFF_WIDTH);
                end if;
            end if;    
        end process EnableIRQReg;

        Enable_ECC_i <= ECC_OnOffReg(32-C_ECC_ON_OFF_WIDTH); 
        Enable_ECC <= Enable_ECC_i;

    end generate GEN_ECC_ONOFF;


    ---------------------------------------------------------------------------
    -- Generate:    GEN_NO_ECC_ONOFF
    -- Purpose:     No ECC on/off control register.
    ---------------------------------------------------------------------------
    GEN_NO_ECC_ONOFF : if not C_HAS_ECC_ONOFF generate
    begin
        Enable_ECC <= '0'; 
        
        -- ECC ON/OFF register is only enabled when C_ECC = 1.
        -- If C_ECC = 0, then no ECC on/off register (C_HAS_ECC_ONOFF = 0) then
        -- ECC should be disabled.
        
        ECC_OnOffReg(32-C_ECC_ON_OFF_WIDTH) <= '0';

    end generate GEN_NO_ECC_ONOFF;
    

    ---------------------------------------------------------------------------
    -- Generate:    CE_COUNTER
    -- Purpose:     Enable Correctable Error Counter
    --              Fixed to size of C_CE_COUNTER_WIDTH = 8 bits.
    --              Parameterized here for future enhancements.
    ---------------------------------------------------------------------------

      CE_COUNTER : if C_HAS_CE_COUNTER generate
        -- One extra bit compare to CE_CounterReg to handle carry bit
        signal CE_CounterReg_plus_1 : std_logic_vector(31-C_CE_COUNTER_WIDTH to 31);
      begin

       CE_CounterReg_WE <= '1' when (RegWr = '1' and RegAddr = C_CE_CounterReg) else '0';

        -- TBD (could come from axi_lite)
       -- CE_CounterReg_Inc <= '1' when (Sl_CE_i = '1' and Sl_Ready_i = '1' and 
       --                              CE_CounterReg_plus_1(CE_CounterReg_plus_1'left) = '0') 
       --                       else '0';

       CE_CounterReg_Inc_i <= '1' when (CE_CounterReg_Inc = '1' and 
                                    CE_CounterReg_plus_1(CE_CounterReg_plus_1'left) = '0') 
                             else '0';


        CountReg : process(S_AXI_AClk) is
        begin
          if (S_AXI_AClk'event and S_AXI_AClk = '1') then
            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                CE_CounterReg <= (others => '0');
            elsif CE_CounterReg_WE = '1' then
                -- CE_CounterReg <= RegWrData(0 to C_DWIDTH-1);
                CE_CounterReg <= RegWrData(32-C_CE_COUNTER_WIDTH to 31);
            elsif CE_CounterReg_Inc_i = '1' then
                CE_CounterReg <= CE_CounterReg_plus_1(32-C_CE_COUNTER_WIDTH to 31);
            end if;
          end if;
        end process CountReg;

        CE_CounterReg_plus_1 <= std_logic_vector(unsigned(('0' & CE_CounterReg)) + 1);
        
      end generate CE_COUNTER;


    -- Note: Hit this generate when C_ECC = 0.
    -- Reserve for future support.
    -- 
    --     ---------------------------------------------------------------------------
    --     -- Generate:    NO_CE_COUNTER
    --     -- Purpose:     Default for no CE counter register.
    --     ---------------------------------------------------------------------------
    -- 
    --     NO_CE_COUNTER : if not C_HAS_CE_COUNTER generate
    --     begin
    --           CE_CounterReg <= (others => '0');
    --     end generate NO_CE_COUNTER;


    ---------------------------------------------------------------------------
    -- Generate:    GEN_REG_32_DATA
    -- Purpose:     Generate read register values & signal assignments based on
    --              32-bit BRAM data width.
    ---------------------------------------------------------------------------
    
    GEN_REG_32_DATA: if C_S_AXI_DATA_WIDTH = 32 generate
    begin

      SelRegRdData : process (RegAddr, ECC_StatusReg, ECC_EnableIRQReg, ECC_OnOffReg, 
                              CE_CounterReg, CE_FailingAddress,
                              FaultInjectData_i,
                              FaultInjectECC_i
                              -- CE_FailingData, CE_FailingECC,
                              -- UE_FailingAddress, UE_FailingData, UE_FailingECC
                              )
      begin
        RegRdData <= (others => '0');

        case RegAddr is
          -- Replace 'range use here for vector (31:0) (AXI BRAM) and (0:31) (LMB BRAM) reassignment                
          when C_ECC_StatusReg              => RegRdData(ECC_StatusReg'range) <= ECC_StatusReg;
          when C_ECC_EnableIRQReg           => RegRdData(ECC_EnableIRQReg'range) <= ECC_EnableIRQReg;
          when C_ECC_OnOffReg               => RegRdData(ECC_OnOffReg'range) <= ECC_OnOffReg;
          when C_CE_CounterReg              => RegRdData(CE_CounterReg'range) <= CE_CounterReg;
          when C_CE_FailingAddress_31_0     => RegRdData(CE_FailingAddress'range) <= CE_FailingAddress;
          when C_CE_FailingAddress_63_32    => RegRdData(0 to C_DWIDTH-1) <= (others => '0');
          
          -- Temporary addition to readback fault inject register values
          when C_FaultInjectData_31_0       => RegRdData(0 to C_DWIDTH-1) <= FaultInjectData_i (0 to 31);
          when C_FaultInjectECC             => RegRdData(C_DWIDTH-C_ECC_WIDTH to C_DWIDTH-1) <= FaultInjectECC_i (0 to C_ECC_WIDTH-1);
                    
          -- Note: For future enhancement.
          --   when C_CE_FailingData_31_0        => RegRdData(0 to C_DWIDTH-1) <= (others => '0');      -- CE_FailingData (0 to 31);
          --   when C_CE_FailingData_63_31       => RegRdData(0 to C_DWIDTH-1) <= (others => '0');
          --   when C_CE_FailingData_95_64       => RegRdData(0 to C_DWIDTH-1) <= (others => '0');        
          --   when C_CE_FailingData_127_96      => RegRdData(0 to C_DWIDTH-1) <= (others => '0');
          --   when C_CE_FailingECC              => RegRdData(CE_FailingECC'range) <= (others => '0');  -- CE_FailingECC; 
          --   when C_UE_FailingAddress_31_0     => RegRdData(0 to C_DWIDTH-1) <= (others => '0');      -- UE_FailingAddress (0 to 31);
          --   when C_UE_FailingAddress_63_32    => RegRdData(0 to C_DWIDTH-1) <= (others => '0');
          --   when C_UE_FailingData_31_0        => RegRdData(0 to C_DWIDTH-1) <= (others => '0');      -- UE_FailingData (0 to 31);                
          --   when C_UE_FailingData_63_31       => RegRdData(0 to C_DWIDTH-1) <= (others => '0');         
          --   when C_UE_FailingData_95_64       => RegRdData(0 to C_DWIDTH-1) <= (others => '0');
          --   when C_UE_FailingData_127_96      => RegRdData(0 to C_DWIDTH-1) <= (others => '0');
          --   when C_UE_FailingECC              => RegRdData(UE_FailingECC'range) <= (others => '0');  -- UE_FailingECC;
          
          when others                       => RegRdData <= (others => '0');
        end case;
      end process SelRegRdData;
    
    end generate GEN_REG_32_DATA;


    ---------------------------------------------------------------------------
    -- Generate:    GEN_REG_64_DATA
    -- Purpose:     Generate read register values & signal assignments based on
    --              64-bit BRAM data width.
    ---------------------------------------------------------------------------

    GEN_REG_64_DATA: if C_S_AXI_DATA_WIDTH = 64 generate
    begin
    
      SelRegRdData : process (RegAddr, ECC_StatusReg, ECC_EnableIRQReg, ECC_OnOffReg, 
                              CE_CounterReg, CE_FailingAddress,
                              FaultInjectData_i,
                              FaultInjectECC_i
                              -- CE_FailingData, CE_FailingECC,
                              -- UE_FailingAddress, UE_FailingData, UE_FailingECC
                              )
      begin
        RegRdData <= (others => '0');

        case RegAddr is
            -- Replace 'range use here for vector (31:0) (AXI BRAM) and (0:31) (LMB BRAM) reassignment        
          when C_ECC_StatusReg              => RegRdData(ECC_StatusReg'range) <= ECC_StatusReg;
          when C_ECC_EnableIRQReg           => RegRdData(ECC_EnableIRQReg'range) <= ECC_EnableIRQReg;
          when C_ECC_OnOffReg               => RegRdData(ECC_OnOffReg'range) <= ECC_OnOffReg;
          when C_CE_CounterReg              => RegRdData(CE_CounterReg'range) <= CE_CounterReg;
          when C_CE_FailingAddress_31_0     => RegRdData(0 to C_DWIDTH-1)   <= CE_FailingAddress (0 to 31);
          when C_CE_FailingAddress_63_32    => RegRdData(0 to C_DWIDTH-1)   <= (others => '0');

          -- Temporary addition to readback fault inject register values
          when C_FaultInjectData_31_0       => RegRdData(0 to C_DWIDTH-1) <= FaultInjectData_i (0 to 31);
          when C_FaultInjectData_63_32      => RegRdData(0 to C_DWIDTH-1) <= FaultInjectData_i (32 to 63);
          when C_FaultInjectECC             => RegRdData(C_DWIDTH-C_ECC_WIDTH to C_DWIDTH-1) <= FaultInjectECC_i (0 to C_ECC_WIDTH-1);

          -- Note: For future enhancement.
          --   when C_CE_FailingData_31_0        => RegRdData(0 to C_DWIDTH-1  )    <= CE_FailingData (32 to 63);
          --   when C_CE_FailingData_63_31       => RegRdData(0 to C_DWIDTH-1  )    <= CE_FailingData (0 to 31);
          --   when C_CE_FailingData_95_64       => RegRdData(0 to C_DWIDTH-1)   <= (others => '0');
          --   when C_CE_FailingData_127_96      => RegRdData(0 to C_DWIDTH-1)   <= (others => '0');
          --   when C_CE_FailingECC              => RegRdData(CE_FailingECC'range)     <= CE_FailingECC;
          --   when C_UE_FailingAddress_31_0     => RegRdData(0 to C_DWIDTH-1)   <= UE_FailingAddress (0 to 31);
          --   when C_UE_FailingAddress_63_32    => RegRdData(0 to C_DWIDTH-1) <= (others => '0');
          --   when C_UE_FailingData_31_0        => RegRdData(0 to C_DWIDTH-1)      <= UE_FailingData (32 to 63);
          --   when C_UE_FailingData_63_31       => RegRdData(0 to C_DWIDTH-1  )    <= UE_FailingData (0 to 31);          
          --   when C_UE_FailingData_95_64       => RegRdData(0 to C_DWIDTH-1) <= (others => '0');
          --   when C_UE_FailingData_127_96      => RegRdData(0 to C_DWIDTH-1) <= (others => '0');
          --   when C_UE_FailingECC              => RegRdData(UE_FailingECC'range)     <= UE_FailingECC;
          
          when others                       => RegRdData <= (others => '0');
        end case;
      end process SelRegRdData;
    
    end generate GEN_REG_64_DATA;


    ---------------------------------------------------------------------------
    -- Generate:    GEN_REG_128_DATA
    -- Purpose:     Generate read register values & signal assignments based on
    --              128-bit BRAM data width.
    ---------------------------------------------------------------------------

    GEN_REG_128_DATA: if C_S_AXI_DATA_WIDTH = 128 generate
    begin
    
      SelRegRdData : process (RegAddr, ECC_StatusReg, ECC_EnableIRQReg, ECC_OnOffReg, 
                              CE_CounterReg, CE_FailingAddress,
                              FaultInjectData_i,
                              FaultInjectECC_i
                              -- CE_FailingData, CE_FailingECC,
                              -- UE_FailingAddress, UE_FailingData, UE_FailingECC
                              )
      begin
        RegRdData <= (others => '0');

        case RegAddr is
            -- Replace 'range use here for vector (31:0) (AXI BRAM) and (0:31) (LMB BRAM) reassignment        
          when C_ECC_StatusReg              => RegRdData(ECC_StatusReg'range) <= ECC_StatusReg;
          when C_ECC_EnableIRQReg           => RegRdData(ECC_EnableIRQReg'range) <= ECC_EnableIRQReg;
          when C_ECC_OnOffReg               => RegRdData(ECC_OnOffReg'range) <= ECC_OnOffReg;
          when C_CE_CounterReg              => RegRdData(CE_CounterReg'range) <= CE_CounterReg;          
          when C_CE_FailingAddress_31_0     => RegRdData(0 to C_DWIDTH-1) <= CE_FailingAddress (0 to 31);
          when C_CE_FailingAddress_63_32    => RegRdData(0 to C_DWIDTH-1) <= (others => '0');
          
          -- Temporary addition to readback fault inject register values
          when C_FaultInjectData_31_0       => RegRdData(0 to C_DWIDTH-1) <= FaultInjectData_i (0 to 31);
          when C_FaultInjectData_63_32      => RegRdData(0 to C_DWIDTH-1) <= FaultInjectData_i (32 to 63);
          when C_FaultInjectData_95_64      => RegRdData(0 to C_DWIDTH-1) <= FaultInjectData_i (64 to 95);
          when C_FaultInjectData_127_96     => RegRdData(0 to C_DWIDTH-1) <= FaultInjectData_i (96 to 127);
          when C_FaultInjectECC             => RegRdData(C_DWIDTH-C_ECC_WIDTH to C_DWIDTH-1) <= FaultInjectECC_i (0 to C_ECC_WIDTH-1);


          -- Note: For future enhancement.
          --   when C_CE_FailingData_31_0        => RegRdData(0 to C_DWIDTH-1  )    <= CE_FailingData (96 to 127);
          --   when C_CE_FailingData_63_31       => RegRdData(0 to C_DWIDTH-1  )    <= CE_FailingData (64 to 95);
          --   when C_CE_FailingData_95_64       => RegRdData(0 to C_DWIDTH-1  )    <= CE_FailingData (32 to 63);         
          --   when C_CE_FailingData_127_96      => RegRdData(0 to C_DWIDTH-1  )    <= CE_FailingData (0 to 31);
          --   when C_CE_FailingECC              => RegRdData(CE_FailingECC'range)     <= CE_FailingECC;          
          --   when C_UE_FailingAddress_31_0     => RegRdData(0 to C_DWIDTH-1) <= UE_FailingAddress (0 to 31);                    
          --   when C_UE_FailingAddress_63_32    => RegRdData(0 to C_DWIDTH-1) <= (others => '0');
          --   when C_UE_FailingData_31_0        => RegRdData(0 to C_DWIDTH-1)      <= UE_FailingData (96 to 127);
          --   when C_UE_FailingData_63_31       => RegRdData(0 to C_DWIDTH-1  )    <= UE_FailingData (64 to 95);
          --   when C_UE_FailingData_95_64       => RegRdData(0 to C_DWIDTH-1  )    <= UE_FailingData (32 to 63);
          --   when C_UE_FailingData_127_96      => RegRdData(0 to C_DWIDTH-1  )    <= UE_FailingData (0 to 31);
          --   when C_UE_FailingECC              => RegRdData(UE_FailingECC'range)     <= UE_FailingECC;
          
          when others                       => RegRdData <= (others => '0');
        end case;
      end process SelRegRdData;

    end generate GEN_REG_128_DATA;


    ---------------------------------------------------------------------------




end architecture implementation;










-------------------------------------------------------------------------------
-- axi_lite.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
-------------------------------------------------------------------------------
-- Filename:        axi_lite.vhd
--
-- Description:     This file is the top level module for the AXI-Lite
--                  instantiation of the BRAM controller interface.  
--
--                  Responsible for shared address pipelining between the
--                  write address (AW) and read address (AR) channels.
--                  Controls (seperately) the data flows for the write data
--                  (W), write response (B), and read data (R) channels.
--
--                  Creates a shared port to BRAM (for all read and write
--                  transactions) or dual BRAM port utilization based on a
--                  generic parameter setting.
--
--
-- VHDL-Standard:   VHDL'93
--
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- correct_one_bit.vhd
--                      |   -- ecc_gen.vhd
--
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/1/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
-- JLJ      2/2/2011         v1.03a
-- ~~~~~~
--  Remove library version # dependency.  Replace with work library.
-- ^^^^^^
-- JLJ      2/22/2011         v1.03a
-- ~~~~~~
--  Update BRAM address mapping to lite_ecc_reg module.  Corrected
--  signal size for XST detected unused bits in vector.
--  Plus minor code cleanup.
--
--  Add top level parameter, C_ECC_TYPE for Hsiao ECC algorithm.
-- ^^^^^^
-- JLJ      2/23/2011         v1.03a
-- ~~~~~~
--  Add Hsiao ECC algorithm logic (similar to full_axi module HDL).
-- ^^^^^^
-- JLJ      2/24/2011         v1.03a
-- ~~~~~~
--  Move REG_RDATA register process out from C_ECC_TYPE generate block 
--  to C_ECC generate block.
-- ^^^^^^
-- JLJ      3/22/2011         v1.03a
-- ~~~~~~
--  Add LUT level with reset signal to combinatorial outputs, AWREADY
--  and WREADY.  This will ensure that the output remains LOW during reset,
--  regardless of AWVALID or WVALID input signals.
-- ^^^^^^
-- JLJ      3/28/2011         v1.03a
-- ~~~~~~
--  Remove combinatorial output paths on AWREADY and WREADY.
--  Combine AWREADY and WREADY registers.
--  Remove combinatorial output path on ARREADY.  Can pre-assert ARREADY
--  (but only for non ECC configurations).
--  Create 3-bit counter for BVALID response, seperate from AW/W channels.
--
--  Delay assertion of WREADY in ECC configurations to minimize register
--  resource utilization.
--  No pre-assertion of ARREADY in ECC configurations (due to write latency
--  with ECC enabled).
--
-- ^^^^^^
-- JLJ      3/30/2011         v1.03a
-- ~~~~~~
--  Update Sl_CE and Sl_UE flag assertions to a single clock cycle.
--  Clean up comments.
-- ^^^^^^
-- JLJ      4/19/2011         v1.03a
-- ~~~~~~
--  Update BVALID assertion when ECC is enabled to match the implementation
--  when C_ECC = 0.  Optimize back to back write performance when C_ECC = 1.
-- ^^^^^^
-- JLJ      4/22/2011         v1.03a
-- ~~~~~~
--  Modify FaultInjectClr signal assertion.  With BVALID counter, delay
--  when fault inject register gets cleared.
-- ^^^^^^
-- JLJ      4/22/2011         v1.03a
-- ~~~~~~
--  Code clean up.
-- ^^^^^^
-- JLJ      5/6/2011      v1.03a
-- ~~~~~~
--  Remove usage of C_FAMILY.  
--  Hard code C_USE_LUT6 constant.
-- ^^^^^^
-- JLJ      7/7/2011      v1.03a
-- ~~~~~~
--  Fix DV regression failure with reset.
--  Hold off BRAM enable output with active reset signal.
-- ^^^^^^
--
--  
-------------------------------------------------------------------------------

-- Library declarations

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.lite_ecc_reg;
use work.parity;
use work.checkbit_handler;
use work.correct_one_bit;
use work.ecc_gen;
use work.axi_bram_ctrl_funcs.all;


------------------------------------------------------------------------------


entity axi_lite is
generic (


    C_S_AXI_PROTOCOL : string := "AXI4LITE";
        -- Set to AXI4LITE to optimize out burst transaction support

    C_S_AXI_ADDR_WIDTH : integer := 32;
      -- Width of AXI address bus (in bits)
    
    C_S_AXI_DATA_WIDTH : integer := 32;
      -- Width of AXI data bus (in bits)

    C_SINGLE_PORT_BRAM : integer := 1;
        -- Enable single port usage of BRAM
      
    --  C_FAMILY : string := "virtex6";
        -- Specify the target architecture type


    -- AXI-Lite Register Parameters
    
    C_S_AXI_CTRL_ADDR_WIDTH : integer := 32;
        -- Width of AXI-Lite address bus (in bits)

    C_S_AXI_CTRL_DATA_WIDTH  : integer := 32;
        -- Width of AXI-Lite data bus (in bits)
        
        
  
    -- ECC Parameters
    
    C_ECC : integer := 0;
        -- Enables or disables ECC functionality
        
    C_ECC_TYPE : integer := 0;          -- v1.03a 
        -- ECC algorithm format, 0 = Hamming code, 1 = Hsiao code

    C_ECC_WIDTH : integer := 8;
        -- Width of ECC data vector
        
    C_FAULT_INJECT : integer := 0;
        -- Enable fault injection registers
        
    C_ECC_ONOFF_RESET_VALUE : integer := 1;
        -- By default, ECC checking is on (can disable ECC @ reset by setting this to 0)


    -- Hard coded parameters at top level.
    -- Note: Kept in design for future enhancement.
    
    C_ENABLE_AXI_CTRL_REG_IF : integer := 0;
        -- By default the ECC AXI-Lite register interface is enabled    
    
    C_CE_FAILING_REGISTERS : integer := 0;
        -- Enable CE (correctable error) failing registers
        
    C_UE_FAILING_REGISTERS : integer := 0;
        -- Enable UE (uncorrectable error) failing registers
        
    C_ECC_STATUS_REGISTERS : integer := 0;
        -- Enable ECC status registers

    C_ECC_ONOFF_REGISTER : integer := 0;
        -- Enable ECC on/off control register

    C_CE_COUNTER_WIDTH : integer := 0
        -- Selects CE counter width/threshold to assert ECC_Interrupt
    
    


    );
  port (


    -- AXI Interface Signals
    
    -- AXI Clock and Reset
    S_AXI_ACLK              : in    std_logic;
    S_AXI_ARESETN           : in    std_logic;      

    ECC_Interrupt           : out   std_logic := '0';
    ECC_UE                  : out   std_logic := '0';

    -- *** AXI Write Address Channel Signals (AW) *** 

    AXI_AWADDR              : in    std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    AXI_AWVALID             : in    std_logic;
    AXI_AWREADY             : out   std_logic;

        -- Unused AW AXI-Lite Signals        
                -- AXI_AWID                : in    std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
                -- AXI_AWLEN               : in    std_logic_vector(7 downto 0);
                -- AXI_AWSIZE              : in    std_logic_vector(2 downto 0);
                -- AXI_AWBURST             : in    std_logic_vector(1 downto 0);
                -- AXI_AWLOCK              : in    std_logic;                          -- Currently unused         
                -- AXI_AWCACHE             : in    std_logic_vector(3 downto 0);       -- Currently unused
                -- AXI_AWPROT              : in    std_logic_vector(2 downto 0);       -- Currently unused


    -- *** AXI Write Data Channel Signals (W) *** 

    AXI_WDATA               : in    std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_WSTRB               : in    std_logic_vector(C_S_AXI_DATA_WIDTH/8-1 downto 0);
    AXI_WVALID              : in    std_logic;
    AXI_WREADY              : out   std_logic;


        -- Unused W AXI-Lite Signals
                -- AXI_WLAST               : in    std_logic;


    -- *** AXI Write Data Response Channel Signals (B) *** 

    AXI_BRESP               : out   std_logic_vector(1 downto 0);
    AXI_BVALID              : out   std_logic;
    AXI_BREADY              : in    std_logic;


        -- Unused B AXI-Lite Signals
                -- AXI_BID                 : out   std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);

 
    -- *** AXI Read Address Channel Signals (AR) *** 

    AXI_ARADDR              : in    std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    AXI_ARVALID             : in    std_logic;
    AXI_ARREADY             : out   std_logic;
    
    
    -- *** AXI Read Data Channel Signals (R) *** 

    AXI_RDATA               : out   std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    AXI_RRESP               : out   std_logic_vector(1 downto 0);
    AXI_RLAST               : out   std_logic;

    AXI_RVALID              : out   std_logic;
    AXI_RREADY              : in    std_logic;
    



    -- *** AXI-Lite ECC Register Interface Signals ***
    
    -- AXI-Lite Clock and Reset
    -- Note: AXI-Lite Control IF and AXI IF share the same clock.
    -- S_AXI_CTRL_AClk         : in    std_logic;
    -- S_AXI_CTRL_AResetn      : in    std_logic;      
    
    
    -- AXI-Lite Write Address Channel Signals (AW)
    AXI_CTRL_AWVALID          : in    std_logic;
    AXI_CTRL_AWREADY          : out   std_logic;
    AXI_CTRL_AWADDR           : in    std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);

    
    -- AXI-Lite Write Data Channel Signals (W)
    AXI_CTRL_WDATA            : in    std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    AXI_CTRL_WVALID           : in    std_logic;
    AXI_CTRL_WREADY           : out   std_logic;
    

    -- AXI-Lite Write Data Response Channel Signals (B)
    AXI_CTRL_BRESP            : out   std_logic_vector(1 downto 0);
    AXI_CTRL_BVALID           : out   std_logic;
    AXI_CTRL_BREADY           : in    std_logic;
    

    -- AXI-Lite Read Address Channel Signals (AR)
    AXI_CTRL_ARADDR           : in    std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);
    AXI_CTRL_ARVALID          : in    std_logic;
    AXI_CTRL_ARREADY          : out   std_logic;


    -- AXI-Lite Read Data Channel Signals (R)
    AXI_CTRL_RDATA             : out   std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    AXI_CTRL_RRESP             : out   std_logic_vector(1 downto 0);
    AXI_CTRL_RVALID            : out   std_logic;
    AXI_CTRL_RREADY            : in    std_logic;

        
        
    
    -- *** BRAM Port A Interface Signals ***
    -- Note: Clock handled at top level (axi_bram_ctrl module)
    
    BRAM_En_A               : out   std_logic;
    BRAM_WE_A               : out   std_logic_vector (C_S_AXI_DATA_WIDTH/8+(C_ECC_WIDTH+7)/8-1 downto 0);
    BRAM_Addr_A             : out   std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0);
    BRAM_WrData_A           : out   std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0);   -- @ port level = 8-bits wide ECC 
    BRAM_RdData_A           : in    std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0);   -- @ port level = 8-bits wide ECC    
       
    -- Note: Remove BRAM_RdData_A port (unused in dual port mode)
    -- Platgen will keep port open on BRAM block
    

    -- *** BRAM Port B Interface Signals ***
    -- Note: Clock handled at top level (axi_bram_ctrl module)

    BRAM_En_B               : out   std_logic;
    BRAM_WE_B               : out   std_logic_vector (C_S_AXI_DATA_WIDTH/8+(C_ECC_WIDTH+7)/8-1 downto 0);
    BRAM_Addr_B             : out   std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0);
    BRAM_WrData_B           : out   std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0);   -- @ port level = 8-bits wide ECC
    BRAM_RdData_B           : in    std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0)    -- @ port level = 8-bits wide ECC


    

    );



end entity axi_lite;


-------------------------------------------------------------------------------

architecture implementation of axi_lite is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";

-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------

-- All functions defined in axi_bram_ctrl_funcs package.


-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------


constant C_RESET_ACTIVE     : std_logic := '0';


constant RESP_OKAY      : std_logic_vector (1 downto 0) := "00";    -- Normal access OK response
constant RESP_SLVERR    : std_logic_vector (1 downto 0) := "10";    -- Slave error

-- For future implementation.
-- constant RESP_EXOKAY    : std_logic_vector (1 downto 0) := "01";    -- Exclusive access OK response
-- constant RESP_DECERR    : std_logic_vector (1 downto 0) := "11";    -- Decode error


-- Modify C_BRAM_ADDR_SIZE to be adjusted for BRAM data width
-- When BRAM data width = 32 bits, BRAM_Addr (1:0) = "00"
-- When BRAM data width = 64 bits, BRAM_Addr (2:0) = "000"
-- When BRAM data width = 128 bits, BRAM_Addr (3:0) = "0000"
-- When BRAM data width = 256 bits, BRAM_Addr (4:0) = "00000"
constant C_BRAM_ADDR_ADJUST_FACTOR      : integer := log2 (C_S_AXI_DATA_WIDTH/8);
constant C_BRAM_ADDR_ADJUST     : integer := C_S_AXI_ADDR_WIDTH - C_BRAM_ADDR_ADJUST_FACTOR;

constant C_AXI_DATA_WIDTH_BYTES     : integer := C_S_AXI_DATA_WIDTH/8;

-- Internal data width based on C_S_AXI_DATA_WIDTH.
constant C_INT_ECC_WIDTH : integer := Int_ECC_Size (C_S_AXI_DATA_WIDTH);

-- constant C_USE_LUT6 : boolean := Family_To_LUT_Size (String_To_Family (C_FAMILY,false)) = 6;
-- Remove usage of C_FAMILY.
-- All architectures supporting AXI will support a LUT6. 
-- Hard code this internal constant used in ECC algorithm.
-- constant C_USE_LUT6 : boolean := Family_To_LUT_Size (String_To_Family (C_FAMILY,false)) = 6;
constant C_USE_LUT6 : boolean := TRUE;


-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------


signal axi_aresetn_d1           : std_logic := '0';
signal axi_aresetn_re           : std_logic := '0';


-------------------------------------------------------------------------------
-- AXI Write & Read Address Channel Signals
-------------------------------------------------------------------------------


-- State machine type declarations
type LITE_SM_TYPE is ( IDLE,
                       SNG_WR_DATA,
                       RD_DATA,
                       RMW_RD_DATA,
                       RMW_MOD_DATA,
                       RMW_WR_DATA
                    );
                    
signal lite_sm_cs, lite_sm_ns : LITE_SM_TYPE;


signal axi_arready_cmb      : std_logic := '0';
signal axi_arready_reg      : std_logic := '0';
signal axi_arready_int      : std_logic := '0';


-------------------------------------------------------------------------------
-- AXI Write Data Channel Signals
-------------------------------------------------------------------------------
signal axi_wready_cmb       : std_logic := '0';
signal axi_wready_int       : std_logic := '0';


-------------------------------------------------------------------------------
-- AXI Write Response Channel Signals
-------------------------------------------------------------------------------
signal axi_bresp_int        : std_logic_vector (1 downto 0) := (others => '0');
signal axi_bvalid_int       : std_logic := '0';

signal bvalid_cnt_inc       : std_logic := '0';
signal bvalid_cnt_inc_d1    : std_logic := '0';
signal bvalid_cnt_dec       : std_logic := '0';
signal bvalid_cnt           : std_logic_vector (2 downto 0) := (others => '0');


-------------------------------------------------------------------------------
-- AXI Read Data Channel Signals
-------------------------------------------------------------------------------
signal axi_rresp_int            : std_logic_vector (1 downto 0) := (others => '0');
signal axi_rvalid_set           : std_logic := '0';
signal axi_rvalid_set_r         : std_logic := '0';
signal axi_rvalid_int           : std_logic := '0';
signal axi_rlast_set            : std_logic := '0';
signal axi_rlast_set_r          : std_logic := '0';
signal axi_rlast_int            : std_logic := '0';    
signal axi_rdata_int            : std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
signal axi_rdata_int_corr       : std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); 


-------------------------------------------------------------------------------
-- Internal BRAM Signals
-------------------------------------------------------------------------------
signal bram_we_a_int      : std_logic_vector (C_S_AXI_DATA_WIDTH/8+(C_ECC_WIDTH+7)/8-1 downto 0) := (others => '0');
signal bram_en_a_cmb      : std_logic := '0';
signal bram_en_b_cmb      : std_logic := '0';
signal bram_en_a_int      : std_logic := '0';
signal bram_en_b_int      : std_logic := '0';

signal bram_addr_a_int    : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)
                                := (others => '0');

signal bram_addr_a_int_q  : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)
                                := (others => '0');                                

signal bram_addr_b_int    : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)
                                := (others => '0');

signal BRAM_Addr_A_i    : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
signal BRAM_Addr_B_i    : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
signal bram_wrdata_a_int  : std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0) := (others => '0');    -- Port level signal, 8-bits ECC




-------------------------------------------------------------------------------
-- Internal ECC Signals
-------------------------------------------------------------------------------

signal FaultInjectClr           : std_logic := '0';      -- Clear for Fault Inject Registers      
signal CE_Failing_We            : std_logic := '0';      -- WE for CE Failing Registers        
signal UE_Failing_We            : std_logic := '0';      -- WE for CE Failing Registers
signal CE_CounterReg_Inc        : std_logic := '0';      -- Increment CE Counter Register 
signal Sl_CE                    : std_logic := '0';      -- Correctable Error Flag
signal Sl_UE                    : std_logic := '0';      -- Uncorrectable Error Flag
signal Sl_CE_i                  : std_logic := '0';
signal Sl_UE_i                  : std_logic := '0';

signal FaultInjectData          : std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
signal FaultInjectECC           : std_logic_vector (C_INT_ECC_WIDTH-1 downto 0) := (others => '0');     -- Specific to BRAM data width

signal CorrectedRdData          : std_logic_vector (0 to C_S_AXI_DATA_WIDTH-1) := (others => '0');
signal UnCorrectedRdData        : std_logic_vector (0 to C_S_AXI_DATA_WIDTH-1) := (others => '0');
signal CE_Q                     : std_logic := '0';
signal UE_Q                     : std_logic := '0';
signal Enable_ECC               : std_logic := '0';

signal RdModifyWr_Read          : std_logic := '0';  -- Read cycle in read modify write sequence 
signal RdModifyWr_Check         : std_logic := '0';  -- Read cycle in read modify write sequence 
signal RdModifyWr_Modify        : std_logic := '0';  -- Modify cycle in read modify write sequence 
signal RdModifyWr_Write         : std_logic := '0';  -- Write cycle in read modify write sequence 

signal WrData                   : std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
signal WrData_cmb               : std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
signal Active_Wr                : std_logic := '0';
signal BRAM_Addr_En             : std_logic := '0';

signal Syndrome                 : std_logic_vector(0 to C_INT_ECC_WIDTH-1);     -- Specific to BRAM data width
signal Syndrome_4               : std_logic_vector (0 to 1) := (others => '0');         -- Specific to 32-bit ECC
signal Syndrome_6               : std_logic_vector (0 to 5) := (others => '0');         -- Specific to 32-bit ECC

signal syndrome_reg             : std_logic_vector(0 to C_INT_ECC_WIDTH-1);     -- Specific to BRAM data width
signal syndrome_4_reg           : std_logic_vector (0 to 1) := (others => '0');            -- Specific for 32-bit ECC
signal syndrome_6_reg           : std_logic_vector (0 to 5)  := (others => '0');            -- Specific for 32-bit ECC
signal syndrome_reg_i           : std_logic_vector(0 to C_INT_ECC_WIDTH-1) := (others => '0');     -- Specific to BRAM data width


-------------------------------------------------------------------------------
-- Architecture Body
-------------------------------------------------------------------------------


begin 




    ---------------------------------------------------------------------------
    -- *** AXI-Lite ECC Register Output Signals ***
    ---------------------------------------------------------------------------



    ---------------------------------------------------------------------------
    -- Generate:    GEN_NO_REGS
    -- Purpose:     Generate default values if ECC registers are disabled (or when
    --              ECC is disabled).
    --              Include both AXI-Lite default signal values & internal
    --              core signal values.
    ---------------------------------------------------------------------------
        -- For future implementation.
        -- GEN_NO_REGS: if (C_ECC = 1 and C_ENABLE_AXI_CTRL_REG_IF = 0) or (C_ECC = 0) generate
        
    GEN_NO_REGS: if (C_ECC = 0) generate
    begin
    
        AXI_CTRL_AWREADY <= '0';
        AXI_CTRL_WREADY <= '0';
        AXI_CTRL_BRESP <= (others => '0');
        AXI_CTRL_BVALID <= '0';
        AXI_CTRL_ARREADY <= '0';
        AXI_CTRL_RDATA <= (others => '0');
        AXI_CTRL_RRESP <= (others => '0');
        AXI_CTRL_RVALID <= '0';
                
        -- No fault injection
        FaultInjectData <= (others => '0');
        FaultInjectECC <= (others => '0');
                
        -- Interrupt only enabled when ECC status/interrupt registers enabled
        ECC_Interrupt <= '0';
        ECC_UE <= '0';
        
        BRAM_Addr_En <= '0';
        
        -----------------------------------------------------------------------
        -- Generate:    GEN_DIS_ECC
        -- Purpose:     Disable ECC in read path when ECC is disabled in core.
        -----------------------------------------------------------------------
        GEN_DIS_ECC: if C_ECC = 0 generate
            Enable_ECC <= '0';
        end generate GEN_DIS_ECC;
        
        
        -- For future implementation.
        --
        --       -----------------------------------------------------------------------
        --       -- Generate:    GEN_EN_ECC
        --       -- Purpose:     Enable ECC when C_ECC = 1 and no ECC registers are available.
        --       --              ECC on/off control register is not accessible (so ECC is always
        --       --              enabled in this configuraiton).
        --       -----------------------------------------------------------------------
        --       GEN_EN_ECC: if (C_ECC = 1 and C_ENABLE_AXI_CTRL_REG_IF = 0) generate
        --           Enable_ECC <= '1';  -- ECC ON/OFF register can not be enabled (as no ECC
        --                               -- ECC registers are available.  Therefore, ECC 
        --                               -- is always enabled.
        --       end generate GEN_EN_ECC;



    end generate GEN_NO_REGS;
        
        


    ---------------------------------------------------------------------------
    -- Generate:    GEN_REGS
    -- Purpose:     Generate ECC register module when ECC is enabled and
    --              ECC registers are enabled.
    ---------------------------------------------------------------------------

    -- For future implementation.
    -- GEN_REGS: if (C_ECC = 1 and C_ENABLE_AXI_CTRL_REG_IF = 1) generate

    GEN_REGS: if (C_ECC = 1) generate
    begin

        ---------------------------------------------------------------------------
        -- Instance:        I_LITE_ECC_REG
        -- Description:     This module is for the AXI-Lite ECC registers. 
        --
        --              Responsible for all AXI-Lite communication to the 
        --              ECC register bank.  Provides user interface signals
        --              to rest of AXI BRAM controller IP core for ECC functionality
        --              and control.
        --              Manages AXI-Lite write address (AW) and read address (AR),
        --              write data (W), write response (B), and read data (R) channels.
        ---------------------------------------------------------------------------
        
        I_LITE_ECC_REG : entity work.lite_ecc_reg
        generic map (
        
            C_S_AXI_PROTOCOL                =>  C_S_AXI_PROTOCOL                ,
            C_S_AXI_DATA_WIDTH              =>  C_S_AXI_DATA_WIDTH              ,
            C_S_AXI_ADDR_WIDTH              =>  C_S_AXI_ADDR_WIDTH              ,             
            C_SINGLE_PORT_BRAM              =>  C_SINGLE_PORT_BRAM              ,                  
        
            C_S_AXI_CTRL_ADDR_WIDTH         =>  C_S_AXI_CTRL_ADDR_WIDTH         ,
            C_S_AXI_CTRL_DATA_WIDTH         =>  C_S_AXI_CTRL_DATA_WIDTH         ,    
            
            C_ECC_WIDTH                     =>  C_INT_ECC_WIDTH                 ,       -- ECC width specific to data width
                
            C_FAULT_INJECT                  =>  C_FAULT_INJECT                  ,
            C_CE_FAILING_REGISTERS          =>  C_CE_FAILING_REGISTERS          ,
            C_UE_FAILING_REGISTERS          =>  C_UE_FAILING_REGISTERS          ,
            C_ECC_STATUS_REGISTERS          =>  C_ECC_STATUS_REGISTERS          ,
            C_ECC_ONOFF_REGISTER            =>  C_ECC_ONOFF_REGISTER            ,
            C_ECC_ONOFF_RESET_VALUE         =>  C_ECC_ONOFF_RESET_VALUE         ,
            C_CE_COUNTER_WIDTH              =>  C_CE_COUNTER_WIDTH                      
        )
        port map (
        
            S_AXI_AClk              =>  S_AXI_AClk          ,       -- AXI clock 
            S_AXI_AResetn           =>  S_AXI_AResetn       ,  

            -- Note: AXI-Lite Control IF and AXI IF share the same clock.
            -- S_AXI_CTRL_AClk         =>  S_AXI_CTRL_AClk     ,       -- AXI-Lite clock
            -- S_AXI_CTRL_AResetn      =>  S_AXI_CTRL_AResetn  ,  

            Interrupt               =>  ECC_Interrupt       ,
            ECC_UE                  =>  ECC_UE              ,

            AXI_CTRL_AWVALID        =>  AXI_CTRL_AWVALID    ,  
            AXI_CTRL_AWREADY        =>  AXI_CTRL_AWREADY    ,  
            AXI_CTRL_AWADDR         =>  AXI_CTRL_AWADDR     ,  

            AXI_CTRL_WDATA          =>  AXI_CTRL_WDATA      ,  
            AXI_CTRL_WVALID         =>  AXI_CTRL_WVALID     ,  
            AXI_CTRL_WREADY         =>  AXI_CTRL_WREADY     ,  

            AXI_CTRL_BRESP          =>  AXI_CTRL_BRESP      ,  
            AXI_CTRL_BVALID         =>  AXI_CTRL_BVALID     ,  
            AXI_CTRL_BREADY         =>  AXI_CTRL_BREADY     ,  

            AXI_CTRL_ARADDR         =>  AXI_CTRL_ARADDR     ,  
            AXI_CTRL_ARVALID        =>  AXI_CTRL_ARVALID    ,  
            AXI_CTRL_ARREADY        =>  AXI_CTRL_ARREADY    ,  

            AXI_CTRL_RDATA          =>  AXI_CTRL_RDATA      ,  
            AXI_CTRL_RRESP          =>  AXI_CTRL_RRESP      ,  
            AXI_CTRL_RVALID         =>  AXI_CTRL_RVALID     ,  
            AXI_CTRL_RREADY         =>  AXI_CTRL_RREADY     ,  


            Enable_ECC              =>  Enable_ECC          ,
            FaultInjectClr          =>  FaultInjectClr      ,    
            CE_Failing_We           =>  CE_Failing_We       ,
            CE_CounterReg_Inc       =>  CE_Failing_We       ,
            Sl_CE                   =>  Sl_CE               ,
            Sl_UE                   =>  Sl_UE               ,

            BRAM_Addr_A             =>  BRAM_Addr_A_i (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)   ,       -- v1.03a
            BRAM_Addr_B             =>  BRAM_Addr_B_i (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)   ,       -- v1.03a

            BRAM_Addr_En            =>  BRAM_Addr_En        ,
            Active_Wr               =>  Active_Wr           ,

            FaultInjectData         =>  FaultInjectData     ,
            FaultInjectECC          =>  FaultInjectECC      
            
            );


        FaultInjectClr <= '1' when (bvalid_cnt_inc_d1 = '1') else '0';
        CE_Failing_We <= '1' when Enable_ECC = '1' and CE_Q = '1' else '0';        
        Active_Wr <= '1' when (RdModifyWr_Read = '1' or RdModifyWr_Check = '1' or RdModifyWr_Modify = '1' or RdModifyWr_Write = '1') else '0';
        
        -----------------------------------------------------------------------

        -- Add register delay on BVALID counter increment
        -- Used to clear fault inject register.
        
        REG_BVALID_CNT: process (S_AXI_AClk)
        begin
        
            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    bvalid_cnt_inc_d1 <= '0';
                else
                    bvalid_cnt_inc_d1 <= bvalid_cnt_inc;
                end if;
            end if;
        
        end process REG_BVALID_CNT;

        -----------------------------------------------------------------------
        
        
    end generate GEN_REGS;
        



    ---------------------------------------------------------------------------
    -- *** AXI Output Signals ***
    ---------------------------------------------------------------------------


    -- AXI Write Address Channel Output Signals
    -- AXI_AWREADY <= axi_awready_cmb;   
    -- AXI_AWREADY <= '0' when (S_AXI_AResetn = '0') else axi_awready_cmb;          -- v1.03a
    AXI_AWREADY <= axi_wready_int;                                                  -- v1.03a

    --  AXI Write Data Channel Output Signals 
    -- AXI_WREADY <= axi_wready_cmb; 
    -- AXI_WREADY <= '0' when (S_AXI_AResetn = '0') else axi_wready_cmb;            -- v1.03a
    AXI_WREADY <= axi_wready_int;                                                   -- v1.03a


    --  AXI Write Response Channel Output Signals 
    AXI_BRESP <= axi_bresp_int;
    AXI_BVALID <= axi_bvalid_int;

    --  AXI Read Address Channel Output Signals 
    -- AXI_ARREADY <= axi_arready_cmb;                                              -- v1.03a
    AXI_ARREADY <= axi_arready_int;                                                 -- v1.03a  

    --  AXI Read Data Channel Output Signals 
    --  AXI_RRESP <= axi_rresp_int;
    AXI_RRESP <= RESP_SLVERR when (C_ECC = 1 and Sl_UE_i = '1') else axi_rresp_int;


    -- AXI_RDATA <= axi_rdata_int;
    -- Move assignment of RDATA to generate statements based on C_ECC.
    
    AXI_RVALID <= axi_rvalid_int;
    AXI_RLAST <= axi_rlast_int;




    ----------------------------------------------------------------------------

    -- Need to detect end of reset cycle to assert AWREADY on AXI bus
    REG_ARESETN: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1') then
            axi_aresetn_d1 <= S_AXI_AResetn;
        end if;

    end process REG_ARESETN;


    -- Create combinatorial RE detect of S_AXI_AResetn
    axi_aresetn_re <= '1' when (S_AXI_AResetn = '1' and axi_aresetn_d1 = '0') else '0';

    ----------------------------------------------------------------------------




    ---------------------------------------------------------------------------
    -- *** AXI Write Address Channel Interface ***
    ---------------------------------------------------------------------------


    -- Notes:
    -- No address pipelining for AXI-Lite.
    -- PDR feedback.
    -- Remove address register stage to BRAM.
    -- Rely on registers in AXI Interconnect.



    ---------------------------------------------------------------------------
    -- Generate:    GEN_ADDR
    -- Purpose:     Generate all valid bits in the address(es) to BRAM.
    --              If dual port, generate Port B address signal.
    ---------------------------------------------------------------------------
    
    GEN_ADDR: for i in C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR generate
    begin

        ---------------------------------------------------------------------------
        -- Generate:    GEN_ADDR_SNG_PORT
        -- Purpose:     Generate BRAM address when a single port to BRAM.
        --              Mux read and write addresses from AXI AW and AR channels.
        ---------------------------------------------------------------------------
        
        GEN_ADDR_SNG_PORT: if (C_SINGLE_PORT_BRAM = 1) generate
        begin
        
            -- Read takes priority over AWADDR
            -- bram_addr_a_int (i) <= AXI_ARADDR (i) when (AXI_ARVALID = '1') else AXI_AWADDR (i);

            -- ISE should optimize away this mux when connected to the AXI Interconnect
            -- as the AXI Interconnect duplicates the write or read address on both channels.

            -- v1.03a
            -- ARVALID may get asserted while handling ECC read-modify-write.
            -- With the delay in assertion of AWREADY/WREADY, must add some logic to the 
            -- control  on this mux select.
            bram_addr_a_int (i) <= AXI_ARADDR (i) when ((AXI_ARVALID = '1' and 
                                                        (lite_sm_cs = IDLE or lite_sm_cs = SNG_WR_DATA)) or
                                                       (lite_sm_cs = RD_DATA))
                                   else AXI_AWADDR (i);


        end generate GEN_ADDR_SNG_PORT;



        ---------------------------------------------------------------------------
        -- Generate:    GEN_ADDR_DUAL_PORT
        -- Purpose:     Generate BRAM address when a single port to BRAM.
        --              Mux read and write addresses from AXI AW and AR channels.
        ---------------------------------------------------------------------------
        
        GEN_ADDR_DUAL_PORT: if (C_SINGLE_PORT_BRAM = 0) generate
        begin
            bram_addr_a_int (i) <= AXI_AWADDR (i);
            bram_addr_b_int (i) <= AXI_ARADDR (i);

        end generate GEN_ADDR_DUAL_PORT;

    end generate GEN_ADDR;





    ---------------------------------------------------------------------------
    -- *** AXI Read Address Channel Interface ***
    ---------------------------------------------------------------------------


    ---------------------------------------------------------------------------
    -- Generate:    GEN_ARREADY
    -- Purpose:     Only pre-assert ARREADY for non ECC designs.
    --              With ECC, a write requires a read-modify-write and
    --              will miss the address associated with the ARVALID 
    --              (due to the # of clock cycles).
    ---------------------------------------------------------------------------
    
    GEN_ARREADY: if (C_ECC = 0) generate
    begin

        REG_ARREADY: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                -- ARREADY is asserted until we detect the ARVALID.
                -- Check for back-to-back ARREADY assertions (add axi_arready_int).
                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   (AXI_ARVALID = '1' and axi_arready_int = '1') then
                    axi_arready_int <= '0';

                -- Then ARREADY is asserted again when the read operation completes.
                elsif (axi_aresetn_re = '1') or 
                      (axi_rlast_int = '1' and AXI_RREADY = '1') then
                    axi_arready_int <= '1';
                else
                    axi_arready_int <= axi_arready_int;
                end if;
            end if;

        end process REG_ARREADY;

    end generate GEN_ARREADY;
    
    
    ---------------------------------------------------------------------------
    -- Generate:    GEN_ARREADY_ECC
    -- Purpose:     Generate ARREADY from SM logic.  ARREADY is not pre-asserted
    --              as in the non ECC configuration.
    ---------------------------------------------------------------------------

    GEN_ARREADY_ECC: if (C_ECC = 1) generate
    begin
        axi_arready_int <= axi_arready_reg;        
    end generate GEN_ARREADY_ECC;




    ---------------------------------------------------------------------------
    -- *** AXI Write Data Channel Interface ***
    ---------------------------------------------------------------------------

    -- No AXI_WLAST
    


    ---------------------------------------------------------------------------
    -- Generate:    GEN_WRDATA
    -- Purpose:     Generate BRAM port A write data.  For AXI-Lite, pass
    --              through from AXI bus.  If ECC is enabled, merge with fault
    --              inject vector.
    --              Write data bits are in lower order bit lanes.
    --              (31:0) or (63:0)
    ---------------------------------------------------------------------------

    GEN_WRDATA: for i in C_S_AXI_DATA_WIDTH-1 downto 0 generate
    begin

        ---------------------------------------------------------------------------
        -- Generate:    GEN_NO_ECC
        -- Purpose:     Generate output write data when ECC is disabled.
        --              Remove write data path register to BRAM
        ---------------------------------------------------------------------------
        
        GEN_NO_ECC : if C_ECC = 0 generate
        begin
            bram_wrdata_a_int (i) <= AXI_WDATA (i);
        end generate GEN_NO_ECC;
        
        
        ---------------------------------------------------------------------------
        -- Generate:    GEN_W_ECC
        -- Purpose:     Generate output write data when ECC is enable 
        --              (use fault vector).
        --              (N:0)
        ---------------------------------------------------------------------------

        GEN_W_ECC : if C_ECC = 1 generate
        begin
           bram_wrdata_a_int (i)  <= WrData (i) xor FaultInjectData (i);
        end generate GEN_W_ECC;



    end generate GEN_WRDATA;

  




    ---------------------------------------------------------------------------
    -- *** AXI Write Response Channel Interface ***
    ---------------------------------------------------------------------------


    -- No BID support (wrap around in Interconnect)

    -- In AXI-Lite, no WLAST assertion

    -- Drive constant value out on BRESP    
    -- axi_bresp_int <= RESP_OKAY;
    
    axi_bresp_int <= RESP_SLVERR when (C_ECC = 1 and UE_Q = '1') else RESP_OKAY;
        
    
    ---------------------------------------------------------------------------
    
    -- Implement BVALID with counter regardless of IP configuration.
    --
    -- BVALID counter to track the # of required BVALID/BREADY handshakes
    -- needed to occur on the AXI interface.  Based on early and seperate
    -- AWVALID/AWREADY and WVALID/WREADY handshake exchanges.

    REG_BVALID_CNT: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                bvalid_cnt <= (others => '0');

            -- Ensure we only increment counter wyhen BREADY is not asserted
            elsif (bvalid_cnt_inc = '1') and (bvalid_cnt_dec = '0') then
                bvalid_cnt <= std_logic_vector (unsigned (bvalid_cnt (2 downto 0)) + 1);
        
            -- Ensure that we only decrement when SM is not incrementing
            elsif (bvalid_cnt_dec = '1') and (bvalid_cnt_inc = '0') then
                bvalid_cnt <= std_logic_vector (unsigned (bvalid_cnt (2 downto 0)) - 1);

            else
                bvalid_cnt <= bvalid_cnt;
            end if;

        end if;

    end process REG_BVALID_CNT;
    
    
    bvalid_cnt_dec <= '1' when (AXI_BREADY = '1' and axi_bvalid_int = '1' and bvalid_cnt /= "000") else '0';


    -- Replace BVALID output register
    -- Assert BVALID as long as BVALID counter /= zero

    REG_BVALID: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) or 
               (bvalid_cnt = "001" and bvalid_cnt_dec = '1') then
                axi_bvalid_int <= '0';

            elsif (bvalid_cnt /= "000") then
                axi_bvalid_int <= '1';
            else
                axi_bvalid_int <= '0';
            end if;

        end if;

    end process REG_BVALID;




    ---------------------------------------------------------------------------
    -- *** AXI Read Data Channel Interface ***
    ---------------------------------------------------------------------------
    
        
    -- For reductions on AXI-Lite, drive constant value on RESP
    axi_rresp_int <= RESP_OKAY;



    ---------------------------------------------------------------------------
    -- Generate:    GEN_R
    -- Purpose:     Generate AXI R channel outputs when ECC is disabled.
    --              No register delay on AXI_RVALID and AXI_RLAST.
    ---------------------------------------------------------------------------
    GEN_R: if C_ECC = 0 generate
    begin

        ---------------------------------------------------------------------------
        -- AXI_RVALID Output Register
        --
        -- Set AXI_RVALID when read data SM indicates.
        -- Clear when AXI_RLAST is asserted on AXI bus during handshaking sequence
        -- and recognized by AXI requesting master.
        ---------------------------------------------------------------------------
        REG_RVALID: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   (axi_rlast_int = '1' and AXI_RREADY = '1') then 
                    -- Code coverage is hitting this condition and axi_rvalid_int is ALWAYS = '1'
                    -- May be able to remove from this if clause (and simplify logic)
                    axi_rvalid_int <= '0';

                elsif (axi_rvalid_set = '1') then
                    axi_rvalid_int <= '1';
                else
                    axi_rvalid_int <= axi_rvalid_int;
                end if;
            end if;
            
        end process REG_RVALID;


        ---------------------------------------------------------------------------
        -- AXI_RLAST Output Register
        --
        -- Set AXI_RLAST when read data SM indicates.
        -- Clear when AXI_RLAST is asserted on AXI bus during handshaking sequence
        -- and recognized by AXI requesting master.
        ---------------------------------------------------------------------------
        REG_RLAST: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   (axi_rlast_int = '1' and AXI_RREADY = '1') then
                    -- Code coverage is hitting this condition and axi_rvalid_int is ALWAYS = '1'
                    -- May be able to remove from this if clause (and simplify logic)
                    axi_rlast_int <= '0';

                elsif (axi_rlast_set = '1') then
                    axi_rlast_int <= '1';
                else
                    axi_rlast_int <= axi_rlast_int;
                end if;
            end if;
            
        end process REG_RLAST;

    end generate GEN_R;



    ---------------------------------------------------------------------------
    -- Generate:    GEN_R_ECC
    -- Purpose:     Generate AXI R channel outputs when ECC is enabled.
    --              Must use registered delayed control signals for RLAST
    --              and RVALID to align with register inclusion for corrected
    --              read data in ECC logic.
    ---------------------------------------------------------------------------
    GEN_R_ECC: if C_ECC = 1 generate
    begin

        ---------------------------------------------------------------------------
        -- AXI_RVALID Output Register
        --
        -- Set AXI_RVALID when read data SM indicates.
        -- Clear when AXI_RLAST is asserted on AXI bus during handshaking sequence
        -- and recognized by AXI requesting master.
        ---------------------------------------------------------------------------
        REG_RVALID: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   (axi_rlast_int = '1' and AXI_RREADY = '1') then 
                    -- Code coverage is hitting this condition and axi_rvalid_int is ALWAYS = '1'
                    -- May be able to remove from this if clause (and simplify logic)
                    axi_rvalid_int <= '0';

                elsif (axi_rvalid_set_r = '1') then
                    axi_rvalid_int <= '1';
                else
                    axi_rvalid_int <= axi_rvalid_int;
                end if;
            end if;
            
        end process REG_RVALID;


        ---------------------------------------------------------------------------
        -- AXI_RLAST Output Register
        --
        -- Set AXI_RLAST when read data SM indicates.
        -- Clear when AXI_RLAST is asserted on AXI bus during handshaking sequence
        -- and recognized by AXI requesting master.
        ---------------------------------------------------------------------------
        REG_RLAST: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   (axi_rlast_int = '1' and AXI_RREADY = '1') then
                    -- Code coverage is hitting this condition and axi_rvalid_int is ALWAYS = '1'
                    -- May be able to remove from this if clause (and simplify logic)
                    axi_rlast_int <= '0';

                elsif (axi_rlast_set_r = '1') then
                    axi_rlast_int <= '1';
                else
                    axi_rlast_int <= axi_rlast_int;
                end if;
            end if;
            
        end process REG_RLAST;


    end generate GEN_R_ECC;





    ---------------------------------------------------------------------------
    --
    -- Generate AXI bus read data.  No register.  Pass through
    -- read data from BRAM.  Determine source on single port
    -- vs. dual port configuration.
    --
    ---------------------------------------------------------------------------


    -----------------------------------------------------------------------
    -- Generate: RDATA_NO_ECC
    -- Purpose:  Define port A/B from BRAM on AXI_RDATA when ECC disabled.
    -----------------------------------------------------------------------

    RDATA_NO_ECC: if (C_ECC = 0) generate
    begin

        AXI_RDATA <= axi_rdata_int;

        -----------------------------------------------------------------------
        -- Generate:    GEN_RDATA_SNG_PORT
        -- Purpose:     Source of read data: Port A in single port configuration.
        -----------------------------------------------------------------------

        GEN_RDATA_SNG_PORT: if (C_SINGLE_PORT_BRAM = 1) generate
        begin
            axi_rdata_int (C_S_AXI_DATA_WIDTH-1 downto 0) <= BRAM_RdData_A(C_S_AXI_DATA_WIDTH-1 downto 0);
        end generate GEN_RDATA_SNG_PORT;


        -----------------------------------------------------------------------
        -- Generate:    GEN_RDATA_DUAL_PORT
        -- Purpose:     Source of read data: Port B in dual port configuration.
        -----------------------------------------------------------------------

        GEN_RDATA_DUAL_PORT: if (C_SINGLE_PORT_BRAM = 0) generate
        begin
            axi_rdata_int (C_S_AXI_DATA_WIDTH-1 downto 0) <= BRAM_RdData_B (C_S_AXI_DATA_WIDTH-1 downto 0);
        end generate GEN_RDATA_DUAL_PORT;


    end generate RDATA_NO_ECC;
    

    -----------------------------------------------------------------------
    -- Generate: RDATA_W_ECC
    -- Purpose:  Connect AXI_RDATA from ECC module when ECC enabled.
    -----------------------------------------------------------------------

    RDATA_W_ECC: if (C_ECC = 1) generate

    subtype syndrome_bits is std_logic_vector (0 to 6);
    type correct_data_table_type is array (natural range 0 to 31) of syndrome_bits;
    constant correct_data_table : correct_data_table_type := (
      0 => "1100001",  1 => "1010001",  2 => "0110001",  3 => "1110001",
      4 => "1001001",  5 => "0101001",  6 => "1101001",  7 => "0011001",
      8 => "1011001",  9 => "0111001",  10 => "1111001",  11 => "1000101",
      12 => "0100101",  13 => "1100101",  14 => "0010101",  15 => "1010101",
      16 => "0110101",  17 => "1110101",  18 => "0001101",  19 => "1001101",
      20 => "0101101",  21 => "1101101",  22 => "0011101",  23 => "1011101",
      24 => "0111101",  25 => "1111101",  26 => "1000011",  27 => "0100011",
      28 => "1100011",  29 => "0010011",  30 => "1010011",  31 => "0110011"
      );

    begin

        -- Logic common to either type of ECC encoding/decoding    

        -- Renove bit reversal on AXI_RDATA output.
        AXI_RDATA <= axi_rdata_int when (Enable_ECC = '0' or Sl_UE_i = '1') else axi_rdata_int_corr;

        CorrectedRdData (0 to C_S_AXI_DATA_WIDTH-1) <= axi_rdata_int_corr (C_S_AXI_DATA_WIDTH-1 downto 0);


        -- Remove GEN_RDATA that was doing bit reversal.
        -- Read back data is registered prior to any single bit error correction.
        REG_RDATA: process (S_AXI_AClk)
        begin
            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    axi_rdata_int <= (others => '0');
                else               
                    axi_rdata_int (C_S_AXI_DATA_WIDTH-1 downto 0) <= UnCorrectedRdData (0 to C_S_AXI_DATA_WIDTH-1);
                end if;
            end if;
        end process REG_RDATA;

   
    
        ---------------------------------------------------------------------------
        -- Generate: RDATA_W_HAMMING
        -- Purpose:  Add generate statement for Hamming Code ECC algorithm 
        --           specific logic.
        ---------------------------------------------------------------------------
        
        RDATA_W_HAMMING: if C_ECC_TYPE = 0 generate
        begin
        
            -- Move correct_one_bit logic to output side of AXI_RDATA output register.
            -- Improves timing by balancing logic on both sides of pipeline stage.
            -- Utilizing registers in AXI interconnect makes this feasible.

            ---------------------------------------------------------------------------

            -- Register ECC syndrome value to correct any single bit errors
            -- post-register on AXI read data.

            REG_SYNDROME: process (S_AXI_AClk)
            begin        
                if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then            
                    syndrome_reg <= Syndrome;                    
                    syndrome_4_reg <= Syndrome_4;
                    syndrome_6_reg <= Syndrome_6;                  
                end if;
            end process REG_SYNDROME;


            ---------------------------------------------------------------------------

            -- Do last XOR on select syndrome bits outside of checkbit_handler (to match rd_chnl 
            -- w/ balanced pipeline stage) before correct_one_bit module.
            syndrome_reg_i (0 to 3) <= syndrome_reg (0 to 3);

            PARITY_CHK4: entity work.parity
            generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 2)
            port map (
              InA   =>  syndrome_4_reg (0 to 1),                        -- [in  std_logic_vector(0 to C_SIZE - 1)]
              Res   =>  syndrome_reg_i (4) );                           -- [out std_logic]

            syndrome_reg_i (5) <= syndrome_reg (5);

            PARITY_CHK6: entity work.parity
            generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
            port map (
              InA   =>  syndrome_6_reg (0 to 5),                        -- [in  std_logic_vector(0 to C_SIZE - 1)]
              Res   =>  syndrome_reg_i (6) );                           -- [out std_logic]       
    


            ---------------------------------------------------------------------------
            -- Generate: GEN_CORR_32
            -- Purpose:  Generate corrected read data based on syndrome value.
            --           All vectors oriented (0:N)
            ---------------------------------------------------------------------------
            GEN_CORR_32: for i in 0 to C_S_AXI_DATA_WIDTH-1 generate
            begin

                ---------------------------------------------------------------------------
                -- Instance:        CORR_ONE_BIT_32
                -- Description:     Generate ECC bits for checking data read from BRAM.
                ---------------------------------------------------------------------------

                CORR_ONE_BIT_32: entity work.correct_one_bit
                generic map (
                    C_USE_LUT6    => C_USE_LUT6,
                    Correct_Value => correct_data_table (i))
                port map (
                    DIn           => axi_rdata_int (31-i),
                    Syndrome      => syndrome_reg_i,
                    DCorr         => axi_rdata_int_corr (31-i));

            end generate GEN_CORR_32;
        
        
        end generate RDATA_W_HAMMING;
        
        
        -- Hsiao ECC done in seperate generate statement (GEN_HSIAO_ECC)
        

    end generate RDATA_W_ECC;





    


    ---------------------------------------------------------------------------
    -- Main AXI-Lite State Machine
    --
    -- Description:     Central processing unit for AXI-Lite write and read address
    --                  channel interface handling and handshaking.
    --                  Handles all arbitration between write and read channels
    --                  to utilize single port to BRAM
    --
    -- Outputs:         axi_wready_int          Registered
    --                  axi_arready_reg         Registered (used in ECC configurations)
    --                  bvalid_cnt_inc          Combinatorial
    --                  axi_rvalid_set          Combinatorial
    --                  axi_rlast_set           Combinatorial
    --                  bram_en_a_cmb           Combinatorial
    --                  bram_en_b_cmb           Combinatorial
    --                  bram_we_a_int           Combinatorial
    --
    --
    -- LITE_SM_CMB_PROCESS:      Combinational process to determine next state.
    -- LITE_SM_REG_PROCESS:      Registered process of the state machine.
    --
    ---------------------------------------------------------------------------
    
    LITE_SM_CMB_PROCESS: process ( AXI_AWVALID,
                                   AXI_WVALID,
                                   AXI_WSTRB,
                                   AXI_ARVALID,
                                   AXI_RREADY,
                                   bvalid_cnt,
                                   axi_rvalid_int,
                                   lite_sm_cs )

    begin

    -- assign default values for state machine outputs
    lite_sm_ns <= lite_sm_cs;
       
    axi_wready_cmb <= '0';
    axi_arready_cmb <= '0';
    
    bvalid_cnt_inc <= '0';
    
    axi_rvalid_set <= '0';
    axi_rlast_set <= '0';
    
    bram_en_a_cmb <= '0';
    bram_en_b_cmb <= '0';
    
    bram_we_a_int <= (others => '0');


    case lite_sm_cs is


            ---------------------------- IDLE State ---------------------------
            
            when IDLE =>

                
                -- AXI Interconnect will only issue AWVALID OR ARVALID
                -- at a time.  In the case when the core is attached
                -- to another AXI master IP, arbitrate between read
                -- and write operation.  Read operation will always win.
                
                if (AXI_ARVALID = '1') then

                    lite_sm_ns <= RD_DATA;                   
                    
                    -- Initiate BRAM read transfer
                    -- For single port BRAM, use Port A
                    -- For dual port BRAM, use Port B
                    
                    if (C_SINGLE_PORT_BRAM = 1) then
                        bram_en_a_cmb <= '1';
                    else
                        bram_en_b_cmb <= '1';                    
                    end if;
                    
                    bram_we_a_int <= (others => '0');


                    -- RVALID to be asserted in next clock cycle
                    -- Only 1 clock cycle latency on reading data from BRAM
                    axi_rvalid_set <= '1';     

                    -- Due to single data beat with AXI-Lite
                    -- Assert RLAST on AXI
                    axi_rlast_set <= '1';
                    
                    -- Only in ECC configurations
                    -- Must assert ARREADY here (no pre-assertion)
                    if (C_ECC = 1) then
                        axi_arready_cmb <= '1';
                    end if;
                    

                -- Write operations are lower priority than reads
                -- when an AXI master asserted both operations simultaneously.
                
                elsif (AXI_AWVALID = '1') and (AXI_WVALID = '1') and 
                      (bvalid_cnt /= "111") then
                                    
                    -- Initiate BRAM write transfer
                    bram_en_a_cmb <= '1';                    
                
                
                    -- Always perform a read-modify-write sequence with ECC is enabled.
                    if (C_ECC = 1) then
                        
                        lite_sm_ns <= RMW_RD_DATA;
                    
                        -- Disable Port A write enables
                        bram_we_a_int <= (others => '0');
                    
                    else
                        -- Non ECC operation or an ECC full 32-bit word write
                
                        -- Assert acknowledge of data & address on AXI.
                        -- Wait to assert AWREADY and WREADY in ECC designs.
                        axi_wready_cmb <= '1';
                        
                        -- Increment counter to track # of required BVALID responses.
                        bvalid_cnt_inc <= '1';

                        lite_sm_ns <= SNG_WR_DATA;
                        bram_we_a_int <= AXI_WSTRB;
                        
                    end if;
                        
                end if;
             



            ------------------------- SNG_WR_DATA State -------------------------

            when SNG_WR_DATA =>


                -- With early assertion of ARREADY, the SM
                -- must be able to accept a read address at any clock cycle.
                
                -- Check here for active ARVALID and directly handle read
                -- and do not proceed back to IDLE (no empty clock cycle in which
                -- read address may be missed).

                
                if (AXI_ARVALID = '1') and (C_ECC = 0) then

                    lite_sm_ns <= RD_DATA;                   
                    
                    -- Initiate BRAM read transfer
                    -- For single port BRAM, use Port A
                    -- For dual port BRAM, use Port B
                    
                    if (C_SINGLE_PORT_BRAM = 1) then
                        bram_en_a_cmb <= '1';
                    else
                        bram_en_b_cmb <= '1';                    
                    end if;
                    
                    bram_we_a_int <= (others => '0');

                    -- RVALID to be asserted in next clock cycle
                    -- Only 1 clock cycle latency on reading data from BRAM
                    axi_rvalid_set <= '1';     

                    -- Due to single data beat with AXI-Lite
                    -- Assert RLAST on AXI
                    axi_rlast_set <= '1';

                    -- Only in ECC configurations
                    -- Must assert ARREADY here (no pre-assertion)
                    -- Pre-assertion of ARREADY is only for non ECC configurations.
                    if (C_ECC = 1) then
                        axi_arready_cmb <= '1';
                    end if;
                
                else
                                        
                    lite_sm_ns <= IDLE;
                    
                end if;



            ---------------------------- RD_DATA State ---------------------------
            
            when RD_DATA =>


                -- Data is presented to AXI bus
                -- Wait for acknowledgment to process any next transfers
                -- RVALID may not be asserted as we transition into this state.
                if (AXI_RREADY = '1') and (axi_rvalid_int = '1') then

                    lite_sm_ns <= IDLE;
                    
                end if;


            ------------------------- RMW_RD_DATA State -------------------------

            when RMW_RD_DATA =>
  
                lite_sm_ns <= RMW_MOD_DATA;                                           


            ------------------------- RMW_MOD_DATA State -------------------------

            when RMW_MOD_DATA =>
  
                lite_sm_ns <= RMW_WR_DATA;

                -- Hold off on assertion of WREADY and AWREADY until
                -- here, so no pipeline registers necessary.
                -- Assert acknowledge of data & address on AXI 
                axi_wready_cmb <= '1';
                
                -- Increment counter to track # of required BVALID responses.
                -- Able to assert this signal early, then BVALID counter
                -- will get incremented in the next clock cycle when WREADY
                -- is asserted.
                bvalid_cnt_inc <= '1';
                

            ------------------------- RMW_WR_DATA State -------------------------

            when RMW_WR_DATA =>

                -- Initiate BRAM write transfer
                bram_en_a_cmb <= '1';                    

                -- Enable all WEs to BRAM
                bram_we_a_int <= (others => '1');
                
                -- Complete write operation 
                lite_sm_ns <= IDLE;
                               
                                           

    --coverage off
            ------------------------------ Default ----------------------------
            when others =>
                lite_sm_ns <= IDLE;
    --coverage on

        end case;
        
    end process LITE_SM_CMB_PROCESS;



    ---------------------------------------------------------------------------


    LITE_SM_REG_PROCESS: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
        
            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                lite_sm_cs <= IDLE;         
                axi_wready_int <= '0';
                axi_arready_reg <= '0';
                axi_rvalid_set_r <= '0';
                axi_rlast_set_r <= '0';
            else
                lite_sm_cs <= lite_sm_ns;     
                axi_wready_int <= axi_wready_cmb;
                axi_arready_reg <= axi_arready_cmb;
                axi_rvalid_set_r <= axi_rvalid_set;
                axi_rlast_set_r <= axi_rlast_set;
            end if;
        end if;
        
    end process LITE_SM_REG_PROCESS;


    ---------------------------------------------------------------------------







    ---------------------------------------------------------------------------
    -- *** ECC Logic ***
    ---------------------------------------------------------------------------



    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_ECC
    -- Purpose:     Generate BRAM ECC write data and check ECC on read operations.
    --              Create signals to update ECC registers (lite_ecc_reg module interface).
    --
    ---------------------------------------------------------------------------

    GEN_ECC: if C_ECC = 1 generate
    
    constant null7 : std_logic_vector(0 to 6) := "0000000"; -- Specific to 32-bit data width (AXI-Lite)
    
    signal WrECC        : std_logic_vector (C_INT_ECC_WIDTH-1 downto 0); -- Specific to BRAM data width
    signal WrECC_i      : std_logic_vector (C_ECC_WIDTH-1 downto 0) := (others => '0');
    signal wrdata_i     : std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0);
    signal AXI_WDATA_Q  : std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0);
    signal AXI_WSTRB_Q  : std_logic_vector ((C_S_AXI_DATA_WIDTH/8 - 1) downto 0);

    signal bram_din_a_i  : std_logic_vector (0 to C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1) := (others => '0'); -- Set for port data width
    signal bram_rddata_in : std_logic_vector (C_S_AXI_DATA_WIDTH+C_INT_ECC_WIDTH-1 downto 0) := (others => '0');


    subtype syndrome_bits is std_logic_vector (0 to 6);
    type correct_data_table_type is array (natural range 0 to 31) of syndrome_bits;
    
    constant correct_data_table : correct_data_table_type := (
      0 => "1100001",  1 => "1010001",  2 => "0110001",  3 => "1110001",
      4 => "1001001",  5 => "0101001",  6 => "1101001",  7 => "0011001",
      8 => "1011001",  9 => "0111001",  10 => "1111001",  11 => "1000101",
      12 => "0100101",  13 => "1100101",  14 => "0010101",  15 => "1010101",
      16 => "0110101",  17 => "1110101",  18 => "0001101",  19 => "1001101",
      20 => "0101101",  21 => "1101101",  22 => "0011101",  23 => "1011101",
      24 => "0111101",  25 => "1111101",  26 => "1000011",  27 => "0100011",
      28 => "1100011",  29 => "0010011",  30 => "1010011",  31 => "0110011"
      );

    type bool_array is array (natural range 0 to 6) of boolean;
    constant inverted_bit : bool_array := (false,false,true,false,true,false,false);

    begin
    
        -- Read on Port A 
        -- or any operation on Port B (it will be read only).
        BRAM_Addr_En <= '1' when (bram_en_a_int = '1' and bram_we_a_int = "00000") or
                                 (bram_en_b_int = '1')
                                 else '0'; 

        -- BRAM_WE generated from SM

        -- Remember byte write enables one clock cycle to properly mux bytes to write,
        -- with read data in read/modify write operation
        -- Write in Read/Write always 1 cycle after Read
        REG_RMW_SIGS : process (S_AXI_AClk) is
        begin
            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
            
                -- Add reset values
                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    RdModifyWr_Check <= '0';
                    RdModifyWr_Modify <= '0';
                    RdModifyWr_Write <= '0';
                else
                    RdModifyWr_Check <= RdModifyWr_Read;
                    RdModifyWr_Modify <= RdModifyWr_Check;
                    RdModifyWr_Write <= RdModifyWr_Modify;
                end if;
            end if;
        end process REG_RMW_SIGS;
        

        -- v1.03a
        -- Delay assertion of WREADY to minimize registers in core.
        -- Use SM transition to RMW "read" to assert this signal.
        RdModifyWr_Read <= '1' when (lite_sm_ns = RMW_RD_DATA) else '0';

        -- Remember write data one cycle to be available after read has been completed in a
        -- read/modify write operation
        STORE_WRITE_DBUS : process (S_AXI_AClk) is
        begin
            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    AXI_WDATA_Q <= (others => '0');
                    AXI_WSTRB_Q <= (others => '0');

                -- v1.03a
                -- With the delay assertion of WREADY, use WVALID
                -- to register in WDATA and WSTRB signals.
                elsif (AXI_WVALID = '1') then
                    AXI_WDATA_Q <= AXI_WDATA;
                    AXI_WSTRB_Q <= AXI_WSTRB;
                end if;
            end if;
        end process STORE_WRITE_DBUS;

        wrdata_i <= AXI_WDATA_Q when RdModifyWr_Modify = '1' else AXI_WDATA;
        

        -- v1.03a

        ------------------------------------------------------------------------
        -- Generate:     GEN_WRDATA_CMB
        -- Purpose:      Replace manual signal assignment for WrData_cmb with 
        --               generate funtion.
        --
        --               Ensure correct byte swapping occurs with 
        --               CorrectedRdData (0 to C_S_AXI_DATA_WIDTH-1) assignment
        --               to WrData_cmb (C_S_AXI_DATA_WIDTH-1 downto 0).
        --
        --               AXI_WSTRB_Q (C_S_AXI_DATA_WIDTH_BYTES-1 downto 0) matches
        --               to WrData_cmb (C_S_AXI_DATA_WIDTH-1 downto 0).
        --
        ------------------------------------------------------------------------

        GEN_WRDATA_CMB: for i in C_AXI_DATA_WIDTH_BYTES-1 downto 0 generate
        begin

            WrData_cmb ( (((i+1)*8)-1) downto i*8 ) <= wrdata_i ((((i+1)*8)-1) downto i*8) when 
                                               (RdModifyWr_Modify = '1' and AXI_WSTRB_Q(i) = '1') 
                                            else CorrectedRdData ( (C_S_AXI_DATA_WIDTH - ((i+1)*8)) to 
                                                                   (C_S_AXI_DATA_WIDTH - (i*8) - 1) );
        end generate GEN_WRDATA_CMB;
       
       
        REG_WRDATA : process (S_AXI_AClk) is
        begin
             -- Remove reset value to minimize resources & improve timing
             if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                 WrData <= WrData_cmb;   
             end if;
        end process REG_WRDATA;
        


       ------------------------------------------------------------------------

        -- New assignment of ECC bits to BRAM write data outside generate
        -- blocks.  Same signal assignment regardless of ECC type.
        
        bram_wrdata_a_int (C_S_AXI_DATA_WIDTH + C_ECC_WIDTH - 1) <= '0';
        bram_wrdata_a_int ((C_S_AXI_DATA_WIDTH + C_INT_ECC_WIDTH - 1) downto C_S_AXI_DATA_WIDTH)
                            <= WrECC xor FaultInjectECC;  


       ------------------------------------------------------------------------

        
        -- No need to use RdModifyWr_Write in the data path.


        -- v1.03a

        ------------------------------------------------------------------------
        -- Generate:     GEN_HAMMING_ECC
        -- Purpose:      Determine type of ECC encoding.  Hsiao or Hamming.  
        --               Add parameter/generate level.
        ------------------------------------------------------------------------
        GEN_HAMMING_ECC: if C_ECC_TYPE = 0 generate
        begin
        
       
            ---------------------------------------------------------------------------
            -- Instance:        CHK_HANDLER_WR_32
            -- Description:     Generate ECC bits for writing into BRAM.
            --                  WrData (N:0)
            ---------------------------------------------------------------------------

            CHK_HANDLER_WR_32: entity work.checkbit_handler
            generic map (
                C_ENCODE        =>  true,           -- [boolean]
                C_USE_LUT6      =>  C_USE_LUT6)     -- [boolean]
            port map (
                DataIn          =>  WrData,         -- [in  std_logic_vector(0 to 31)]
                CheckIn         =>  null7,          -- [in  std_logic_vector(0 to 6)]
                CheckOut        =>  WrECC,          -- [out std_logic_vector(0 to 6)]
                Syndrome_4      =>  open,           -- [out std_logic_vector(0 to 1)]
                Syndrome_6      =>  open,           -- [out std_logic_vector(0 to 5)]
                Syndrome        =>  open,           -- [out std_logic_vector(0 to 6)]
                Enable_ECC      =>  '1',            -- [in  std_logic]
                Syndrome_Chk    =>  null7,          -- [in  std_logic_vector(0 to 6)]
                UE_Q            =>  '0',            -- [in  std_logic]
                CE_Q            =>  '0',            -- [in  std_logic]
                UE              =>  open,           -- [out std_logic]
                CE              =>  open );         -- [out std_logic]


   
                            
            ---------------------------------------------------------------------------
            -- Instance:        CHK_HANDLER_RD_32
            -- Description:     Generate ECC bits for checking data read from BRAM.
            --                  All vectors oriented (0:N)
            ---------------------------------------------------------------------------

            CHK_HANDLER_RD_32: entity work.checkbit_handler
              generic map (
                C_ENCODE    =>  false,                 -- [boolean]
                C_USE_LUT6  =>  C_USE_LUT6)            -- [boolean]
              port map (

                -- DataIn (8:39)
                -- CheckIn (1:7)
                -- Bit swapping done at port level on checkbit_handler (31:0) & (6:0)
                DataIn          =>  bram_din_a_i (C_INT_ECC_WIDTH+1 to C_INT_ECC_WIDTH+C_S_AXI_DATA_WIDTH),      -- [in  std_logic_vector(8 to 39)]
                CheckIn         =>  bram_din_a_i (1 to C_INT_ECC_WIDTH),                                         -- [in  std_logic_vector(1 to 7)]

                CheckOut        =>  open,                                                                        -- [out std_logic_vector(0 to 6)]
                Syndrome        =>  Syndrome,                                                                    -- [out std_logic_vector(0 to 6)]
                Syndrome_4      =>  Syndrome_4,                                                                  -- [out std_logic_vector(0 to 1)]
                Syndrome_6      =>  Syndrome_6,                                                                  -- [out std_logic_vector(0 to 5)]
                Syndrome_Chk    =>  syndrome_reg_i,                                                              -- [in  std_logic_vector(0 to 6)]
                Enable_ECC      =>  Enable_ECC,                                                                  -- [in  std_logic]
                UE_Q            =>  UE_Q,                                                                        -- [in  std_logic]
                CE_Q            =>  CE_Q,                                                                        -- [in  std_logic]
                UE              =>  Sl_UE_i,                                                                     -- [out std_logic]
                CE              =>  Sl_CE_i );                                                                   -- [out std_logic]



            -- GEN_CORR_32 generate & correct_one_bit instantiation moved to generate
            -- of AXI RDATA output register logic to use registered syndrome value.
            
        end generate GEN_HAMMING_ECC;
        
        


        -- v1.03a

        ------------------------------------------------------------------------
        -- Generate:     GEN_HSIAO_ECC
        -- Purpose:      Determine type of ECC encoding.  Hsiao or Hamming.  
        --               Add parameter/generate level.
        --               Derived from MIG v3.7 Hsiao HDL.
        ------------------------------------------------------------------------
        GEN_HSIAO_ECC: if C_ECC_TYPE = 1 generate

        constant CODE_WIDTH  : integer := C_S_AXI_DATA_WIDTH + C_INT_ECC_WIDTH;
        constant ECC_WIDTH   : integer := C_INT_ECC_WIDTH;

        type type_int0 is array (C_S_AXI_DATA_WIDTH - 1 downto 0) of std_logic_vector (ECC_WIDTH - 1 downto 0);

        signal syndrome_ns   : std_logic_vector(ECC_WIDTH - 1 downto 0);
        signal syndrome_r    : std_logic_vector(ECC_WIDTH - 1 downto 0);

        signal ecc_rddata_r  : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
        signal h_matrix      : type_int0;

        signal h_rows        : std_logic_vector (CODE_WIDTH * ECC_WIDTH - 1 downto 0);
        signal flip_bits     : std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);

        begin
        
            
            ---------------------- Hsiao ECC Write Logic ----------------------

            -- Instantiate ecc_gen module, generated from MIG

            ECC_GEN_HSIAO: entity work.ecc_gen
               generic map (
                  code_width  => CODE_WIDTH,
                  ecc_width   => ECC_WIDTH,
                  data_width  => C_S_AXI_DATA_WIDTH
               )
               port map (
                  -- Output
                  h_rows  => h_rows (CODE_WIDTH * ECC_WIDTH - 1 downto 0)
               );
        
        
            -- Merge muxed rd/write data to gen               
            HSIAO_ECC: process (h_rows, WrData)
            
            constant DQ_WIDTH : integer := CODE_WIDTH;
            variable ecc_wrdata_tmp : std_logic_vector(DQ_WIDTH-1 downto C_S_AXI_DATA_WIDTH);
            
            begin                
                -- Loop to generate all ECC bits
                for k in 0 to  ECC_WIDTH - 1 loop                        
                    ecc_wrdata_tmp (CODE_WIDTH - k - 1) := REDUCTION_XOR ( (WrData (C_S_AXI_DATA_WIDTH - 1 downto 0) 
                                                                            and h_rows (k * CODE_WIDTH + C_S_AXI_DATA_WIDTH - 1 downto k * CODE_WIDTH)));
                end loop;

                WrECC (C_INT_ECC_WIDTH-1 downto 0) <= ecc_wrdata_tmp (DQ_WIDTH-1 downto C_S_AXI_DATA_WIDTH);
                 
            end process HSIAO_ECC;



            ---------------------- Hsiao ECC Read Logic -----------------------

            GEN_RD_ECC: for m in 0 to ECC_WIDTH - 1 generate
            begin
                syndrome_ns (m) <= REDUCTION_XOR ( bram_rddata_in (CODE_WIDTH-1 downto 0)
                                                   and h_rows ((m*CODE_WIDTH)+CODE_WIDTH-1 downto (m*CODE_WIDTH)));
            end generate GEN_RD_ECC;

            -- Insert register stage for syndrome 
            REG_SYNDROME: process (S_AXI_AClk)
            begin        
                if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then            
                    syndrome_r <= syndrome_ns; 
                    
                    -- Replicate BRAM read back data register for Hamming ECC
                    ecc_rddata_r <= bram_rddata_in (C_S_AXI_DATA_WIDTH-1 downto 0);
                end if;
            end process REG_SYNDROME;

            -- Reconstruct H-matrix
            H_COL: for n in 0 to C_S_AXI_DATA_WIDTH - 1 generate
            begin
                H_BIT: for p in 0 to ECC_WIDTH - 1 generate
                begin
                    h_matrix (n)(p) <= h_rows (p * CODE_WIDTH + n);
                end generate H_BIT;
            end generate H_COL;


            GEN_FLIP_BIT: for r in 0 to C_S_AXI_DATA_WIDTH - 1 generate
            begin
               flip_bits (r) <= BOOLEAN_TO_STD_LOGIC (h_matrix (r) = syndrome_r);
            end generate GEN_FLIP_BIT;


            axi_rdata_int_corr (C_S_AXI_DATA_WIDTH-1 downto 0) <= ecc_rddata_r (C_S_AXI_DATA_WIDTH-1 downto 0) xor
                                                             flip_bits (C_S_AXI_DATA_WIDTH-1 downto 0);

            Sl_CE_i <= not (REDUCTION_NOR (syndrome_r (ECC_WIDTH-1 downto 0))) and (REDUCTION_XOR (syndrome_r (ECC_WIDTH-1 downto 0)));
            Sl_UE_i <= not (REDUCTION_NOR (syndrome_r (ECC_WIDTH-1 downto 0))) and not (REDUCTION_XOR (syndrome_r (ECC_WIDTH-1 downto 0)));

        
        
        end generate GEN_HSIAO_ECC;
            

        -- Capture correctable/uncorrectable error from BRAM read.
        -- Either during RMW of write operation or during BRAM read.
        CORR_REG: process(S_AXI_AClk) is
        begin
            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                if RdModifyWr_Modify = '1' or 
                   ((Enable_ECC = '1') and 
                    (axi_rvalid_int = '1' and AXI_RREADY = '1')) then     -- Capture error signals 
                    CE_Q <= Sl_CE_i;
                    UE_Q <= Sl_UE_i;
                
                else              
                    CE_Q <= '0';
                    UE_Q <= '0';
                end if;          
            end if;
        end process CORR_REG;

        -- Register CE and UE flags to register block.
        Sl_CE <= CE_Q;
        Sl_UE <= UE_Q;
        
        
        
        ---------------------------------------------------------------------------
        -- Generate: GEN_DIN_A
        -- Purpose:  Generate BRAM read data vector assignment to always be from Port A
        --           in a single port BRAM configuration.
        --           Map BRAM_RdData_A (N:0) to bram_din_a_i (0:N)
        --           Including read back ECC bits.
        ---------------------------------------------------------------------------
        GEN_DIN_A: if C_SINGLE_PORT_BRAM = 1 generate
        begin
        
            ---------------------------------------------------------------------------
            -- Generate:    GEN_DIN_A_HAMMING 
            -- Purpose:     Standard input for Hamming ECC code generation. 
            --              MSB '0' is removed in port mapping to checkbit_handler module.
            ---------------------------------------------------------------------------
            GEN_DIN_A_HAMMING: if C_ECC_TYPE = 0 generate
            begin
                bram_din_a_i (0 to C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1) <= BRAM_RdData_A (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0);
            end generate GEN_DIN_A_HAMMING;
    

            ---------------------------------------------------------------------------
            -- Generate:    GEN_DIN_A_HSIAO 
            -- Purpose:     For Hsiao ECC implementation configurations.
            --              Remove MSB '0' on 32-bit implementation with fixed 
            --              '0' in (8-bit wide) ECC data bits (only need 7-bits in h-matrix).
            ---------------------------------------------------------------------------
            GEN_DIN_A_HSIAO: if C_ECC_TYPE = 1 generate
            begin
                bram_rddata_in <= BRAM_RdData_A (C_S_AXI_DATA_WIDTH+C_INT_ECC_WIDTH-1 downto 0);
            end generate GEN_DIN_A_HSIAO;


        end generate GEN_DIN_A;
                            
                            
        ---------------------------------------------------------------------------
        -- Generate: GEN_DIN_B
        -- Purpose:  Generate BRAM read data vector assignment in a dual port
        --           configuration to be either from Port B, or from Port A in a 
        --           read-modify-write sequence.
        --           Map BRAM_RdData_A/B (N:0) to bram_din_a_i (0:N)
        --           Including read back ECC bits.
        ---------------------------------------------------------------------------
        GEN_DIN_B: if C_SINGLE_PORT_BRAM = 0 generate
        begin
        
            ---------------------------------------------------------------------------
            -- Generate:    GEN_DIN_B_HAMMING 
            -- Purpose:     Standard input for Hamming ECC code generation. 
            --              MSB '0' is removed in port mapping to checkbit_handler module.
            ---------------------------------------------------------------------------
            GEN_DIN_B_HAMMING: if C_ECC_TYPE = 0 generate
            begin
                bram_din_a_i (0 to C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1) <= BRAM_RdData_A (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0) 
                                                                    when (RdModifyWr_Check = '1') 
                                                                    else BRAM_RdData_B (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0);     
            
            end generate GEN_DIN_B_HAMMING;
            
            
            ---------------------------------------------------------------------------
            -- Generate:    GEN_DIN_B_HSIAO 
            -- Purpose:     For Hsiao ECC implementation configurations.
            --              Remove MSB '0' on 32-bit implementation with fixed 
            --              '0' in (8-bit wide) ECC data bits (only need 7-bits in h-matrix).
            ---------------------------------------------------------------------------
            GEN_DIN_B_HSIAO: if C_ECC_TYPE = 1 generate
            begin
                bram_rddata_in <= BRAM_RdData_A (C_S_AXI_DATA_WIDTH+C_INT_ECC_WIDTH-1 downto 0) 
                                  when (RdModifyWr_Check = '1') 
                                  else BRAM_RdData_B (C_S_AXI_DATA_WIDTH+C_INT_ECC_WIDTH-1 downto 0);  
            end generate GEN_DIN_B_HSIAO;
                   
                   
        end generate GEN_DIN_B;
        

        -- Map data vector from BRAM to use in correct_one_bit module with 
        -- register syndrome (post AXI RDATA register).
		UnCorrectedRdData (0 to C_S_AXI_DATA_WIDTH-1) <= bram_din_a_i (C_ECC_WIDTH to C_ECC_WIDTH+C_S_AXI_DATA_WIDTH-1) when (C_ECC_TYPE = 0) else bram_rddata_in(C_S_AXI_DATA_WIDTH-1 downto 0);
        
        
                            
    end generate GEN_ECC;



    ---------------------------------------------------------------------------



    

    


    ---------------------------------------------------------------------------
    -- *** BRAM Interface Signals ***
    ---------------------------------------------------------------------------



    -- With AXI-LITE no narrow operations are allowed.
    -- AXI_WSTRB is ignored and all byte lanes are written.


    bram_en_a_int <= bram_en_a_cmb;    
    --    BRAM_En_A <= bram_en_a_int;   

    -- DV regression failure with reset
    -- 7/7/11
    BRAM_En_A <= '0' when (S_AXI_AResetn = C_RESET_ACTIVE) else bram_en_a_int;   

    
    -----------------------------------------------------------------------
    -- Generate:    GEN_BRAM_EN_DUAL_PORT
    -- Purpose:     Only generate Port B BRAM enable signal when 
    --              configured for dual port BRAM.
    -----------------------------------------------------------------------
    GEN_BRAM_EN_DUAL_PORT: if (C_SINGLE_PORT_BRAM = 0) generate
    begin
        bram_en_b_int <= bram_en_b_cmb;
        BRAM_En_B <= bram_en_b_int;   
    end generate GEN_BRAM_EN_DUAL_PORT;

    

    -----------------------------------------------------------------------
    -- Generate:    GEN_BRAM_EN_SNG_PORT
    -- Purpose:     Drive default for unused BRAM Port B in single
    --              port BRAM configuration.
    -----------------------------------------------------------------------
    GEN_BRAM_EN_SNG_PORT: if (C_SINGLE_PORT_BRAM = 1) generate
    begin
        BRAM_En_B <= '0';   
    end generate GEN_BRAM_EN_SNG_PORT;



    ---------------------------------------------------------------------------
    -- Generate:    GEN_BRAM_WE
    -- Purpose:     BRAM WE generate process
    --              One WE per 8-bits of BRAM data.
    ---------------------------------------------------------------------------
    
    GEN_BRAM_WE: for i in (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH)/8-1 downto 0 generate
    begin
        BRAM_WE_A (i) <= bram_we_a_int (i);        
    end generate GEN_BRAM_WE;
            

    ---------------------------------------------------------------------------


    BRAM_Addr_A <= BRAM_Addr_A_i;
    BRAM_Addr_B <= BRAM_Addr_B_i;

    ---------------------------------------------------------------------------
    -- Generate:    GEN_L_BRAM_ADDR
    -- Purpose:     Generate zeros on lower order address bits adjustable
    --              based on BRAM data width.
    ---------------------------------------------------------------------------

    GEN_L_BRAM_ADDR: for i in C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0 generate
    begin    
        BRAM_Addr_A_i (i) <= '0';        
        BRAM_Addr_B_i (i) <= '0';        
    end generate GEN_L_BRAM_ADDR;




    ---------------------------------------------------------------------------
    -- Generate:    GEN_BRAM_ADDR
    -- Purpose:     Assign BRAM address output from address counter.
    ---------------------------------------------------------------------------

    GEN_U_BRAM_ADDR: for i in C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR generate
    begin    


        BRAM_Addr_A_i (i) <= bram_addr_a_int (i);


        -----------------------------------------------------------------------
        -- Generate:    GEN_BRAM_ADDR_DUAL_PORT
        -- Purpose:     Only generate Port B BRAM address when 
        --              configured for dual port BRAM.
        -----------------------------------------------------------------------

        GEN_BRAM_ADDR_DUAL_PORT: if (C_SINGLE_PORT_BRAM = 0) generate
        begin
            BRAM_Addr_B_i (i) <= bram_addr_b_int (i);   
        end generate GEN_BRAM_ADDR_DUAL_PORT;


        -----------------------------------------------------------------------
        -- Generate:    GEN_BRAM_ADDR_SNG_PORT
        -- Purpose:     Drive default for unused BRAM Port B in single
        --              port BRAM configuration.
        -----------------------------------------------------------------------

        GEN_BRAM_ADDR_SNG_PORT: if (C_SINGLE_PORT_BRAM = 1) generate
        begin
            BRAM_Addr_B_i (i) <= '0';   
        end generate GEN_BRAM_ADDR_SNG_PORT;

        
    end generate GEN_U_BRAM_ADDR;
    



    ---------------------------------------------------------------------------
    -- Generate:    GEN_BRAM_WRDATA
    -- Purpose:     Generate BRAM Write Data for Port A.
    ---------------------------------------------------------------------------

    -- When C_ECC = 0, C_ECC_WIDTH = 0 (at top level HDL)
    GEN_BRAM_WRDATA: for i in (C_S_AXI_DATA_WIDTH + C_ECC_WIDTH - 1) downto 0 generate
    begin        
        BRAM_WrData_A (i) <= bram_wrdata_a_int (i);           
    end generate GEN_BRAM_WRDATA;


    
    BRAM_WrData_B <= (others => '0');
    BRAM_WE_B <= (others => '0');

    

    ---------------------------------------------------------------------------




end architecture implementation;










-------------------------------------------------------------------------------
-- sng_port_arb.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
-------------------------------------------------------------------------------
-- Filename:        sng_port_arb.vhd
--
-- Description:     This file is the top level arbiter for full AXI4 mode
--                  when configured in a single port mode to BRAM.
--
-- VHDL-Standard:   VHDL'93
--
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- checkbit_handler_64.vhd
--                      |       -- (same helper components as checkbit_handler)
--                      |   -- correct_one_bit.vhd
--                      |   -- correct_one_bit_64.vhd
--
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/2/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
-- JLJ      4/11/2011         v1.03a
-- ~~~~~~
--  Add input signal, AW2Arb_BVALID_Cnt, from wr_chnl. For configurations
--  when WREADY is to be a registered output.  With a seperate FIFO for BID,
--  ensure arbitration does not get more than 8 ahead of BID responses.  A 
--  value of 8 is the max of the BVALID counter.
-- ^^^^^^
--
--
--
--  
-------------------------------------------------------------------------------

-- Library declarations

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;



------------------------------------------------------------------------------


entity sng_port_arb is
generic (

    C_S_AXI_ADDR_WIDTH : integer := 32
      -- Width of AXI address bus (in bits)
    
    );
  port (

    
    -- *** AXI Clock and Reset ***
    S_AXI_ACLK              : in    std_logic;
    S_AXI_ARESETN           : in    std_logic;      

    -- *** AXI Write Address Channel Signals (AW) *** 
    AXI_AWADDR              : in    std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    AXI_AWVALID             : in    std_logic;
    AXI_AWREADY             : out   std_logic := '0';

 
    -- *** AXI Read Address Channel Signals (AR) *** 
    AXI_ARADDR              : in    std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    AXI_ARVALID             : in    std_logic;
    AXI_ARREADY             : out   std_logic := '0';
    
    
    
    -- *** Write Channel Interface Signals ***
    Arb2AW_Active               : out   std_logic := '0';
    AW2Arb_Busy                 : in    std_logic;
    AW2Arb_Active_Clr           : in    std_logic;
    AW2Arb_BVALID_Cnt           : in    std_logic_vector (2 downto 0);
    

    -- *** Read Channel Interface Signals ***
    Arb2AR_Active               : out   std_logic := '0';
    AR2Arb_Active_Clr           : in    std_logic

    

    );



end entity sng_port_arb;


-------------------------------------------------------------------------------

architecture implementation of sng_port_arb is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";


-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------




-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

constant C_RESET_ACTIVE     : std_logic := '0';
constant ARB_WR : std_logic := '0';
constant ARB_RD : std_logic := '1';




-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------



-------------------------------------------------------------------------------
-- AXI Write & Read Address Channel Signals
-------------------------------------------------------------------------------


-- State machine type declarations
type ARB_SM_TYPE is ( IDLE,
                      RD_DATA,
                      WR_DATA
                    );
                    
signal arb_sm_cs, arb_sm_ns : ARB_SM_TYPE;

signal axi_awready_cmb      : std_logic := '0';
signal axi_awready_int      : std_logic := '0';

signal axi_arready_cmb      : std_logic := '0';
signal axi_arready_int      : std_logic := '0';


signal last_arb_won_cmb     : std_logic := '0';
signal last_arb_won         : std_logic := '0';

signal aw_active_cmb        : std_logic := '0';     
signal aw_active            : std_logic := '0';
signal ar_active_cmb        : std_logic := '0';  
signal ar_active            : std_logic := '0';



-------------------------------------------------------------------------------
-- Architecture Body
-------------------------------------------------------------------------------


begin 



    ---------------------------------------------------------------------------
    -- *** AXI Output Signals ***
    ---------------------------------------------------------------------------


    -- AXI Write Address Channel Output Signals
    AXI_AWREADY <=  axi_awready_int;

    --  AXI Read Address Channel Output Signals 
    AXI_ARREADY <= axi_arready_int;




    ---------------------------------------------------------------------------
    -- *** AXI Write Address Channel Interface ***
    ---------------------------------------------------------------------------






    ---------------------------------------------------------------------------
    -- *** AXI Read Address Channel Interface ***
    ---------------------------------------------------------------------------



    ---------------------------------------------------------------------------
    -- *** Internal Arbitration Interface ***
    ---------------------------------------------------------------------------
    
    Arb2AW_Active <= aw_active;
    Arb2AR_Active <= ar_active;
    

    ---------------------------------------------------------------------------
    -- Main Arb State Machine
    --
    -- Description:             Main arbitration logic when AXI BRAM controller
    --                          configured in a single port BRAM mode.
    --                          Module is instantiated when C_SINGLE_PORT_BRAM = 1.
    --
    -- Outputs:                 last_arb_won        Registered
    --                          aw_active           Registered
    --                          ar_active           Registered
    --                          axi_awready_int     Registered        
    --                          axi_arready_int     Registered          
    --
    --
    -- ARB_SM_CMB_PROCESS:      Combinational process to determine next state.
    -- ARB_SM_REG_PROCESS:      Registered process of the state machine.
    --
    ---------------------------------------------------------------------------
    
    ARB_SM_CMB_PROCESS: process ( AXI_AWVALID,
                                  AXI_ARVALID,
                                  AW2Arb_BVALID_Cnt,
                                  AW2Arb_Busy,
                                  AW2Arb_Active_Clr,
                                  AR2Arb_Active_Clr,
                                  last_arb_won,
                                  aw_active,
                                  ar_active,
                                  arb_sm_cs )

    begin

    -- assign default values for state machine outputs
    arb_sm_ns <= arb_sm_cs;
    
    axi_awready_cmb <= '0';
    axi_arready_cmb <= '0';
    last_arb_won_cmb <= last_arb_won;
    aw_active_cmb <= aw_active;
    ar_active_cmb <= ar_active;


    case arb_sm_cs is


            ---------------------------- IDLE State ---------------------------
            
            when IDLE =>

                -- Check for valid read operation
                -- Reads take priority over AW traffic (if both asserted)
                -- 4/11
                -- if ((AXI_ARVALID = '1') and (AXI_AWVALID = '1') and (last_arb_won = ARB_WR)) or
                --    ((AXI_ARVALID = '1') and (AXI_AWVALID = '0')) then

                -- 4/11
                -- Add BVALID counter to AW arbitration.
                -- Since this is arbitration to read, no need for BVALID counter.
                if ((AXI_ARVALID = '1') and (AXI_AWVALID = '1') and (last_arb_won = ARB_WR)) or  -- and 
                    --(AW2Arb_BVALID_Cnt /= "111")) or
                   ((AXI_ARVALID = '1') and (AXI_AWVALID = '0')) then


                    -- Read wins arbitration
                    arb_sm_ns <= RD_DATA;
                    axi_arready_cmb <= '1';
                    last_arb_won_cmb <= ARB_RD;    
                    ar_active_cmb <= '1';
                    
                    
                -- Write operations are lower priority than reads
                -- when an AXI master asserted both operations simultaneously.                
                -- 4/11 elsif (AXI_AWVALID = '1') and (AW2Arb_Busy = '0') then
                elsif (AXI_AWVALID = '1') and (AW2Arb_Busy = '0') and 
                      (AW2Arb_BVALID_Cnt /= "111") then
                
                    -- Write wins arbitration                    
                    arb_sm_ns <= WR_DATA;    
                    axi_awready_cmb <= '1';
                    last_arb_won_cmb <= ARB_WR;  
                    aw_active_cmb <= '1';
                    
                end if;
             



            ------------------------- WR_DATA State -------------------------

            when WR_DATA =>
            
                -- Wait for write operation to complete
                if (AW2Arb_Active_Clr = '1') then
                    aw_active_cmb <= '0';
                    
                    -- Check early for pending read (to save clock cycle
                    -- in transitioning back to IDLE)
                    if (AXI_ARVALID = '1') then
                        
                        -- Read wins arbitration
                        arb_sm_ns <= RD_DATA;
                        axi_arready_cmb <= '1';
                        last_arb_won_cmb <= ARB_RD;    
                        ar_active_cmb <= '1';
                        
                        -- Note: if timing paths occur b/w wr_chnl data SM
                        -- and here, remove this clause to check for early
                        -- arbitration on a read operation.                   
                    
                    else                   
                        arb_sm_ns <= IDLE;
                    end if;
                    
                end if;
  
            ---------------------------- RD_DATA State ---------------------------
            
            when RD_DATA =>

                -- Wait for read operation to complete
                if (AR2Arb_Active_Clr = '1') then
                    ar_active_cmb <= '0';
                    
                    -- Check early for pending write operation (to save clock cycle
                    -- in transitioning back to IDLE)
                    -- 4/11 if (AXI_AWVALID = '1') and (AW2Arb_Busy = '0') then
                    if (AXI_AWVALID = '1') and (AW2Arb_Busy = '0') and 
                       (AW2Arb_BVALID_Cnt /= "111") then
                    
                        -- Write wins arbitration                    
                        arb_sm_ns <= WR_DATA;    
                        axi_awready_cmb <= '1';
                        last_arb_won_cmb <= ARB_WR;  
                        aw_active_cmb <= '1';
                        
                        -- Note: if timing paths occur b/w rd_chnl data SM
                        -- and here, remove this clause to check for early
                        -- arbitration on a write operation.                   
                    
                    -- Check early for a pending back-to-back read operation
                    elsif (AXI_AWVALID = '0') and (AXI_ARVALID = '1') then
                    
                        -- Read wins arbitration
                        arb_sm_ns <= RD_DATA;
                        axi_arready_cmb <= '1';
                        last_arb_won_cmb <= ARB_RD;    
                        ar_active_cmb <= '1';
                        
                    else                   
                        arb_sm_ns <= IDLE;
                    end if;

                end if;


    --coverage off
            ------------------------------ Default ----------------------------
            when others =>
                arb_sm_ns <= IDLE;
    --coverage on

        end case;
        
    end process ARB_SM_CMB_PROCESS;



    ---------------------------------------------------------------------------


    ARB_SM_REG_PROCESS: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
        
            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                arb_sm_cs <= IDLE;        
                last_arb_won <= ARB_WR;
                aw_active <= '0';
                ar_active <= '0';
                axi_awready_int <='0';           
                axi_arready_int <='0';           
            else
                arb_sm_cs <= arb_sm_ns;  
                last_arb_won <= last_arb_won_cmb;
                aw_active <= aw_active_cmb;
                ar_active <= ar_active_cmb;
                axi_awready_int <= axi_awready_cmb;           
                axi_arready_int <= axi_arready_cmb;           

            end if;
        end if;
        
    end process ARB_SM_REG_PROCESS;


    ---------------------------------------------------------------------------








end architecture implementation;










-------------------------------------------------------------------------------
-- ua_narrow.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
-------------------------------------------------------------------------------
-- Filename:        ua_narrow.vhd
--
-- Description:     Creates a narrow burst count load value when an operation
--                  is an unaligned narrow WRAP or INCR burst type.  Used by
--                  I_NARROW_CNT module.
--
-- VHDL-Standard:   VHDL'93
--
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- correct_one_bit.vhd
--
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/2/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
-- JLJ      2/4/2011       v1.03a
-- ~~~~~~
--  Edit for scalability and support of 512 and 1024-bit data widths.
-- ^^^^^^
-- JLJ      2/8/2011       v1.03a
-- ~~~~~~
--  Update bit vector usage of address LSB for calculating ua_narrow_load.
--  Add axi_bram_ctrl_funcs package inclusion.
-- ^^^^^^
-- JLJ      3/1/2011        v1.03a
-- ~~~~~~
--  Fix XST handling for DIV functions.  Create seperate process when
--  divisor is not constant and a power of two.
-- ^^^^^^
-- JLJ      3/2/2011        v1.03a
-- ~~~~~~
--  Update range of integer signals.
-- ^^^^^^
-- JLJ      3/4/2011        v1.03a
-- ~~~~~~
--  Remove use of local function, Create_Size_Max.
-- ^^^^^^
-- JLJ      3/11/2011        v1.03a
-- ~~~~~~
--  Remove C_AXI_DATA_WIDTH generate statments.
-- ^^^^^^
-- JLJ      3/14/2011        v1.03a
-- ~~~~~~
--  Update ua_narrow_load signal assignment to pass simulations & XST.
-- ^^^^^^
-- JLJ      3/15/2011        v1.03a
-- ~~~~~~
--  Update multiply function on signal, ua_narrow_wrap_gt_width, 
--  for timing path improvements.  Replace with left shift operation.
-- ^^^^^^
-- JLJ      3/17/2011      v1.03a
-- ~~~~~~
--  Add comments as noted in Spyglass runs. And general code clean-up.
-- ^^^^^^
--
--
-------------------------------------------------------------------------------

-- Library declarations

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.axi_bram_ctrl_funcs.all;


------------------------------------------------------------------------------


entity ua_narrow is
generic (


    C_AXI_DATA_WIDTH : integer := 32;
        -- Width of AXI data bus (in bits)

    C_BRAM_ADDR_ADJUST_FACTOR : integer := 32;
        -- Adjust BRAM address width based on C_AXI_DATA_WIDTH
        
    C_NARROW_BURST_CNT_LEN : integer := 4
        -- Size of narrow burst counter
      
    );
  port (

    curr_wrap_burst             : in    std_logic;
    curr_incr_burst             : in    std_logic;
    bram_addr_ld_en             : in    std_logic;

    curr_axlen                  : in    std_logic_vector (7 downto 0) := (others => '0');
    curr_axsize                 : in    std_logic_vector (2 downto 0) := (others => '0');
    curr_axaddr_lsb             : in    std_logic_vector (C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0) := (others => '0');

    curr_ua_narrow_wrap         : out   std_logic;
    curr_ua_narrow_incr         : out   std_logic;

    ua_narrow_load              : out   std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0)
                                        := (others => '0')  
 

    );



end entity ua_narrow;


-------------------------------------------------------------------------------

architecture implementation of ua_narrow is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";


-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------

-- All functions defined in axi_bram_ctrl_funcs package.


-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

-- Reset active level (common through core)
constant C_RESET_ACTIVE     : std_logic := '0';


-- AXI Size Constants
--      constant C_AXI_SIZE_1BYTE       : std_logic_vector (2 downto 0) := "000";   -- 1 byte
--      constant C_AXI_SIZE_2BYTE       : std_logic_vector (2 downto 0) := "001";   -- 2 bytes
--      constant C_AXI_SIZE_4BYTE       : std_logic_vector (2 downto 0) := "010";   -- 4 bytes = max size for 32-bit BRAM
--      constant C_AXI_SIZE_8BYTE       : std_logic_vector (2 downto 0) := "011";   -- 8 bytes = max size for 64-bit BRAM
--      constant C_AXI_SIZE_16BYTE      : std_logic_vector (2 downto 0) := "100";   -- 16 bytes = max size for 128-bit BRAM
--      constant C_AXI_SIZE_32BYTE      : std_logic_vector (2 downto 0) := "101";   -- 32 bytes = max size for 256-bit BRAM
--      constant C_AXI_SIZE_64BYTE      : std_logic_vector (2 downto 0) := "110";   -- 64 bytes = max size for 512-bit BRAM
--      constant C_AXI_SIZE_128BYTE     : std_logic_vector (2 downto 0) := "111";   -- 128 bytes = max size for 1024-bit BRAM


-- Determine max value of ARSIZE based on the AXI data width.
-- Use function in axi_bram_ctrl_funcs package.
constant C_AXI_SIZE_MAX         : std_logic_vector (2 downto 0) := Create_Size_Max (C_AXI_DATA_WIDTH);

-- Determine the number of bytes based on the AXI data width.
constant C_AXI_DATA_WIDTH_BYTES          : integer := C_AXI_DATA_WIDTH/8;
constant C_AXI_DATA_WIDTH_BYTES_LOG2     : integer := log2(C_AXI_DATA_WIDTH_BYTES);


-- Use constant to compare when LSB of ADDR is equal to zero.
constant axaddr_lsb_zero          : std_logic_vector (C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0) := (others => '0');

-- 8d = size of AxLEN vector
constant C_MAX_LSHIFT_SIZE  : integer := C_AXI_DATA_WIDTH_BYTES_LOG2 + 8;


-- Convert # of data bytes for AXI data bus into an unsigned vector (C_MAX_LSHIFT_SIZE:0).
constant C_AXI_DATA_WIDTH_BYTES_UNSIGNED : unsigned (C_MAX_LSHIFT_SIZE downto 0) := 
                                           to_unsigned (C_AXI_DATA_WIDTH_BYTES, C_MAX_LSHIFT_SIZE+1);


-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------

signal ua_narrow_wrap_gt_width      : std_logic := '0';
signal curr_axsize_unsigned         : unsigned (2 downto 0) := (others => '0');
signal curr_axsize_int          : integer := 0;

signal curr_axlen_unsigned          : unsigned (7 downto 0) := (others => '0');
signal curr_axlen_unsigned_lshift   : unsigned (C_MAX_LSHIFT_SIZE downto 0) := (others => '0');    -- Max = 32768d

signal bytes_per_addr           : integer := 1;     --    range 1 to 128 := 1;
signal size_plus_lsb            : integer range 1 to 256 := 1;
signal narrow_addr_offset       : integer := 1;



-------------------------------------------------------------------------------
-- Architecture Body
-------------------------------------------------------------------------------


begin 



    -- v1.03a
    
    -- Added for narrow INCR bursts with UA addresses
    -- Check if burst is a) INCR type,
    --                   b) a narrow burst (SIZE = full width of bus)
    --                   c) LSB of address is non zero
    curr_ua_narrow_incr <= '1' when (curr_incr_burst = '1') and
                                    (curr_axsize (2 downto 0) /= C_AXI_SIZE_MAX) and
                                    (curr_axaddr_lsb /= axaddr_lsb_zero) and 
                                    (bram_addr_ld_en = '1')
                                    else '0';

    -- v1.03a
    
    -- Detect narrow WRAP bursts
    -- Detect if the operation is a) WRAP type,
    --                            b) a narrow burst (SIZE = full width of bus)
    --                            c) LSB of address is non zero
    --                            d) complete size of WRAP is larger than width of BRAM
    
    curr_ua_narrow_wrap <= '1' when (curr_wrap_burst = '1') and
                                    (curr_axsize (2 downto 0) /= C_AXI_SIZE_MAX) and
                                    (curr_axaddr_lsb /= axaddr_lsb_zero) and 
                                    (bram_addr_ld_en = '1') and
                                    (ua_narrow_wrap_gt_width = '1')
                                    else '0';
    


    ---------------------------------------------------------------------------


    -- v1.03a

    -- Check condition if narrow burst wraps within the size of the BRAM width.
    -- Check if size * length > BRAM width in bytes.
    --
    -- When asserted = '1', means that narrow burst counter is not preloaded early,
    -- the BRAM burst will be contained within the BRAM data width.

    curr_axsize_unsigned <= unsigned (curr_axsize);
    curr_axsize_int <= to_integer (curr_axsize_unsigned);

    curr_axlen_unsigned <= unsigned (curr_axlen);


    -- Original logic with multiply function.
    --
    -- ua_narrow_wrap_gt_width <= '0' when (((2**(to_integer (curr_axsize_unsigned))) * 
    --                                       unsigned (curr_axlen (7 downto 0))) 
    --                                      < C_AXI_DATA_WIDTH_BYTES) 
    --                                else '1';


    -- Replace with left shift operation of AxLEN.
    -- Replace multiply of AxLEN * AxSIZE with a left shift function.
    LEN_LSHIFT: process (curr_axlen_unsigned, curr_axsize_int)
    begin
    
        for i in C_MAX_LSHIFT_SIZE downto 0 loop
        
            if (i >= curr_axsize_int + 8) then
                curr_axlen_unsigned_lshift (i) <= '0';
            elsif (i >= curr_axsize_int) then
                curr_axlen_unsigned_lshift (i) <= curr_axlen_unsigned (i - curr_axsize_int);
            else
                curr_axlen_unsigned_lshift (i) <= '0';
            end if;
        
        end loop;        
    
    end process LEN_LSHIFT;
        
        
    -- Final result.
    ua_narrow_wrap_gt_width <= '0' when (curr_axlen_unsigned_lshift < C_AXI_DATA_WIDTH_BYTES_UNSIGNED) 
                                   else '1';
                                   

    ---------------------------------------------------------------------------


    
    -- v1.03a
    
    -- For narrow burst transfer, provides the number of bytes per address
    
    -- XST does not support divisors that are not constants AND powers of two.
    -- Create process to create a fixed value for divisor.

    -- Replace this statement:
    --     bytes_per_addr <= C_AXI_DATA_WIDTH_BYTES / (2**(to_integer (curr_axsize_unsigned)));

    
    -- With this new process:
    -- Replace case statement with unsigned signal comparator.

    DIV_AXSIZE: process (curr_axsize)
    begin
    
        case (curr_axsize) is
            when "000" =>   bytes_per_addr <= C_AXI_DATA_WIDTH_BYTES / 1;
            when "001" =>   bytes_per_addr <= C_AXI_DATA_WIDTH_BYTES / 2;
            when "010" =>   bytes_per_addr <= C_AXI_DATA_WIDTH_BYTES / 4;
            when "011" =>   bytes_per_addr <= C_AXI_DATA_WIDTH_BYTES / 8;
            when "100" =>   bytes_per_addr <= C_AXI_DATA_WIDTH_BYTES / 16;
            when "101" =>   bytes_per_addr <= C_AXI_DATA_WIDTH_BYTES / 32;
            when "110" =>   bytes_per_addr <= C_AXI_DATA_WIDTH_BYTES / 64;
            when "111" =>   bytes_per_addr <= C_AXI_DATA_WIDTH_BYTES / 128;     -- Max SIZE for 1024-bit AXI bus
            when others => bytes_per_addr <= C_AXI_DATA_WIDTH_BYTES;
        end case;
    
    end process DIV_AXSIZE;

    
    
    -- Original statement.
    -- XST does not support divisors that are not constants AND powers of two.
    -- Insert process to perform (size_plus_lsb / size_bytes_int) function in generation of ua_narrow_load.
    --
    --      size_bytes_int <= (2**(to_integer (curr_axsize_unsigned)));
    --
    --      ua_narrow_load <= std_logic_vector (to_unsigned (bytes_per_addr - 
    --                                                       (size_plus_lsb / size_bytes_int), C_NARROW_BURST_CNT_LEN));


    
    -- AxSIZE + LSB of address
    -- Use all LSB address bit lanes for the narrow transfer based on C_S_AXI_DATA_WIDTH
    size_plus_lsb <= (2**(to_integer (curr_axsize_unsigned))) + 
                     to_integer (unsigned (curr_axaddr_lsb (C_AXI_DATA_WIDTH_BYTES_LOG2-1 downto 0)));
    

    -- Process to keep synthesis with divide by constants that are a power of 2.    
    DIV_SIZE_BYTES: process (size_plus_lsb, 
                             curr_axsize)
    begin
               
        -- Use unsigned w/ curr_axsize signal
        case (curr_axsize) is
        
            when "000" =>   narrow_addr_offset <= size_plus_lsb / 1;
            when "001" =>   narrow_addr_offset <= size_plus_lsb / 2;
            when "010" =>   narrow_addr_offset <= size_plus_lsb / 4;
            when "011" =>   narrow_addr_offset <= size_plus_lsb / 8;           
            when "100" =>   narrow_addr_offset <= size_plus_lsb / 16;
            when "101" =>   narrow_addr_offset <= size_plus_lsb / 32;
            when "110" =>   narrow_addr_offset <= size_plus_lsb / 64;
            when "111" =>   narrow_addr_offset <= size_plus_lsb / 128;     -- Max SIZE for 1024-bit AXI bus
            when others =>  narrow_addr_offset <= size_plus_lsb;
        end case;
    
    end process DIV_SIZE_BYTES;
    
    
    -- Final new statement.    
    -- Passing in simulation and XST.
    ua_narrow_load <= std_logic_vector (to_unsigned (bytes_per_addr - 
                                                     narrow_addr_offset, C_NARROW_BURST_CNT_LEN)) 
                      when (bytes_per_addr >= narrow_addr_offset) 
                      else std_logic_vector (to_unsigned (0, C_NARROW_BURST_CNT_LEN));
                      

   

    ---------------------------------------------------------------------------



end architecture implementation;










-------------------------------------------------------------------------------
-- wrap_brst.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
-------------------------------------------------------------------------------
-- Filename:        wrap_brst.vhd
--
-- Description:     Create sub module for logic to generate WRAP burst
--                  address for rd_chnl and wr_chnl.
--
-- VHDL-Standard:   VHDL'93
--
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- correct_one_bit.vhd
--
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/2/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
-- JLJ      2/4/2011       v1.03a
-- ~~~~~~
--  Edit for scalability and support of 512 and 1024-bit data widths.
--  Add axi_bram_ctrl_funcs package inclusion.
-- ^^^^^^
-- JLJ      2/7/2011       v1.03a
-- ~~~~~~
--  Remove axi_bram_ctrl_funcs package use.
-- ^^^^^^
-- JLJ      3/15/2011       v1.03a
-- ~~~~~~
--  Update multiply function on signal, wrap_burst_total_cmb, 
--  for timing path improvements.  Replace with left shift operation.
-- ^^^^^^
-- JLJ      3/17/2011      v1.03a
-- ~~~~~~
--  Add comments as noted in Spyglass runs. And general code clean-up.
-- ^^^^^^
-- JLJ      3/24/2011      v1.03a
-- ~~~~~~
--  Add specific generate blocks based on C_AXI_DATA_WIDTH to calculate
--  total WRAP burst size for improved FPGA resource utilization.
-- ^^^^^^
-- JLJ      3/30/2011      v1.03a
-- ~~~~~~
--  Clean up code.
--  Re-code wrap_burst_total_cmb process blocks for each data width
--  to improve and catch all false conditions in code coverage analysis.
-- ^^^^^^
--
--
--
--
-------------------------------------------------------------------------------

-- Library declarations

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.axi_bram_ctrl_funcs.all;


------------------------------------------------------------------------------

entity wrap_brst is
generic (


    C_AXI_ADDR_WIDTH : integer := 32;
        -- Width of AXI address bus (in bits)

    C_BRAM_ADDR_ADJUST_FACTOR : integer := 32;
        -- Adjust BRAM address width based on C_AXI_DATA_WIDTH

    C_AXI_DATA_WIDTH : integer := 32
        -- Width of AXI data bus (in bits)
      
    );
  port (


    S_AXI_AClk                  : in    std_logic;
    S_AXI_AResetn               : in    std_logic;


    curr_axlen                  : in    std_logic_vector(7 downto 0) := (others => '0');
    curr_axsize                 : in    std_logic_vector(2 downto 0) := (others => '0');

    curr_narrow_burst           : in    std_logic;
    narrow_bram_addr_inc_re     : in    std_logic;
    bram_addr_ld_en             : in    std_logic;
    bram_addr_ld                : in    std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)
                                        := (others => '0');
    bram_addr_int               : in    std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)
                                        := (others => '0');

    bram_addr_ld_wrap           : out   std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)
                                        := (others => '0');
    
    max_wrap_burst_mod          : out   std_logic := '0'   


    );


end entity wrap_brst;


-------------------------------------------------------------------------------

architecture implementation of wrap_brst is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";

-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

-- Reset active level (common through core)
constant C_RESET_ACTIVE     : std_logic := '0';


-- AXI Size Constants
constant C_AXI_SIZE_1BYTE       : std_logic_vector (2 downto 0) := "000";   -- 1 byte
constant C_AXI_SIZE_2BYTE       : std_logic_vector (2 downto 0) := "001";   -- 2 bytes
constant C_AXI_SIZE_4BYTE       : std_logic_vector (2 downto 0) := "010";   -- 4 bytes = max size for 32-bit BRAM
constant C_AXI_SIZE_8BYTE       : std_logic_vector (2 downto 0) := "011";   -- 8 bytes = max size for 64-bit BRAM
constant C_AXI_SIZE_16BYTE      : std_logic_vector (2 downto 0) := "100";   -- 16 bytes = max size for 128-bit BRAM
constant C_AXI_SIZE_32BYTE      : std_logic_vector (2 downto 0) := "101";   -- 32 bytes = max size for 256-bit BRAM
constant C_AXI_SIZE_64BYTE      : std_logic_vector (2 downto 0) := "110";   -- 64 bytes = max size for 512-bit BRAM
constant C_AXI_SIZE_128BYTE     : std_logic_vector (2 downto 0) := "111";   -- 128 bytes = max size for 1024-bit BRAM


-- Determine the number of bytes based on the AXI data width.
constant C_AXI_DATA_WIDTH_BYTES     : integer := C_AXI_DATA_WIDTH/8;
constant C_AXI_DATA_WIDTH_BYTES_LOG2     : integer := log2(C_AXI_DATA_WIDTH_BYTES);

-- 8d = size of AxLEN vector
constant C_MAX_LSHIFT_SIZE  : integer := C_AXI_DATA_WIDTH_BYTES_LOG2 + 8;

-- Constants for WRAP size decoding to simplify integer represenation.
constant C_WRAP_SIZE_2      : std_logic_vector (2 downto 0) := "001";
constant C_WRAP_SIZE_4      : std_logic_vector (2 downto 0) := "010";
constant C_WRAP_SIZE_8      : std_logic_vector (2 downto 0) := "011";
constant C_WRAP_SIZE_16     : std_logic_vector (2 downto 0) := "100";



-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------

signal max_wrap_burst           : std_logic := '0';

signal save_init_bram_addr_ld       : std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR+1)
                                        := (others => '0');

-- signal curr_axsize_unsigned     : unsigned (2 downto 0) := (others => '0');
-- signal curr_axsize_int          : integer := 0;
-- signal curr_axlen_unsigned      : unsigned (7 downto 0) := (others => '0');

-- Holds burst length/size total (based on width of BRAM width)
-- Max size = max length of burst (256 beats)
-- signal wrap_burst_total_cmb     : integer range 0 to 256 := 1;      -- Max 256 (= 32768d / 128 bytes)
-- signal wrap_burst_total         : integer range 0 to 256 := 1;

signal wrap_burst_total_cmb     : std_logic_vector (2 downto 0) := (others => '0');
signal wrap_burst_total         : std_logic_vector (2 downto 0) := (others => '0');

-- signal curr_axlen_unsigned_plus1          : unsigned (7 downto 0) := (others => '0');
-- signal curr_axlen_unsigned_plus1_lshift   : unsigned (C_MAX_LSHIFT_SIZE downto 0) := (others => '0');  -- Max = 32768d


-------------------------------------------------------------------------------
-- Architecture Body
-------------------------------------------------------------------------------


begin 


        ---------------------------------------------------------------------------


        -- Modify counter size based on size of current write burst operation
        -- For WRAP burst types, the counter value will roll over when the burst
        -- boundary is reached.

        -- Based on AxSIZE and AxLEN
        -- To minimize muxing on initial load of counter value
        -- Detect on WRAP burst types, when the max address is reached.
        -- When the max address is reached, re-load counter with lower
        -- address value.

        -- Save initial load address value.

        REG_INIT_BRAM_ADDR: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    save_init_bram_addr_ld <= (others => '0');
                    
                elsif (bram_addr_ld_en = '1') then 
                    save_init_bram_addr_ld <= bram_addr_ld(C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR+1);
                else
                    save_init_bram_addr_ld <= save_init_bram_addr_ld;
                end if;

            end if;
        end process REG_INIT_BRAM_ADDR;


        ---------------------------------------------------------------------------



        -- v1.03a
        
        -- Calculate AXI size (integer)
        --  curr_axsize_unsigned <= unsigned (curr_axsize);
        --  curr_axsize_int <= to_integer (curr_axsize_unsigned);

        -- Calculate AXI length (integer)
        --  curr_axlen_unsigned <= unsigned (curr_axlen);
        --  curr_axlen_unsigned_plus1 <= curr_axlen_unsigned + "00000001";
        

        -- WRAP = size * length (based on BRAM data width in bytes)
        --
        -- Original multiply function:
        -- wrap_burst_total_cmb <= (size_bytes_int * len_int) / C_AXI_DATA_WIDTH_BYTES;


        -- For XST, modify integer multiply function to improve timing.  
        -- Replace multiply of AxLEN * AxSIZE with a left shift function.
        --  LEN_LSHIFT: process (curr_axlen_unsigned_plus1, curr_axsize_int)
        --  begin
        --  
        --      for i in C_MAX_LSHIFT_SIZE downto 0 loop
        --      
        --          if (i >= curr_axsize_int + 8) then
        --              curr_axlen_unsigned_plus1_lshift (i) <= '0';
        --          elsif (i >= curr_axsize_int) then
        --              curr_axlen_unsigned_plus1_lshift (i) <= curr_axlen_unsigned_plus1 (i - curr_axsize_int);
        --          else
        --              curr_axlen_unsigned_plus1_lshift (i) <= '0';
        --          end if;
        --      
        --      end loop;        
        --  
        --  end process LEN_LSHIFT;


        -- Final signal assignment for XST & timing improvements.
        --  wrap_burst_total_cmb <= to_integer (curr_axlen_unsigned_plus1_lshift) / C_AXI_DATA_WIDTH_BYTES;



        ---------------------------------------------------------------------------



        -- v1.03a
        
        -- For best FPGA resource implementation, hard code the generation of
        -- WRAP burst size based on each C_AXI_DATA_WIDTH possibility.

                
        ---------------------------------------------------------------------------
        -- Generate:    GEN_32_WRAP_SIZE
        -- Purpose:     These wrap size values only apply to 32-bit BRAM.
        ---------------------------------------------------------------------------

        GEN_32_WRAP_SIZE: if C_AXI_DATA_WIDTH = 32 generate
        begin
        
            WRAP_SIZE_CMB: process (curr_axlen, curr_axsize)
            begin
            
            
                -- v1.03a
                -- Attempt to re code this to improve conditional coverage checks.
                -- Use case statment to replace if/else with no priority enabled.
                
                -- Current size of transaction
                case (curr_axsize (2 downto 0)) is
                    
                    -- 4 bytes (full AXI size)
                    when C_AXI_SIZE_4BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0001" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "0011" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_16;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                
                    -- 2 bytes (1/2 AXI size)
                    when C_AXI_SIZE_2BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0011" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;

                    -- 1 byte (1/4 AXI size)
                    when C_AXI_SIZE_1BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                
                    when others =>  wrap_burst_total_cmb <= (others => '0');
            
                end case;
                
                
                
                -- v1.03 Original HDL
                --     
                --     
                --     if ((curr_axlen (3 downto 0) = "0001") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_4BYTE)) or
                --        ((curr_axlen (3 downto 0) = "0011") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_2BYTE)) or
                --        ((curr_axlen (3 downto 0) = "0111") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_1BYTE)) then   
                --     
                --         wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                --      
                --     elsif ((curr_axlen (3 downto 0) = "0011") and 
                --            (curr_axsize (2 downto 0) = C_AXI_SIZE_4BYTE)) or
                --           ((curr_axlen (3 downto 0) = "0111") and 
                --            (curr_axsize (2 downto 0) = C_AXI_SIZE_2BYTE)) or
                --           ((curr_axlen (3 downto 0) = "1111") and 
                --            (curr_axsize (2 downto 0) = C_AXI_SIZE_1BYTE)) then
                --            
                --         wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                --     
                --     elsif ((curr_axlen (3 downto 0) = "0111") and 
                --            (curr_axsize (2 downto 0) = C_AXI_SIZE_4BYTE)) or
                --           ((curr_axlen (3 downto 0) = "1111") and 
                --            (curr_axsize (2 downto 0) = C_AXI_SIZE_2BYTE)) then
                --     
                --         wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                --     
                --     elsif ((curr_axlen (3 downto 0) = "1111") and 
                --            (curr_axsize (2 downto 0) = C_AXI_SIZE_4BYTE)) then
                --                 
                --         wrap_burst_total_cmb <= C_WRAP_SIZE_16;
                --     
                --     else                
                --         wrap_burst_total_cmb <= (others => '0');
                --     end if;                    
                            
                            
            end process WRAP_SIZE_CMB;
                
        end generate GEN_32_WRAP_SIZE;
        


                
        ---------------------------------------------------------------------------
        -- Generate:    GEN_64_WRAP_SIZE
        -- Purpose:     These wrap size values only apply to 64-bit BRAM.
        ---------------------------------------------------------------------------

        GEN_64_WRAP_SIZE: if C_AXI_DATA_WIDTH = 64 generate
        begin
        
            WRAP_SIZE_CMB: process (curr_axlen, curr_axsize)
            begin
            

                -- v1.03a
                -- Attempt to re code this to improve conditional coverage checks.
                -- Use case statment to replace if/else with no priority enabled.
                
                -- Current size of transaction
                case (curr_axsize (2 downto 0)) is

                    -- 8 bytes (full AXI size)
                    when C_AXI_SIZE_8BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0001" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "0011" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_16;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                    
                    -- 4 bytes (1/2 AXI size)
                    when C_AXI_SIZE_4BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0011" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                
                    -- 2 bytes (1/4 AXI size)
                    when C_AXI_SIZE_2BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;

                    -- 1 byte (1/8 AXI size)
                    when C_AXI_SIZE_1BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                
                    when others =>  wrap_burst_total_cmb <= (others => '0');
            
                end case;
                


                -- v1.03 Original HDL
                --    
                --    
                --    if ((curr_axlen (3 downto 0) = "0001") and 
                --        (curr_axsize (2 downto 0) = C_AXI_SIZE_8BYTE)) or
                --       ((curr_axlen (3 downto 0) = "0011") and 
                --        (curr_axsize (2 downto 0) = C_AXI_SIZE_4BYTE)) or
                --       ((curr_axlen (3 downto 0) = "0111") and 
                --        (curr_axsize (2 downto 0) = C_AXI_SIZE_2BYTE)) or
                --       ((curr_axlen (3 downto 0) = "1111") and 
                --        (curr_axsize (2 downto 0) = C_AXI_SIZE_1BYTE)) then
                --    
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                --     
                --    elsif ((curr_axlen (3 downto 0) = "0011") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_8BYTE)) or
                --          ((curr_axlen (3 downto 0) = "0111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_4BYTE)) or
                --          ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_2BYTE)) then
                --          
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                --    
                --    elsif ((curr_axlen (3 downto 0) = "0111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_8BYTE)) or
                --          ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_4BYTE)) then
                --    
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                --    
                --    elsif ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_8BYTE)) then
                --                
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_16;
                --    
                --    else                
                --        wrap_burst_total_cmb <= (others => '0');
                --    end if;                    
                
                
                            
            end process WRAP_SIZE_CMB;
                
        end generate GEN_64_WRAP_SIZE;
        


                
        ---------------------------------------------------------------------------
        -- Generate:    GEN_128_WRAP_SIZE
        -- Purpose:     These wrap size values only apply to 128-bit BRAM.
        ---------------------------------------------------------------------------

        GEN_128_WRAP_SIZE: if C_AXI_DATA_WIDTH = 128 generate
        begin
        
            WRAP_SIZE_CMB: process (curr_axlen, curr_axsize)
            begin
            

                -- v1.03a
                -- Attempt to re code this to improve conditional coverage checks.
                -- Use case statment to replace if/else with no priority enabled.
                
                -- Current size of transaction
                case (curr_axsize (2 downto 0)) is

                    -- 16 bytes (full AXI size)
                    when C_AXI_SIZE_16BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0001" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "0011" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_16;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                    
                    -- 8 bytes (1/2 AXI size)
                    when C_AXI_SIZE_8BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0011" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                
                    -- 4 bytes (1/4 AXI size)
                    when C_AXI_SIZE_4BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;

                    -- 2 bytes (1/8 AXI size)
                    when C_AXI_SIZE_2BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                
                    when others =>  wrap_burst_total_cmb <= (others => '0');
            
                end case;
                


                -- v1.03 Original HDL
                --    
                --     if ((curr_axlen (3 downto 0) = "0001") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_16BYTE)) or
                --        ((curr_axlen (3 downto 0) = "0011") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_8BYTE)) or
                --        ((curr_axlen (3 downto 0) = "0111") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_4BYTE)) or
                --        ((curr_axlen (3 downto 0) = "1111") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_2BYTE)) then 
                --    
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                --     
                --    elsif ((curr_axlen (3 downto 0) = "0011") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_16BYTE)) or
                --          ((curr_axlen (3 downto 0) = "0111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_8BYTE)) or
                --          ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_4BYTE)) then
                --          
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                --    
                --    elsif ((curr_axlen (3 downto 0) = "0111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_16BYTE)) or
                --          ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_8BYTE)) then
                --    
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                --    
                --    elsif ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_16BYTE)) then
                --                
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_16;
                --    
                --    else                
                --        wrap_burst_total_cmb <= (others => '0');
                --    end if;                    
                            
                            
                            
            end process WRAP_SIZE_CMB;
                
        end generate GEN_128_WRAP_SIZE;
        


                
        ---------------------------------------------------------------------------
        -- Generate:    GEN_256_WRAP_SIZE
        -- Purpose:     These wrap size values only apply to 256-bit BRAM.
        ---------------------------------------------------------------------------

        GEN_256_WRAP_SIZE: if C_AXI_DATA_WIDTH = 256 generate
        begin
        
            WRAP_SIZE_CMB: process (curr_axlen, curr_axsize)
            begin
            

                -- v1.03a
                -- Attempt to re code this to improve conditional coverage checks.
                -- Use case statment to replace if/else with no priority enabled.
                
                -- Current size of transaction
                case (curr_axsize (2 downto 0)) is

                    -- 32 bytes (full AXI size)
                    when C_AXI_SIZE_32BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0001" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "0011" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_16;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                    
                    -- 16 bytes (1/2 AXI size)
                    when C_AXI_SIZE_16BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0011" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                
                    -- 8 bytes (1/4 AXI size)
                    when C_AXI_SIZE_8BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;

                    -- 4 bytes (1/8 AXI size)
                    when C_AXI_SIZE_4BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                
                    when others =>  wrap_burst_total_cmb <= (others => '0');
            
                end case;
                


                -- v1.03 Original HDL
                --    
                --     if ((curr_axlen (3 downto 0) = "0001") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_32BYTE)) or
                --        ((curr_axlen (3 downto 0) = "0011") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_16BYTE)) or
                --        ((curr_axlen (3 downto 0) = "0111") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_8BYTE)) or
                --        ((curr_axlen (3 downto 0) = "1111") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_4BYTE)) then   
                --    
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                --     
                --    elsif ((curr_axlen (3 downto 0) = "0011") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_32BYTE)) or
                --          ((curr_axlen (3 downto 0) = "0111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_16BYTE)) or
                --          ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_8BYTE)) then
                --           
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                --    
                --    elsif ((curr_axlen (3 downto 0) = "0111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_32BYTE)) or
                --          ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_16BYTE)) then
                --    
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                --    
                --    elsif ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_32BYTE)) then
                --                
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_16;
                --    
                --    else                
                --        wrap_burst_total_cmb <= (others => '0');
                --    end if;   
                
                
                            
            end process WRAP_SIZE_CMB;
                
        end generate GEN_256_WRAP_SIZE;
        


                
        ---------------------------------------------------------------------------
        -- Generate:    GEN_512_WRAP_SIZE
        -- Purpose:     These wrap size values only apply to 512-bit BRAM.
        ---------------------------------------------------------------------------

        GEN_512_WRAP_SIZE: if C_AXI_DATA_WIDTH = 512 generate
        begin
        
            WRAP_SIZE_CMB: process (curr_axlen, curr_axsize)
            begin
            

                -- v1.03a
                -- Attempt to re code this to improve conditional coverage checks.
                -- Use case statment to replace if/else with no priority enabled.
                
                -- Current size of transaction
                case (curr_axsize (2 downto 0)) is

                    -- 64 bytes (full AXI size)
                    when C_AXI_SIZE_64BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0001" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "0011" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_16;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                    
                    -- 32 bytes (1/2 AXI size)
                    when C_AXI_SIZE_32BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0011" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                
                    -- 16 bytes (1/4 AXI size)
                    when C_AXI_SIZE_16BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;

                    -- 8 bytes (1/8 AXI size)
                    when C_AXI_SIZE_8BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                
                    when others =>  wrap_burst_total_cmb <= (others => '0');
            
                end case;
                


                -- v1.03 Original HDL
                --    
                --    
                --     if ((curr_axlen (3 downto 0) = "0001") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_64BYTE)) or
                --        ((curr_axlen (3 downto 0) = "0011") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_32BYTE)) or
                --        ((curr_axlen (3 downto 0) = "0111") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_16BYTE)) or
                --        ((curr_axlen (3 downto 0) = "1111") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_8BYTE)) then   
                --    
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                --     
                --    elsif ((curr_axlen (3 downto 0) = "0011") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_64BYTE)) or
                --          ((curr_axlen (3 downto 0) = "0111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_32BYTE)) or
                --          ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_16BYTE)) then
                --           
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                --    
                --    elsif ((curr_axlen (3 downto 0) = "0111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_64BYTE)) or
                --          ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_32BYTE)) then
                --    
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                --    
                --    elsif ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_64BYTE)) then
                --                
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_16;
                --    
                --    else                
                --        wrap_burst_total_cmb <= (others => '0');
                --    end if;                    
                
                            
            end process WRAP_SIZE_CMB;
                
        end generate GEN_512_WRAP_SIZE;
        


                
        ---------------------------------------------------------------------------
        -- Generate:    GEN_1024_WRAP_SIZE
        -- Purpose:     These wrap size values only apply to 1024-bit BRAM.
        ---------------------------------------------------------------------------

        GEN_1024_WRAP_SIZE: if C_AXI_DATA_WIDTH = 1024 generate
        begin
        
            WRAP_SIZE_CMB: process (curr_axlen, curr_axsize)
            begin
            

                -- v1.03a
                -- Attempt to re code this to improve conditional coverage checks.
                -- Use case statment to replace if/else with no priority enabled.
                
                -- Current size of transaction
                case (curr_axsize (2 downto 0)) is

                    -- 128 bytes (full AXI size)
                    when C_AXI_SIZE_128BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0001" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "0011" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_16;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                    
                    -- 64 bytes (1/2 AXI size)
                    when C_AXI_SIZE_64BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0011" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                
                    -- 32 bytes (1/4 AXI size)
                    when C_AXI_SIZE_32BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "0111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;

                    -- 16 bytes (1/8 AXI size)
                    when C_AXI_SIZE_16BYTE =>
            
                        case (curr_axlen (3 downto 0)) is 
                            when "1111" =>  wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                            when others =>  wrap_burst_total_cmb <= (others => '0');
                        end case;
                
                    when others =>  wrap_burst_total_cmb <= (others => '0');
            
                end case;
                


                -- v1.03 Original HDL
                --    
                --    
                --     if ((curr_axlen (3 downto 0) = "0001") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_128BYTE)) or
                --        ((curr_axlen (3 downto 0) = "0011") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_64BYTE)) or
                --        ((curr_axlen (3 downto 0) = "0111") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_32BYTE)) or
                --        ((curr_axlen (3 downto 0) = "1111") and 
                --         (curr_axsize (2 downto 0) = C_AXI_SIZE_16BYTE)) then   
                --    
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_2;
                --     
                --    elsif ((curr_axlen (3 downto 0) = "0011") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_128BYTE)) or
                --          ((curr_axlen (3 downto 0) = "0111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_64BYTE)) or
                --          ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_32BYTE)) then
                --           
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_4;
                --    
                --    elsif ((curr_axlen (3 downto 0) = "0111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_128BYTE)) or
                --          ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_64BYTE)) then
                --    
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_8;
                --    
                --    elsif ((curr_axlen (3 downto 0) = "1111") and 
                --           (curr_axsize (2 downto 0) = C_AXI_SIZE_128BYTE)) then
                --                
                --        wrap_burst_total_cmb <= C_WRAP_SIZE_16;
                --    
                --    else                
                --        wrap_burst_total_cmb <= (others => '0');
                --    end if;                    
                            
                            
            end process WRAP_SIZE_CMB;
                
        end generate GEN_1024_WRAP_SIZE;
        
        
        

        ---------------------------------------------------------------------------



        -- Early decode to determine size of WRAP transfer
        -- Goal to break up long timing path to generate max_wrap_burst signal.
        
        REG_WRAP_TOTAL: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    wrap_burst_total <= (others => '0');

                elsif (bram_addr_ld_en = '1') then
                    wrap_burst_total <= wrap_burst_total_cmb;
                else
                    wrap_burst_total <= wrap_burst_total;
                end if;
            end if;

        end process REG_WRAP_TOTAL;


        ---------------------------------------------------------------------------


        CHECK_WRAP_MAX : process ( wrap_burst_total,                                   
                                   bram_addr_int,
                                   save_init_bram_addr_ld )
        begin

           
            -- Check BRAM address value if max value is reached.
            -- Max value is based on burst size/length for operation.
            -- Address bits to check vary based on C_S_AXI_DATA_WIDTH and burst size/length.
            -- (use signal, wrap_burst_total, based on current WRAP burst size/length/data width).

            case wrap_burst_total is
            
            when C_WRAP_SIZE_2 => 
                if (bram_addr_int (C_BRAM_ADDR_ADJUST_FACTOR) = '1') then
                    max_wrap_burst <= '1';
                else
                    max_wrap_burst <= '0';
                end if;

                -- Use saved BRAM load value
                bram_addr_ld_wrap (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR+1) <= 
                    save_init_bram_addr_ld (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR+1);
                
                -- Reset lower order address bits to zero (to wrap address)
                bram_addr_ld_wrap (C_BRAM_ADDR_ADJUST_FACTOR) <= '0';
                
            when C_WRAP_SIZE_4 =>     
                if (bram_addr_int (C_BRAM_ADDR_ADJUST_FACTOR + 1 downto C_BRAM_ADDR_ADJUST_FACTOR) = "11") then
                    max_wrap_burst <= '1';
                else
                    max_wrap_burst <= '0';
                end if;

                -- Use saved BRAM load value
                bram_addr_ld_wrap (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR+2) <= 
                    save_init_bram_addr_ld (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR+2);
                
                -- Reset lower order address bits to zero (to wrap address)
                bram_addr_ld_wrap (C_BRAM_ADDR_ADJUST_FACTOR + 1 downto C_BRAM_ADDR_ADJUST_FACTOR ) <= "00";

                
            when C_WRAP_SIZE_8 =>     
                if (bram_addr_int (C_BRAM_ADDR_ADJUST_FACTOR + 2 downto C_BRAM_ADDR_ADJUST_FACTOR) = "111") then
                    max_wrap_burst <= '1';
                else
                    max_wrap_burst <= '0';
                end if;

                -- Use saved BRAM load value
                bram_addr_ld_wrap (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR+3) <= 
                    save_init_bram_addr_ld (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR+3);
                    
                -- Reset lower order address bits to zero (to wrap address)
                bram_addr_ld_wrap (C_BRAM_ADDR_ADJUST_FACTOR + 2 downto C_BRAM_ADDR_ADJUST_FACTOR ) <= "000";
                
            when C_WRAP_SIZE_16 =>     
                if (bram_addr_int (C_BRAM_ADDR_ADJUST_FACTOR + 3 downto C_BRAM_ADDR_ADJUST_FACTOR) = "1111") then
                    max_wrap_burst <= '1';
                else
                    max_wrap_burst <= '0';
                end if;

                -- Use saved BRAM load value
                bram_addr_ld_wrap (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR+4) <= 
                    save_init_bram_addr_ld (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR+4);
                    
                -- Reset lower order address bits to zero (to wrap address)
                bram_addr_ld_wrap (C_BRAM_ADDR_ADJUST_FACTOR + 3 downto C_BRAM_ADDR_ADJUST_FACTOR ) <= "0000";

            when others => 
                max_wrap_burst <= '0';
                bram_addr_ld_wrap(C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR+1) <= save_init_bram_addr_ld;
                -- Reset lower order address bits to zero (to wrap address)
                bram_addr_ld_wrap (C_BRAM_ADDR_ADJUST_FACTOR) <= '0';             
            end case;

            

        end process CHECK_WRAP_MAX;


        ---------------------------------------------------------------------------


        -- Move outside of CHECK_WRAP_MAX process.
        -- Account for narrow burst operations.
        --
        -- Currently max_wrap_burst is getting asserted at the first address beat to BRAM
        -- that indicates the maximum WRAP burst boundary.  Must wait for the completion of the
        -- narrow wrap burst counter to assert max_wrap_burst.
        --
        -- Indicates when narrow burst address counter hits max (all zeros value)          
        -- narrow_bram_addr_inc_re
        
        max_wrap_burst_mod <= max_wrap_burst when (curr_narrow_burst = '0') else
                              (max_wrap_burst and narrow_bram_addr_inc_re);


        ---------------------------------------------------------------------------



end architecture implementation;










-------------------------------------------------------------------------------
-- rd_chnl.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
-------------------------------------------------------------------------------
-- Filename:        rd_chnl.vhd
--
-- Description:     This file is the top level module for the AXI BRAM
--                  controller read channel interfaces.  Controls all
--                  handshaking and data flow on the AXI read address (AR)
--                  and read data (R) channels.
--
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- correct_one_bit.vhd
--
--
-------------------------------------------------------------------------------
--
-- History:
-- 
-- JLJ      2/2/2011       v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Minor code cleanup.
--  Remove library version # dependency.  Replace with work library.
-- ^^^^^^
-- JLJ      2/3/2011       v1.03a
-- ~~~~~~
--  Edits for scalability and support of 512 and 1024-bit data widths.
-- ^^^^^^
-- JLJ      2/14/2011      v1.03a
-- ~~~~~~
--  Initial integration of Hsiao ECC algorithm.
--  Add C_ECC_TYPE top level parameter.
--  Similar edits as wr_chnl on Hsiao ECC code.
-- ^^^^^^
-- JLJ      2/18/2011      v1.03a
-- ~~~~~~
--  Update for usage of ecc_gen.vhd module directly from MIG.
--  Clean-up XST warnings.
-- ^^^^^^
-- JLJ      2/22/2011      v1.03a
-- ~~~~~~
--  Found issue with ECC decoding on read path.  Remove MSB '0' usage 
--  in syndrome calculation, since h_matrix is based on 32 + 7 = 39 bits.
--  Modify read data signal used in single bit error correction.
-- ^^^^^^
-- JLJ      2/23/2011      v1.03a
-- ~~~~~~
--  Move all MIG functions to package body.
-- ^^^^^^
-- JLJ      3/2/2011        v1.03a
-- ~~~~~~
--  Fix XST handling for DIV functions.  Create seperate process when
--  divisor is not constant and a power of two.
-- ^^^^^^
-- JLJ      3/15/2011        v1.03a
-- ~~~~~~
--  Clean-up unused signal, narrow_addr_inc.
-- ^^^^^^
-- JLJ      3/17/2011      v1.03a
-- ~~~~~~
--  Add comments as noted in Spyglass runs. And general code clean-up.
-- ^^^^^^
-- JLJ      4/21/2011      v1.03a
-- ~~~~~~
--  Code clean up.
--  Add defaults to araddr_pipe_sel & axi_arready_int when in single port mode.
--  Remove use of IF_IS_AXI4 constant.
-- ^^^^^^
-- JLJ      4/22/2011         v1.03a
-- ~~~~~~
--  Code clean up.
-- ^^^^^^
-- JLJ      5/6/2011      v1.03a
-- ~~~~~~
--  Remove usage of C_FAMILY.  
--  Hard code C_USE_LUT6 constant.
-- ^^^^^^
-- JLJ      5/26/2011      v1.03a
-- ~~~~~~
--  With CR # 609695, update else clause for narrow_burst_cnt_ld to 
--  remove simulation warnings when axi_byte_div_curr_arsize = zero.
-- ^^^^^^
--
--
--
-------------------------------------------------------------------------------

-- Library declarations

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.wrap_brst;
use work.ua_narrow;
use work.checkbit_handler;
use work.checkbit_handler_64;
use work.correct_one_bit;
use work.correct_one_bit_64;
use work.ecc_gen;
use work.parity;
use work.axi_bram_ctrl_funcs.all;


 ------------------------------------------------------------------------------


entity rd_chnl is
generic (


    --  C_FAMILY : string := "virtex6";
        -- Specify the target architecture type

    C_AXI_ADDR_WIDTH    : integer := 32;
      -- Width of AXI address bus (in bits)
      
    C_BRAM_ADDR_ADJUST_FACTOR   : integer := 2;
      -- Adjust factor to BRAM address width based on data width (in bits)
    
    C_AXI_DATA_WIDTH  : integer := 32;
      -- Width of AXI data bus (in bits)
      
    C_AXI_ID_WIDTH : integer := 4;
        --  AXI ID vector width

    C_S_AXI_SUPPORTS_NARROW : integer := 1;
        -- Support for narrow burst operations

    C_S_AXI_PROTOCOL : string := "AXI4";
        -- Set to "AXI4LITE" to optimize out burst transaction support

    C_SINGLE_PORT_BRAM : integer := 0;
        -- Enable single port usage of BRAM

    C_ECC : integer := 0;
        -- Enables or disables ECC functionality
        
    C_ECC_WIDTH : integer := 8;
        -- Width of ECC data vector

    C_ECC_TYPE : integer := 0          -- v1.03a 
        -- ECC algorithm format, 0 = Hamming code, 1 = Hsiao code

    );
  port (


    -- AXI Global Signals
    S_AXI_AClk              : in    std_logic;
    S_AXI_AResetn           : in    std_logic;          


    -- AXI Read Address Channel Signals (AR)
    AXI_ARID                : in    std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
    AXI_ARADDR              : in    std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0);
    
    AXI_ARLEN               : in    std_logic_vector(7 downto 0);
        -- Specifies the number of data transfers in the burst
        -- "0000 0000"  1 data transfer
        -- "0000 0001"  2 data transfers
        -- ...
        -- "1111 1111" 256 data transfers
      
    AXI_ARSIZE              : in    std_logic_vector(2 downto 0);
        -- Specifies the max number of data bytes to transfer in each data beat
        -- "000"    1 byte to transfer
        -- "001"    2 bytes to transfer
        -- "010"    3 bytes to transfer
        -- ...
      
    AXI_ARBURST             : in    std_logic_vector(1 downto 0);
        -- Specifies burst type
        -- "00" FIXED = Fixed burst address (handled as INCR)
        -- "01" INCR = Increment burst address
        -- "10" WRAP = Incrementing address burst that wraps to lower order address at boundary
        -- "11" Reserved (not checked)
    
    AXI_ARLOCK              : in    std_logic;                                  
    AXI_ARCACHE             : in    std_logic_vector(3 downto 0);
    AXI_ARPROT              : in    std_logic_vector(2 downto 0);

    AXI_ARVALID             : in    std_logic;
    AXI_ARREADY             : out   std_logic;
    

    -- AXI Read Data Channel Signals (R)
    AXI_RID                 : out   std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
    AXI_RDATA               : out   std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0);
    AXI_RRESP               : out   std_logic_vector(1 downto 0);
    AXI_RLAST               : out   std_logic;

    AXI_RVALID              : out   std_logic;
    AXI_RREADY              : in    std_logic;
    

    -- ECC Register Interface Signals
    Enable_ECC              : in    std_logic;
    BRAM_Addr_En            : out   std_logic;
    CE_Failing_We           : out   std_logic := '0'; 
    Sl_CE                   : out   std_logic := '0'; 
    Sl_UE                   : out   std_logic := '0'; 
    

    -- Single Port Arbitration Signals
    Arb2AR_Active               : in   std_logic;
    AR2Arb_Active_Clr           : out  std_logic := '0';

    Sng_BRAM_Addr_Ld_En         : out   std_logic := '0';
    Sng_BRAM_Addr_Ld            : out   std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) := (others => '0');
    Sng_BRAM_Addr_Inc           : out   std_logic := '0';
    Sng_BRAM_Addr               : in    std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR);

    
    -- BRAM Read Port Interface Signals
    BRAM_En                 : out   std_logic;
    BRAM_Addr               : out   std_logic_vector (C_AXI_ADDR_WIDTH-1 downto 0);
    BRAM_RdData             : in    std_logic_vector (C_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0)
       
    

    );



end entity rd_chnl;


-------------------------------------------------------------------------------

architecture implementation of rd_chnl is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";


-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------

-- All functions defined in axi_bram_ctrl_funcs package.



-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

-- Reset active level (common through core)
constant C_RESET_ACTIVE     : std_logic := '0';

constant RESP_OKAY      : std_logic_vector (1 downto 0) := "00";    -- Normal access OK response
constant RESP_SLVERR    : std_logic_vector (1 downto 0) := "10";    -- Slave error
-- For future support.      constant RESP_EXOKAY    : std_logic_vector (1 downto 0) := "01";    -- Exclusive access OK response
-- For future support.      constant RESP_DECERR    : std_logic_vector (1 downto 0) := "11";    -- Decode error

-- Set constants for ARLEN equal to a count of one or two beats.
constant AXI_ARLEN_ONE  : std_logic_vector(7 downto 0) := (others => '0');
constant AXI_ARLEN_TWO  : std_logic_vector(7 downto 0) := "00000001";


-- Modify C_BRAM_ADDR_SIZE to be adjusted for BRAM data width
-- When BRAM data width = 32 bits, BRAM_Addr (1:0) = "00"
-- When BRAM data width = 64 bits, BRAM_Addr (2:0) = "000"
-- When BRAM data width = 128 bits, BRAM_Addr (3:0) = "0000"
-- When BRAM data width = 256 bits, BRAM_Addr (4:0) = "00000"
-- Move to full_axi module
-- constant C_BRAM_ADDR_ADJUST_FACTOR : integer := log2 (C_AXI_DATA_WIDTH/8);
-- Not used
-- constant C_BRAM_ADDR_ADJUST : integer := C_AXI_ADDR_WIDTH - C_BRAM_ADDR_ADJUST_FACTOR;


-- Determine maximum size for narrow burst length counter
-- When C_AXI_DATA_WIDTH = 32, minimum narrow width burst is 8 bits
--              resulting in a count 3 downto 0 => so minimum counter width = 2 bits.
-- When C_AXI_DATA_WIDTH = 256, minimum narrow width burst is 8 bits
--              resulting in a count 31 downto 0 => so minimum counter width = 5 bits.

constant C_NARROW_BURST_CNT_LEN : integer := log2 (C_AXI_DATA_WIDTH/8);
constant NARROW_CNT_MAX     : std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0) := (others => '0');


-- Max length burst count AXI4 specification
constant C_MAX_BRST_CNT         : integer := 256;
constant C_BRST_CNT_SIZE        : integer := log2 (C_MAX_BRST_CNT);

-- When the burst count = 0
constant C_BRST_CNT_ZERO    : std_logic_vector(C_BRST_CNT_SIZE-1 downto 0) := (others => '0');

-- Burst count = 1
constant C_BRST_CNT_ONE     : std_logic_vector(7 downto 0) := "00000001";

-- Burst count = 2
constant C_BRST_CNT_TWO     : std_logic_vector(7 downto 0) := "00000010";          


-- Read data mux select constants (for signal rddata_mux_sel)
    -- '0' selects BRAM
    -- '1' selects read skid buffer
constant C_RDDATA_MUX_BRAM          : std_logic := '0';
constant C_RDDATA_MUX_SKID_BUF      : std_logic := '1';   


-- Determine the number of bytes based on the AXI data width.
constant C_AXI_DATA_WIDTH_BYTES     : integer := C_AXI_DATA_WIDTH/8;


-- AXI Burst Types
-- AXI Spec 4.4
constant C_AXI_BURST_WRAP       : std_logic_vector (1 downto 0) := "10";  
constant C_AXI_BURST_INCR       : std_logic_vector (1 downto 0) := "01";  
constant C_AXI_BURST_FIXED      : std_logic_vector (1 downto 0) := "00";  


-- AXI Size Constants
--      constant C_AXI_SIZE_1BYTE       : std_logic_vector (2 downto 0) := "000";   -- 1 byte
--      constant C_AXI_SIZE_2BYTE       : std_logic_vector (2 downto 0) := "001";   -- 2 bytes
--      constant C_AXI_SIZE_4BYTE       : std_logic_vector (2 downto 0) := "010";   -- 4 bytes = max size for 32-bit BRAM
--      constant C_AXI_SIZE_8BYTE       : std_logic_vector (2 downto 0) := "011";   -- 8 bytes = max size for 64-bit BRAM
--      constant C_AXI_SIZE_16BYTE      : std_logic_vector (2 downto 0) := "100";   -- 16 bytes = max size for 128-bit BRAM
--      constant C_AXI_SIZE_32BYTE      : std_logic_vector (2 downto 0) := "101";   -- 32 bytes = max size for 256-bit BRAM
--      constant C_AXI_SIZE_64BYTE      : std_logic_vector (2 downto 0) := "110";   -- 64 bytes = max size for 512-bit BRAM
--      constant C_AXI_SIZE_128BYTE     : std_logic_vector (2 downto 0) := "111";   -- 128 bytes = max size for 1024-bit BRAM


-- Determine max value of ARSIZE based on the AXI data width.
-- Use function in axi_bram_ctrl_funcs package.
constant C_AXI_SIZE_MAX         : std_logic_vector (2 downto 0) := Create_Size_Max (C_AXI_DATA_WIDTH);

-- Internal ECC data width size.
constant C_INT_ECC_WIDTH : integer := Int_ECC_Size (C_AXI_DATA_WIDTH);

-- For use with ECC functions (to use LUT6 components or let synthesis infer the optimal implementation).
-- constant C_USE_LUT6 : boolean := Family_To_LUT_Size (String_To_Family (C_FAMILY,false)) = 6;
-- Remove usage of C_FAMILY.
-- All architectures supporting AXI will support a LUT6. 
-- Hard code this internal constant used in ECC algorithm.
constant C_USE_LUT6 : boolean := TRUE;



-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------



-------------------------------------------------------------------------------
-- AXI Read Address Channel Signals
-------------------------------------------------------------------------------


-- State machine type declarations
type RD_ADDR_SM_TYPE is ( IDLE,
                          LD_ARADDR
                        );
                    
signal rd_addr_sm_cs, rd_addr_sm_ns : RD_ADDR_SM_TYPE;

signal ar_active_set            : std_logic := '0';
signal ar_active_set_i          : std_logic := '0';
signal ar_active_clr            : std_logic := '0';
signal ar_active                : std_logic := '0';
signal ar_active_d1             : std_logic := '0';
signal ar_active_re             : std_logic := '0';


signal axi_araddr_pipe          : std_logic_vector (C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');

signal curr_araddr_lsb          : std_logic_vector (C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0) := (others => '0');
signal araddr_pipe_ld           : std_logic := '0';
signal araddr_pipe_ld_i         : std_logic := '0';
signal araddr_pipe_sel          : std_logic := '0';
    -- '0' indicates mux select from AXI
    -- '1' indicates mux select from AR Addr Register
signal axi_araddr_full          : std_logic := '0';

signal axi_arready_int          : std_logic := '0';
signal axi_early_arready_int    : std_logic := '0';


signal axi_aresetn_d1           : std_logic := '0';
signal axi_aresetn_d2           : std_logic := '0';
signal axi_aresetn_re           : std_logic := '0';
signal axi_aresetn_re_reg       : std_logic := '0';


signal no_ar_ack_cmb        : std_logic := '0';
signal no_ar_ack            : std_logic := '0';

signal pend_rd_op_cmb       : std_logic := '0';
signal pend_rd_op           : std_logic := '0';


signal axi_arid_pipe            : std_logic_vector (C_AXI_ID_WIDTH-1 downto 0) := (others => '0');

signal axi_arsize_pipe          : std_logic_vector (2 downto 0) := (others => '0');
signal axi_arsize_pipe_4byte    : std_logic := '0';
signal axi_arsize_pipe_8byte    : std_logic := '0';
signal axi_arsize_pipe_16byte   : std_logic := '0';
signal axi_arsize_pipe_32byte   : std_logic := '0';

-- v1.03a
signal axi_arsize_pipe_max      : std_logic := '0';


signal curr_arsize              : std_logic_vector (2 downto 0) := (others => '0');
signal curr_arsize_reg          : std_logic_vector (2 downto 0) := (others => '0');



signal axi_arlen_pipe           : std_logic_vector(7 downto 0) := (others => '0');
signal axi_arlen_pipe_1_or_2    : std_logic := '0';           

signal curr_arlen               : std_logic_vector(7 downto 0) := (others => '0');
signal curr_arlen_reg           : std_logic_vector(7 downto 0) := (others => '0');

signal axi_arburst_pipe         : std_logic_vector(1 downto 0) := (others => '0');
signal axi_arburst_pipe_fixed   : std_logic := '0';            

signal curr_arburst             : std_logic_vector(1 downto 0) := (others => '0');
signal curr_wrap_burst          : std_logic := '0';
signal curr_wrap_burst_reg      : std_logic := '0';
signal max_wrap_burst           : std_logic := '0';

signal curr_incr_burst          : std_logic := '0';

signal curr_fixed_burst         : std_logic := '0';
signal curr_fixed_burst_reg     : std_logic := '0';




-- BRAM Address Counter    
signal bram_addr_ld_en          : std_logic := '0';
signal bram_addr_ld_en_i        : std_logic := '0';
signal bram_addr_ld_en_mod      : std_logic := '0';

signal bram_addr_ld             : std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)
                                    := (others => '0');
signal bram_addr_ld_wrap        : std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)
                                    := (others => '0');

signal bram_addr_inc                : std_logic := '0';
signal bram_addr_inc_mod            : std_logic := '0';
signal bram_addr_inc_wrap_mod       : std_logic := '0';         



-------------------------------------------------------------------------------
-- AXI Read Data Channel Signals
-------------------------------------------------------------------------------


-- State machine type declarations
type RD_DATA_SM_TYPE is ( IDLE,
                          SNG_ADDR,
                          SEC_ADDR,
                          FULL_PIPE,
                          FULL_THROTTLE,
                          LAST_ADDR,
                          LAST_THROTTLE,
                          LAST_DATA,
                          LAST_DATA_AR_PEND
                        );
                    
signal rd_data_sm_cs, rd_data_sm_ns : RD_DATA_SM_TYPE;

signal rd_adv_buf               : std_logic := '0';
signal axi_rd_burst             : std_logic := '0';
signal axi_rd_burst_two         : std_logic := '0';

signal act_rd_burst             : std_logic := '0';
signal act_rd_burst_set         : std_logic := '0';
signal act_rd_burst_clr         : std_logic := '0';
signal act_rd_burst_two         : std_logic := '0';

-- Rd Data Buffer/Register
signal rd_skid_buf_ld_cmb       : std_logic := '0';
signal rd_skid_buf_ld_reg       : std_logic := '0';
signal rd_skid_buf_ld           : std_logic := '0';
signal rd_skid_buf_ld_imm       : std_logic := '0';
signal rd_skid_buf              : std_logic_vector (C_AXI_DATA_WIDTH-1 downto 0) := (others => '0');

signal rddata_mux_sel_cmb   : std_logic := '0';
signal rddata_mux_sel       : std_logic := '0';

signal axi_rdata_en         : std_logic := '0';
signal axi_rdata_mux        : std_logic_vector (C_AXI_DATA_WIDTH+8*C_ECC-1 downto 0) := (others => '0');



-- Read Burst Counter
signal brst_cnt_max         : std_logic := '0';
signal brst_cnt_max_d1      : std_logic := '0';
signal brst_cnt_max_re      : std_logic := '0';

signal end_brst_rd_clr_cmb  : std_logic := '0';
signal end_brst_rd_clr      : std_logic := '0';
signal end_brst_rd          : std_logic := '0';

signal brst_zero            : std_logic := '0';
signal brst_one             : std_logic := '0';


signal brst_cnt_ld          : std_logic_vector (C_BRST_CNT_SIZE-1 downto 0) := (others => '0');
signal brst_cnt_rst         : std_logic := '0';
signal brst_cnt_ld_en       : std_logic := '0';
signal brst_cnt_ld_en_i     : std_logic := '0';
signal brst_cnt_dec         : std_logic := '0';
signal brst_cnt             : std_logic_vector (C_BRST_CNT_SIZE-1 downto 0) := (others => '0');



-- AXI Read Response Signals
signal axi_rid_temp         : std_logic_vector (C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal axi_rid_temp_full    : std_logic := '0';
signal axi_rid_temp_full_d1 : std_logic := '0';
signal axi_rid_temp_full_fe : std_logic := '0';


signal axi_rid_temp2        : std_logic_vector (C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal axi_rid_temp2_full   : std_logic := '0';

signal axi_b2b_rid_adv      : std_logic := '0';     
signal axi_rid_int          : std_logic_vector (C_AXI_ID_WIDTH-1 downto 0) := (others => '0');

signal axi_rresp_int        : std_logic_vector (1 downto 0) := (others => '0');

signal axi_rvalid_clr_ok    : std_logic := '0';     
signal axi_rvalid_set_cmb   : std_logic := '0';
signal axi_rvalid_set       : std_logic := '0';
signal axi_rvalid_int       : std_logic := '0';

signal axi_rlast_int        : std_logic := '0';
signal axi_rlast_set        : std_logic := '0';
    

-- Internal BRAM Signals
signal bram_en_cmb          : std_logic := '0';
signal bram_en_int          : std_logic := '0';

signal bram_addr_int        : std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)
                                := (others => '0');



-- Narrow Burst Signals
signal curr_narrow_burst_cmb    : std_logic := '0';
signal curr_narrow_burst        : std_logic := '0';
signal narrow_burst_cnt_ld      : std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0) := (others => '0');
signal narrow_burst_cnt_ld_reg  : std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0) := (others => '0');
signal narrow_burst_cnt_ld_mod  : std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0) := (others => '0');


signal narrow_addr_rst          : std_logic := '0';       
signal narrow_addr_ld_en        : std_logic := '0';
signal narrow_addr_dec          : std_logic := '0';


signal narrow_bram_addr_inc         : std_logic := '0';
signal narrow_bram_addr_inc_d1      : std_logic := '0';
signal narrow_bram_addr_inc_re      : std_logic := '0';

signal narrow_addr_int              : std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0) := (others => '0');

signal curr_ua_narrow_wrap          : std_logic := '0';
signal curr_ua_narrow_incr          : std_logic := '0';
signal ua_narrow_load               : std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0) := (others => '0');




-- State machine type declarations
type RLAST_SM_TYPE is ( IDLE,
                        W8_THROTTLE,
                        W8_2ND_LAST_DATA,
                        W8_LAST_DATA,
                        -- W8_LAST_DATA_B2,
                        W8_THROTTLE_B2
                        );
                    
signal rlast_sm_cs, rlast_sm_ns : RLAST_SM_TYPE;

signal last_bram_addr               : std_logic := '0';
signal set_last_bram_addr           : std_logic := '0';

signal alast_bram_addr              : std_logic := '0';

signal rd_b2b_elgible               : std_logic := '0';
signal rd_b2b_elgible_no_thr_check  : std_logic := '0';
signal throttle_last_data           : std_logic := '0';

signal disable_b2b_brst_cmb         : std_logic := '0';
signal disable_b2b_brst             : std_logic := '0';

signal axi_b2b_brst_cmb             : std_logic := '0';
signal axi_b2b_brst                 : std_logic := '0';

signal do_cmplt_burst_cmb           : std_logic := '0';
signal do_cmplt_burst               : std_logic := '0';
signal do_cmplt_burst_clr           : std_logic := '0';


-------------------------------------------------------------------------------
-- ECC Signals
-------------------------------------------------------------------------------

signal UnCorrectedRdData    : std_logic_vector (0 to C_AXI_DATA_WIDTH-1) := (others => '0');

-- Move vector from core ECC module to use in AXI RDATA register output
signal Syndrome             : std_logic_vector(0 to C_INT_ECC_WIDTH-1) := (others => '0');     -- Specific to BRAM data width
signal Syndrome_4           : std_logic_vector (0 to 1) := (others => '0');                     -- Only used in 32-bit ECC
signal Syndrome_6           : std_logic_vector (0 to 5) := (others => '0');                     -- Specific to ECC @ 32-bit data width
signal Syndrome_7           : std_logic_vector (0 to 11) := (others => '0');                    -- Specific to ECC @ 64-bit data width

signal syndrome_reg         : std_logic_vector(0 to C_INT_ECC_WIDTH-1) := (others => '0');     -- Specific to BRAM data width
signal syndrome_reg_i       : std_logic_vector(0 to C_INT_ECC_WIDTH-1) := (others => '0');     -- Specific to BRAM data width

signal Sl_UE_i              : std_logic := '0';
signal UE_Q                 : std_logic := '0';

-- v1.03a
-- Hsiao ECC
signal syndrome_r   : std_logic_vector (C_INT_ECC_WIDTH - 1 downto 0) := (others => '0');

constant CODE_WIDTH : integer := C_AXI_DATA_WIDTH + C_INT_ECC_WIDTH;
constant ECC_WIDTH  : integer := C_INT_ECC_WIDTH;

signal h_rows       : std_logic_vector (CODE_WIDTH * ECC_WIDTH - 1 downto 0);



-------------------------------------------------------------------------------
-- Architecture Body
-------------------------------------------------------------------------------


begin 





    ---------------------------------------------------------------------------
    -- AXI Read Address Channel Output Signals
    ---------------------------------------------------------------------------



    ---------------------------------------------------------------------------
    -- Generate:    GEN_ARREADY_DUAL
    -- Purpose:     Generate AXI_ARREADY when in dual port mode.
    ---------------------------------------------------------------------------
    GEN_ARREADY_DUAL: if C_SINGLE_PORT_BRAM = 0 generate
    begin

        -- Ensure ARREADY only gets asserted early when acknowledge recognized
        -- on AXI read data channel.
        AXI_ARREADY <= axi_arready_int or (axi_early_arready_int and rd_adv_buf);

    end generate GEN_ARREADY_DUAL;
    
    

    ---------------------------------------------------------------------------
    -- Generate:    GEN_ARREADY_SNG
    -- Purpose:     Generate AXI_ARREADY when in single port mode.
    ---------------------------------------------------------------------------
    GEN_ARREADY_SNG: if C_SINGLE_PORT_BRAM = 1 generate
    begin

        -- ARREADY generated by sng_port_arb module
        AXI_ARREADY <= '0';
        axi_arready_int <= '0';
        
    end generate GEN_ARREADY_SNG;
    
   

    

    ---------------------------------------------------------------------------
    -- AXI Read Data Channel Output Signals
    ---------------------------------------------------------------------------

    -- UE flag is detected is same clock cycle that read data is presented on 
    -- the AXI bus.  Must drive SLVERR combinatorially to align with corrupted 
    -- detected data word.
    AXI_RRESP <= RESP_SLVERR when (C_ECC = 1 and Sl_UE_i = '1') else axi_rresp_int;
    AXI_RVALID <= axi_rvalid_int;

    AXI_RID <= axi_rid_int;             
    AXI_RLAST <= axi_rlast_int;




    ---------------------------------------------------------------------------
    --
    -- *** AXI Read Address Channel Interface ***
    --
    ---------------------------------------------------------------------------



    ---------------------------------------------------------------------------
    -- Generate:    GEN_AR_PIPE_SNG
    -- Purpose:     Only generate pipeline registers when in dual port BRAM mode.
    ---------------------------------------------------------------------------

    GEN_AR_PIPE_SNG: if C_SINGLE_PORT_BRAM = 1 generate
    begin
    
        -- Unused AW pipeline (set default values)
        araddr_pipe_ld <= '0';
        axi_araddr_pipe <= AXI_ARADDR;
        axi_arid_pipe <= AXI_ARID;
        axi_arsize_pipe <= AXI_ARSIZE;
        axi_arlen_pipe <= AXI_ARLEN;
        axi_arburst_pipe <= AXI_ARBURST;
        axi_arlen_pipe_1_or_2 <= '0';
        axi_arburst_pipe_fixed <= '0';
        axi_araddr_full <= '0';
            
    end generate GEN_AR_PIPE_SNG;






    ---------------------------------------------------------------------------
    -- Generate:    GEN_AR_PIPE_DUAL
    -- Purpose:     Only generate pipeline registers when in dual port BRAM mode.
    ---------------------------------------------------------------------------

    GEN_AR_PIPE_DUAL: if C_SINGLE_PORT_BRAM = 0 generate
    begin

        -----------------------------------------------------------------------
        -- AXI Read Address Buffer/Register
        -- (mimic behavior of address pipeline for AXI_ARID)
        -----------------------------------------------------------------------

        GEN_ARADDR: for i in C_AXI_ADDR_WIDTH-1 downto 0 generate
        begin

            REG_ARADDR: process (S_AXI_AClk)
            begin

                if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                    -- No reset condition to save resources/timing

                    if (araddr_pipe_ld = '1') then
                        axi_araddr_pipe (i) <= AXI_ARADDR (i);
                    else
                        axi_araddr_pipe (i) <= axi_araddr_pipe (i);

                    end if;
                end if;
            end process REG_ARADDR;

        end generate GEN_ARADDR;

    
        -------------------------------------------------------------------
        -- Register ARID
        -- No reset condition to save resources/timing
        -------------------------------------------------------------------

        REG_ARID: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (araddr_pipe_ld = '1') then
                    axi_arid_pipe <= AXI_ARID;
                else
                    axi_arid_pipe <= axi_arid_pipe;

                end if;
            end if;
        end process REG_ARID;



        ---------------------------------------------------------------------------

        -- In parallel to ARADDR pipeline and ARID
        -- Use same control signals to capture AXI_ARSIZE, AXI_ARLEN & AXI_ARBURST.

        -- Register AXI_ARSIZE, AXI_ARLEN & AXI_ARBURST
        -- No reset condition to save resources/timing

        REG_ARCTRL: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (araddr_pipe_ld = '1') then
                    axi_arsize_pipe <= AXI_ARSIZE;
                    axi_arlen_pipe <= AXI_ARLEN;
                    axi_arburst_pipe <= AXI_ARBURST;
                else
                    axi_arsize_pipe <= axi_arsize_pipe;
                    axi_arlen_pipe <= axi_arlen_pipe;
                    axi_arburst_pipe <= axi_arburst_pipe;

                end if;

            end if;

        end process REG_ARCTRL;


        ---------------------------------------------------------------------------


        -- Create signals that indicate value of AXI_ARLEN in pipeline stage
        -- Used to decode length of burst when BRAM address can be loaded early
        -- when pipeline is full.
        --
        -- Add early decode of ARBURST in pipeline.
        -- Copy logic from WR_CHNL module (similar logic).
        -- Add early decode of ARSIZE = 4 bytes in pipeline.


        REG_ARLEN_PIPE: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                -- No reset condition to save resources/timing

                if (araddr_pipe_ld = '1') then

                    -- Create merge to decode ARLEN of ONE or TWO
                    if (AXI_ARLEN = AXI_ARLEN_ONE) or (AXI_ARLEN = AXI_ARLEN_TWO) then
                        axi_arlen_pipe_1_or_2 <= '1';
                    else
                        axi_arlen_pipe_1_or_2 <= '0';
                    end if;


                    -- Early decode on value in pipeline of ARBURST
                    if (AXI_ARBURST = C_AXI_BURST_FIXED) then
                        axi_arburst_pipe_fixed <= '1';                
                    else
                        axi_arburst_pipe_fixed <= '0';
                    end if;

                else

                    axi_arlen_pipe_1_or_2 <= axi_arlen_pipe_1_or_2;
                    axi_arburst_pipe_fixed <= axi_arburst_pipe_fixed;

                end if;

            end if;

        end process REG_ARLEN_PIPE;



        ---------------------------------------------------------------------------

        -- Create full flag for ARADDR pipeline
        -- Set when read address register is loaded.
        -- Cleared when read address stored in register is loaded into BRAM
        -- address counter.

        REG_RDADDR_FULL: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   -- (bram_addr_ld_en = '1' and araddr_pipe_sel = '1') then

                   (bram_addr_ld_en = '1' and araddr_pipe_sel = '1' and araddr_pipe_ld = '0') then
                    axi_araddr_full <= '0';

                elsif (araddr_pipe_ld = '1') then
                    axi_araddr_full <= '1';
                else
                    axi_araddr_full <= axi_araddr_full;
                end if;
            end if;

        end process REG_RDADDR_FULL;


        ---------------------------------------------------------------------------

    end generate GEN_AR_PIPE_DUAL;



    ---------------------------------------------------------------------------

    -- v1.03a
    -- Add early decode of ARSIZE = max size in pipeline based on AXI data
    -- bus width (use constant, C_AXI_SIZE_MAX)

    REG_ARSIZE_PIPE: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                axi_arsize_pipe_max <= '0';

            elsif (araddr_pipe_ld = '1') then

                -- Early decode of ARSIZE in pipeline equal to max # of bytes
                -- based on AXI data bus width
                if (AXI_ARSIZE = C_AXI_SIZE_MAX) then                   
                    axi_arsize_pipe_max <= '1';
                else
                    axi_arsize_pipe_max <= '0';
                end if;                

            else
                axi_arsize_pipe_max <= axi_arsize_pipe_max;
            end if;
        end if;

    end process REG_ARSIZE_PIPE;


   




    ---------------------------------------------------------------------------
    -- Generate:    GE_ARREADY
    -- Purpose:     ARREADY is only created here when in dual port BRAM mode.
    ---------------------------------------------------------------------------
    GEN_ARREADY: if (C_SINGLE_PORT_BRAM = 0) generate
    begin


        ----------------------------------------------------------------------------
        --  AXI_ARREADY Output Register
        --  Description:    Keep AXI_ARREADY output asserted until ARADDR pipeline
        --                  is full.  When a full condition is reached, negate
        --                  ARREADY as another AR address can not be accepted.
        --                  Add condition to keep ARReady asserted if loading current
        ---                 ARADDR pipeline value into the BRAM address counter.
        --                  Indicated by assertion of bram_addr_ld_en & araddr_pipe_sel.
        --
        ----------------------------------------------------------------------------

        REG_ARREADY: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    axi_arready_int <= '0';

                -- Detect end of S_AXI_AResetn to assert AWREADY and accept 
                -- new AWADDR values
                elsif (axi_aresetn_re_reg = '1') or 

                      -- Add condition for early ARREADY to keep pipeline full
                      (bram_addr_ld_en = '1' and araddr_pipe_sel = '1' and axi_early_arready_int = '0') then            
                    axi_arready_int <= '1';

                -- Add conditional check if ARREADY is asserted (with ARVALID) (one clock cycle later) 
                -- when the address pipeline is full.
                elsif (araddr_pipe_ld = '1') or 
                      (AXI_ARVALID = '1' and axi_arready_int = '1' and axi_araddr_full = '1') then

                    axi_arready_int <= '0';
                else
                    axi_arready_int <= axi_arready_int;
                end if;
            end if;

        end process REG_ARREADY;


        ----------------------------------------------------------------------------


        REG_EARLY_ARREADY: process (S_AXI_AClk)
        begin
            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    axi_early_arready_int <= '0';

                -- Pending ARADDR and ARREADY is not yet asserted to accept
                -- operation (due to ARADDR being full)
                elsif (AXI_ARVALID = '1' and axi_arready_int = '0' and 
                       axi_araddr_full = '1') and
                      (alast_bram_addr = '1') and

                      -- Add check for elgible back-to-back BRAM load
                      (rd_b2b_elgible = '1') then 

                    axi_early_arready_int <= '1';

                else
                    axi_early_arready_int <= '0';
                end if;
            end if;

        end process REG_EARLY_ARREADY;


        ---------------------------------------------------------------------------

        -- Need to detect end of reset cycle to assert ARREADY on AXI bus
        REG_ARESETN: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                axi_aresetn_d1 <= S_AXI_AResetn;
                axi_aresetn_d2 <= axi_aresetn_d1;
                axi_aresetn_re_reg <= axi_aresetn_re;
            end if;

        end process REG_ARESETN;


        -- Create combinatorial RE detect of S_AXI_AResetn
        axi_aresetn_re <= '1' when (S_AXI_AResetn = '1' and axi_aresetn_d1 = '0') else '0';

        ----------------------------------------------------------------------------


    end generate GEN_ARREADY;

   
   

    ---------------------------------------------------------------------------
    -- Generate:    GEN_DUAL_ADDR_CNT
    -- Purpose:     Instantiate BRAM address counter unique for wr_chnl logic
    --              only when controller configured in dual port mode.
    ---------------------------------------------------------------------------
    GEN_DUAL_ADDR_CNT: if (C_SINGLE_PORT_BRAM = 0) generate
    begin

        
        ---------------------------------------------------------------------------
        
        -- Replace I_ADDR_CNT module usage of pf_counter in proc_common library.
        -- Only need to use lower 12-bits of address due to max AXI burst size
        -- Since AXI guarantees bursts do not cross 4KB boundary, the counting part 
        -- of I_ADDR_CNT can be reduced to max 4KB. 
        --
        -- No reset on bram_addr_int.
        -- Increment ONLY.

        REG_ADDR_CNT: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                if (bram_addr_ld_en_mod = '1') then
                    bram_addr_int <= bram_addr_ld;

                elsif (bram_addr_inc_mod = '1') then
                    bram_addr_int (C_AXI_ADDR_WIDTH-1 downto 12) <= 
                            bram_addr_int (C_AXI_ADDR_WIDTH-1 downto 12);
                    bram_addr_int (11 downto C_BRAM_ADDR_ADJUST_FACTOR) <= 
                            std_logic_vector (unsigned (bram_addr_int (11 downto C_BRAM_ADDR_ADJUST_FACTOR)) + 1);

                end if;
            end if;

        end process REG_ADDR_CNT;

        ---------------------------------------------------------------------------

        -- Set defaults to shared address counter
        -- Only used in single port configurations
        Sng_BRAM_Addr_Ld_En <= '0';
        Sng_BRAM_Addr_Ld <= (others => '0');
        Sng_BRAM_Addr_Inc <= '0';
        

    end generate GEN_DUAL_ADDR_CNT;




    ---------------------------------------------------------------------------
    -- Generate:    GEN_SNG_ADDR_CNT
    -- Purpose:     When configured in single port BRAM mode, address counter
    --              is shared with rd_chnl module.  Assign output signals here
    --              to counter instantiation at full_axi module level.
    ---------------------------------------------------------------------------
    GEN_SNG_ADDR_CNT: if (C_SINGLE_PORT_BRAM = 1) generate
    begin
    
        Sng_BRAM_Addr_Ld_En <= bram_addr_ld_en_mod;
        Sng_BRAM_Addr_Ld <= bram_addr_ld;
        Sng_BRAM_Addr_Inc <= bram_addr_inc_mod;
        bram_addr_int <= Sng_BRAM_Addr; 

    end generate GEN_SNG_ADDR_CNT;


    ---------------------------------------------------------------------------

    -- BRAM address load mux.
    -- Either load BRAM counter directly from AXI bus or from stored registered value    
    -- Use registered signal to indicate current operation is a WRAP burst
    --
    -- Match bram_addr_ld to what asserts bram_addr_ld_en_mod
    -- Include bram_addr_inc_mod when asserted to use bram_addr_ld_wrap value
    -- (otherwise use pipelined or AXI bus value to load BRAM address counter)

    bram_addr_ld <= bram_addr_ld_wrap when (max_wrap_burst = '1' and 
                                            curr_wrap_burst_reg = '1' and 
                                            bram_addr_inc_wrap_mod = '1') else

                    axi_araddr_pipe (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) 
                        when (araddr_pipe_sel = '1') else 

                    AXI_ARADDR (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR);

    ---------------------------------------------------------------------------


    -- On wrap burst max loads (simultaneous BRAM address increment is asserted).
    -- Ensure that load has higher priority over increment.
    -- Use registered signal to indicate current operation is a WRAP burst

    bram_addr_ld_en_mod <= '1' when (bram_addr_ld_en = '1' or 
                                     (max_wrap_burst = '1' and 
                                      curr_wrap_burst_reg = '1' and 
                                      bram_addr_inc_wrap_mod = '1'))
                            else '0';


    -- Create a special bram_addr_inc_mod for use in the bram_addr_ld_en_mod signal
    -- logic.  No need for the check if the current operation is NOT a fixed AND a wrap
    -- burst.  The transfer will be one or the other.

    -- Found issue when narrow FIXED length burst is incorrectly 
    -- incrementing BRAM address counter
    bram_addr_inc_wrap_mod <= bram_addr_inc when (curr_narrow_burst = '0') 
                            else narrow_bram_addr_inc_re;


    ----------------------------------------------------------------------------


    -- Narrow bursting
    --
    -- Handle read burst addressing on narrow burst operations
    -- Intercept BRAM address increment flag, bram_addr_inc and only
    -- increment address when the number of BRAM reads match the width of the
    -- AXI data bus.

    -- For a 32-bit BRAM, byte burst will increment the BRAM address 
    --      after four reads from BRAM.
    -- For a 256-bit BRAM, a byte burst will increment the BRAM address 
    --      after 32 reads from BRAM.


    -- Based on current operation being a narrow burst, hold off BRAM
    -- address increment until narrow burst fits BRAM data width.
    -- For non narrow burst operations, use bram_addr_inc from data SM.
    --
    -- Add in check that burst type is not FIXED, curr_fixed_burst_reg

    -- bram_addr_inc_mod <= (bram_addr_inc and not (curr_fixed_burst_reg)) when (curr_narrow_burst = '0') else
    --                      narrow_bram_addr_inc_re;
    --
    --
    -- Replace w/ below generate statements based on supporting narrow transfers or not.
    -- Create generate statement around the signal assignment for bram_addr_inc_mod.
    


    ---------------------------------------------------------------------------
    -- Generate:    GEN_BRAM_INC_MOD_W_NARROW
    -- Purpose:     Assign signal, bram_addr_inc_mod when narrow transfers
    --              are supported in design instantiation.
    ---------------------------------------------------------------------------

    GEN_BRAM_INC_MOD_W_NARROW: if (C_S_AXI_SUPPORTS_NARROW = 1) generate
    begin

        -- Found issue when narrow FIXED length burst is incorrectly incrementing BRAM address counter
        bram_addr_inc_mod <= (bram_addr_inc and not (curr_fixed_burst_reg)) when (curr_narrow_burst = '0') else
                             (narrow_bram_addr_inc_re and not (curr_fixed_burst_reg));

    end generate GEN_BRAM_INC_MOD_W_NARROW;



    ---------------------------------------------------------------------------
    -- Generate:    GEN_WO_NARROW
    -- Purpose:     Assign signal, bram_addr_inc_mod when narrow transfers
    --              are not supported in the design instantiation.
    --              Drive default values for narrow counter and logic when 
    --              narrow operation support is disabled.
    ---------------------------------------------------------------------------

    GEN_WO_NARROW: if (C_S_AXI_SUPPORTS_NARROW = 0) generate
    begin

        -- Found issue when narrow FIXED length burst is incorrectly incrementing BRAM address counter
        bram_addr_inc_mod <= bram_addr_inc and not (curr_fixed_burst_reg);

        narrow_addr_rst <= '0';
        narrow_burst_cnt_ld_mod <= (others => '0');
        narrow_addr_dec <= '0';
        narrow_addr_ld_en <= '0';    
        narrow_bram_addr_inc <= '0';
        narrow_bram_addr_inc_d1 <= '0';
        narrow_bram_addr_inc_re <= '0';
        narrow_addr_int <= (others => '0');        
        curr_narrow_burst <= '0';


    end generate GEN_WO_NARROW;




    ---------------------------------------------------------------------------
    --
    -- Only instantiate NARROW_CNT and supporting logic when narrow transfers
    -- are supported and utilized by masters in the AXI system.
    -- The design parameter, C_S_AXI_SUPPORTS_NARROW will indicate this.
    --
    ---------------------------------------------------------------------------


    ---------------------------------------------------------------------------
    -- Generate:    GEN_NARROW_CNT
    -- Purpose:     Instantiate narrow counter and logic when narrow
    --              operation support is enabled.
    ---------------------------------------------------------------------------

    GEN_NARROW_CNT: if (C_S_AXI_SUPPORTS_NARROW = 1) generate
    begin


        ---------------------------------------------------------------------------
        --
        -- Generate seperate smaller counter for narrow burst operations
        -- Replace I_NARROW_CNT module usage of pf_counter_top from proc_common library.
        --
        -- Counter size is adjusted based on size of data burst.
        --
        -- For example, 32-bit data width BRAM, minimum narrow width 
        -- burst is 8 bits resulting in a count 3 downto 0.  So the
        -- minimum counter width = 2 bits.
        --
        -- When C_AXI_DATA_WIDTH = 256, minimum narrow width burst 
        -- is 8 bits resulting in a count 31 downto 0.  So the
        -- minimum counter width = 5 bits.
        --
        -- Size of counter = C_NARROW_BURST_CNT_LEN
        --
        ---------------------------------------------------------------------------

        REG_NARROW_CNT: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                if (narrow_addr_rst = '1') then
                    narrow_addr_int <= (others => '0');

                -- Load enable
                elsif (narrow_addr_ld_en = '1') then
                    narrow_addr_int <= narrow_burst_cnt_ld_mod;

                -- Decrement ONLY (no increment functionality)
                elsif (narrow_addr_dec = '1') then
                    narrow_addr_int (C_NARROW_BURST_CNT_LEN-1 downto 0) <= 
                            std_logic_vector (unsigned (narrow_addr_int (C_NARROW_BURST_CNT_LEN-1 downto 0)) - 1);

                end if;

            end if;

        end process REG_NARROW_CNT;


        ---------------------------------------------------------------------------


        narrow_addr_rst <= not (S_AXI_AResetn);

        -- Modify narrow burst count load value based on
        -- unalignment of AXI address value

        narrow_burst_cnt_ld_mod <= ua_narrow_load when (curr_ua_narrow_wrap = '1' or curr_ua_narrow_incr = '1') else
                                   narrow_burst_cnt_ld when (bram_addr_ld_en = '1') else
                                   narrow_burst_cnt_ld_reg;

        narrow_addr_dec <= bram_addr_inc when (curr_narrow_burst = '1') else '0';

        narrow_addr_ld_en <= (curr_narrow_burst_cmb and bram_addr_ld_en) or narrow_bram_addr_inc_re;


        narrow_bram_addr_inc <= '1' when (narrow_addr_int = NARROW_CNT_MAX) and 
                                         (curr_narrow_burst = '1') 

                                         -- Ensure that narrow address counter doesn't 
                                         -- flag max or get loaded to
                                         -- reset narrow counter until AXI read data 
                                         -- bus has acknowledged current
                                         -- data on the AXI bus.  Use rd_adv_buf signal 
                                         -- to indicate the non throttle
                                         -- condition on the AXI bus.

                                         and (bram_addr_inc = '1')
                                else '0';

        ----------------------------------------------------------------------------

        -- Detect rising edge of narrow_bram_addr_inc    

        REG_NARROW_BRAM_ADDR_INC: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    narrow_bram_addr_inc_d1 <= '0';
                else
                    narrow_bram_addr_inc_d1 <= narrow_bram_addr_inc;
                end if;

            end if;
        end process REG_NARROW_BRAM_ADDR_INC;

        narrow_bram_addr_inc_re <= '1' when (narrow_bram_addr_inc = '1') and 
                                            (narrow_bram_addr_inc_d1 = '0') 
                                    else '0';

        ---------------------------------------------------------------------------



    end generate GEN_NARROW_CNT;




    ----------------------------------------------------------------------------


    -- Specify current ARSIZE signal 
    -- Address pipeline MUX
    curr_arsize <= axi_arsize_pipe when (araddr_pipe_sel = '1') else AXI_ARSIZE;


    REG_ARSIZE: process (S_AXI_AClk)
    begin
    
        if (S_AXI_AClk'event and S_AXI_AClk = '1') then
    
            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                curr_arsize_reg <= (others => '0');
                
            -- Register curr_arsize when bram_addr_ld_en = '1'
            elsif (bram_addr_ld_en = '1') then
                curr_arsize_reg <= curr_arsize;
                
            else
                curr_arsize_reg <= curr_arsize_reg;
            end if;
    
        end if;
    end process REG_ARSIZE;




    ---------------------------------------------------------------------------
    -- Generate:    GEN_NARROW_EN
    -- Purpose:     Only instantiate logic to determine if current burst
    --              is a narrow burst when narrow bursting logic is supported.
    ---------------------------------------------------------------------------

    GEN_NARROW_EN: if (C_S_AXI_SUPPORTS_NARROW = 1) generate
    begin


        -----------------------------------------------------------------------
        -- Determine "narrow" burst transfers
        -- Compare the ARSIZE to the BRAM data width
        -----------------------------------------------------------------------

        -- v1.03a
        -- Detect if current burst operation is of size /= to the full
        -- AXI data bus width.  If not, then the current operation is a 
        -- "narrow" burst.
        
        curr_narrow_burst_cmb <= '1' when (curr_arsize /= C_AXI_SIZE_MAX) else '0';

        ---------------------------------------------------------------------------


        -- Register flag indicating the current operation
        -- is a narrow read burst
        NARROW_BURST_REG: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                -- Need to reset this flag at end of narrow burst operation
                -- Ensure if curr_narrow_burst got set during previous transaction, axi_rlast_set
                -- doesn't clear the flag (add check for pend_rd_op negated).

                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   (axi_rlast_set = '1' and pend_rd_op = '0' and bram_addr_ld_en = '0') then
                    curr_narrow_burst <= '0';                  

                -- Add check for burst operation using ARLEN value
                -- Ensure that narrow burst flag does not get set during FIXED burst types

                elsif (bram_addr_ld_en = '1') and (curr_arlen /= AXI_ARLEN_ONE) and
                      (curr_fixed_burst = '0') then

                    curr_narrow_burst <= curr_narrow_burst_cmb;
                end if;

            end if;

        end process NARROW_BURST_REG;


    end generate GEN_NARROW_EN;


    ---------------------------------------------------------------------------
    -- Generate:    GEN_NARROW_CNT_LD
    -- Purpose:     Only instantiate logic to determine narrow burst counter
    --              load value when narrow bursts are enabled.
    ---------------------------------------------------------------------------

    GEN_NARROW_CNT_LD: if (C_S_AXI_SUPPORTS_NARROW = 1) generate

    signal curr_arsize_unsigned : unsigned (2 downto 0) := (others => '0');
    signal axi_byte_div_curr_arsize : integer := 1;

    begin


        -- v1.03a
        
        -- Create narrow burst counter load value based on current operation
        -- "narrow" data width (indicated by value of AWSIZE).
        
        curr_arsize_unsigned <= unsigned (curr_arsize);


        -- XST does not support divisors that are not constants and powers of 2.
        -- Create process to create a fixed value for divisor.

        -- Replace this statement:
        --    narrow_burst_cnt_ld <= std_logic_vector (
        --                            to_unsigned (
        --                                   (C_AXI_DATA_WIDTH_BYTES / (2**(to_integer (curr_arsize_unsigned))) ) - 1, 
        --                                    C_NARROW_BURST_CNT_LEN));


        --     -- With this new process and subsequent signal assignment:
        --     DIV_AWSIZE: process (curr_arsize_unsigned)
        --     begin
        --     
        --         case (to_integer (curr_arsize_unsigned)) is
        --             when 0 =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 1;
        --             when 1 =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 2;
        --             when 2 =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 4;
        --             when 3 =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 8;
        --             when 4 =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 16;
        --             when 5 =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 32;
        --             when 6 =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 64;
        --             when 7 =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 128;
        --         --coverage off
        --             when others => axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES;
        --         --coverage on
        --         end case;
        --     
        --     end process DIV_AWSIZE;


        -- w/ CR # 609695


        -- With this new process and subsequent signal assignment:
        DIV_AWSIZE: process (curr_arsize_unsigned)
        begin

            case (curr_arsize_unsigned) is
                when "000" =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 1;
                when "001" =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 2;
                when "010" =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 4;
                when "011" =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 8;
                when "100" =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 16;
                when "101" =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 32;
                when "110" =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 64;
                when "111" =>   axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES / 128;
            --coverage off
                when others => axi_byte_div_curr_arsize <= C_AXI_DATA_WIDTH_BYTES;
            --coverage on
            end case;

        end process DIV_AWSIZE;

        
    
        -- v1.03a
        -- Replace with new signal assignment.
        -- For synthesis to support only divisors that are constant and powers of two.


        -- Updated else clause for simulation warnings w/ CR # 609695

        narrow_burst_cnt_ld <= std_logic_vector (
                                to_unsigned (
                                    (axi_byte_div_curr_arsize) - 1, C_NARROW_BURST_CNT_LEN))
                               when (axi_byte_div_curr_arsize > 0)
                               else std_logic_vector (to_unsigned (0, C_NARROW_BURST_CNT_LEN));



        ---------------------------------------------------------------------------

        -- Register narrow burst count load indicator
        
        REG_NAR_BRST_CNT_LD: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    narrow_burst_cnt_ld_reg <= (others => '0');
                elsif (bram_addr_ld_en = '1') then 
                    narrow_burst_cnt_ld_reg <= narrow_burst_cnt_ld;
                else
                    narrow_burst_cnt_ld_reg <= narrow_burst_cnt_ld_reg;
                end if;

            end if;
        end process REG_NAR_BRST_CNT_LD;

        ---------------------------------------------------------------------------


    end generate GEN_NARROW_CNT_LD;



  
    

    ----------------------------------------------------------------------------

    -- Handling for WRAP burst types
    --
    -- For WRAP burst types, the counter value will roll over when the burst
    -- boundary is reached.
    -- Boundary is reached based on ARSIZE and ARLEN.
    --
    -- Goal is to minimize muxing on initial load of counter value.
    -- On WRAP burst types, detect when the max address is reached.
    -- When the max address is reached, re-load counter with lower
    -- address value set to '0'.
    ----------------------------------------------------------------------------

    -- Detect valid WRAP burst types    
    curr_wrap_burst <= '1' when (curr_arburst = C_AXI_BURST_WRAP) else '0';
    curr_incr_burst <= '1' when (curr_arburst = C_AXI_BURST_INCR) else '0';
    curr_fixed_burst <= '1' when (curr_arburst = C_AXI_BURST_FIXED) else '0';

    ----------------------------------------------------------------------------


    -- Register curr_wrap_burst & curr_fixed_burst signals when BRAM 
    -- address counter is initially loaded

    REG_CURR_BRST: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1') then

            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                curr_wrap_burst_reg <= '0';
                curr_fixed_burst_reg <= '0';

            elsif (bram_addr_ld_en = '1') then 
                curr_wrap_burst_reg <= curr_wrap_burst;
                curr_fixed_burst_reg <= curr_fixed_burst;
            else
                curr_wrap_burst_reg <= curr_wrap_burst_reg;
                curr_fixed_burst_reg <= curr_fixed_burst_reg;
            end if;

        end if;
    end process REG_CURR_BRST;



    ---------------------------------------------------------------------------
    -- Instance: I_WRAP_BRST
    --
    -- Description:
    --
    --      Instantiate WRAP_BRST module
    --      Logic to generate the wrap around value to load into the BRAM address
    --      counter on WRAP burst transactions.
    --      WRAP value is based on current ARLEN, ARSIZE (for narrows) and
    --      data width of BRAM module.
    --
    ---------------------------------------------------------------------------

    I_WRAP_BRST : entity work.wrap_brst
    generic map (

        C_AXI_ADDR_WIDTH                =>  C_AXI_ADDR_WIDTH                ,
        C_BRAM_ADDR_ADJUST_FACTOR       =>  C_BRAM_ADDR_ADJUST_FACTOR       ,
        C_AXI_DATA_WIDTH                =>  C_AXI_DATA_WIDTH              

    )
    port map (

        S_AXI_AClk                  =>  S_AXI_ACLK                  ,
        S_AXI_AResetn               =>  S_AXI_ARESETN               ,   

        curr_axlen                  =>  curr_arlen                  ,
        curr_axsize                 =>  curr_arsize                 ,
        curr_narrow_burst           =>  curr_narrow_burst           ,
        narrow_bram_addr_inc_re     =>  narrow_bram_addr_inc_re     ,
        bram_addr_ld_en             =>  bram_addr_ld_en             ,
        bram_addr_ld                =>  bram_addr_ld                ,
        bram_addr_int               =>  bram_addr_int               ,
        bram_addr_ld_wrap           =>  bram_addr_ld_wrap           ,
        max_wrap_burst_mod          =>  max_wrap_burst     

    );    
    
    


    ----------------------------------------------------------------------------

    -- Specify current ARBURST signal 
    -- Input address pipeline MUX
    curr_arburst <= axi_arburst_pipe when (araddr_pipe_sel = '1') else AXI_ARBURST;

    ----------------------------------------------------------------------------

    -- Specify current AWBURST signal 
    -- Input address pipeline MUX
    curr_arlen <= axi_arlen_pipe when (araddr_pipe_sel = '1') else AXI_ARLEN;

    ----------------------------------------------------------------------------





    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_UA_NARROW
    -- Purpose:     Only instantiate logic for burst narrow WRAP operations when
    --              AXI bus protocol is not set for AXI-LITE and narrow
    --              burst operations are supported.
    --
    ---------------------------------------------------------------------------
    
    GEN_UA_NARROW: if (C_S_AXI_SUPPORTS_NARROW = 1) generate
    begin                           


        ---------------------------------------------------------------------------
        --
        -- New logic to detect unaligned address on a narrow WRAP burst transaction.
        -- If this condition is met, then the narrow burst counter will be
        -- initially loaded with an offset value corresponding to the unalignment
        -- in the ARADDR value.
        --
        --
        -- Create a sub module for all logic to determine the narrow burst counter
        -- offset value on unaligned WRAP burst operations.
        --
        -- Module generates the following signals:
        --
        --      => curr_ua_narrow_wrap, to indicate the current
        --         operation is an unaligned narrow WRAP burst.
        --
        --      => curr_ua_narrow_incr, to load narrow burst counter
        --         for unaligned INCR burst operations.
        --
        --      => ua_narrow_load, narrow counter load value.
        --         Sized, (C_NARROW_BURST_CNT_LEN-1 downto 0)
        --
        ---------------------------------------------------------------------------




        ---------------------------------------------------------------------------
        --
        -- Instance: I_UA_NARROW
        --
        -- Description:
        --
        --      Creates a narrow burst count load value when an operation
        --      is an unaligned narrow WRAP or INCR burst type.  Used by
        --      I_NARROW_CNT module.
        --
        --      Logic is customized for each C_AXI_DATA_WIDTH.
        --
        ---------------------------------------------------------------------------

        I_UA_NARROW : entity work.ua_narrow
        generic map (
            C_AXI_DATA_WIDTH            =>  C_AXI_DATA_WIDTH            ,
            C_BRAM_ADDR_ADJUST_FACTOR   =>  C_BRAM_ADDR_ADJUST_FACTOR   ,
            C_NARROW_BURST_CNT_LEN      =>  C_NARROW_BURST_CNT_LEN
        )
        port map (

            curr_wrap_burst             =>  curr_wrap_burst             ,       -- in
            curr_incr_burst             =>  curr_incr_burst             ,       -- in
            bram_addr_ld_en             =>  bram_addr_ld_en             ,       -- in

            curr_axlen                  =>  curr_arlen                  ,       -- in
            curr_axsize                 =>  curr_arsize                 ,       -- in
            curr_axaddr_lsb             =>  curr_araddr_lsb             ,       -- in
            
            curr_ua_narrow_wrap         =>  curr_ua_narrow_wrap         ,       -- out
            curr_ua_narrow_incr         =>  curr_ua_narrow_incr         ,       -- out
            ua_narrow_load              =>  ua_narrow_load                      -- out

        );    
    
    
           

        -- Use in all C_AXI_DATA_WIDTH generate statements

        -- Only probe least significant BRAM address bits
        -- C_BRAM_ADDR_ADJUST_FACTOR offset down to 0.
        curr_araddr_lsb <= axi_araddr_pipe (C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0) 
                            when (araddr_pipe_sel = '1') else 
                        AXI_ARADDR (C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0);





    end generate GEN_UA_NARROW;




    ----------------------------------------------------------------------------
    --
    -- New logic to detect if pending operation in ARADDR pipeline is
    -- elgible for back-to-back no "bubble" performance. And BRAM address
    -- counter can be loaded upon last BRAM address presented for the current
    -- operation.

    -- This condition exists when the ARADDR pipeline is full and the pending
    -- operation is a burst >= length of two data beats.
    -- And not a FIXED burst type (must be INCR or WRAP type).

    -- The DATA SM handles detecting a throttle condition and will void
    -- the capability to be a back-to-back in performance transaction.
    --
    -- Add check if new operation is a narrow burst (to be loaded into BRAM 
    -- counter)
    -- Add check for throttling condition on after last BRAM address is
    -- presented
    --
    ----------------------------------------------------------------------------

    -- v1.03a
    rd_b2b_elgible_no_thr_check <= '1' when (axi_araddr_full = '1') and
                                            (axi_arlen_pipe_1_or_2 /= '1') and
                                            (axi_arburst_pipe_fixed /= '1') and
                                            (disable_b2b_brst = '0') and
                                            (axi_arsize_pipe_max = '1')
                                        else '0';


    rd_b2b_elgible <= '1' when (rd_b2b_elgible_no_thr_check = '1') and
                               (throttle_last_data = '0')
                        else '0';


    -- Check if SM is in LAST_THROTTLE state which also indicates we are throttling at 
    -- the last data beat in the read burst.  Ensures that the bursts are not implemented
    -- as back-to-back bursts and RVALID will negate upon recognition of RLAST and RID
    -- pipeline will be advanced properly.


    -- Fix timing path on araddr_pipe_sel generated in RDADDR SM
    -- SM uses rd_b2b_elgible signal which checks throttle condition on
    -- last data beat to hold off loading new BRAM address counter for next
    -- back-to-back operation.

    -- Attempt to modify logic in generation of throttle_last_data signal.

    throttle_last_data <= '1' when ((brst_zero = '1') and (rd_adv_buf = '0')) or
                                   (rd_data_sm_cs = LAST_THROTTLE)
                            else '0';


    ----------------------------------------------------------------------------

    

    

    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_AR_SNG
    -- Purpose:     If single port BRAM configuration, set all AR flags from
    --              logic generated in sng_port_arb module.
    --
    ---------------------------------------------------------------------------
    
    
    GEN_AR_SNG: if (C_SINGLE_PORT_BRAM = 1) generate
    begin
        
        araddr_pipe_sel <= '0';         -- Unused in single port configuration
        
        ar_active <= Arb2AR_Active;
        bram_addr_ld_en <= ar_active_re;
        brst_cnt_ld_en <= ar_active_re;
        
        AR2Arb_Active_Clr <= axi_rlast_int and AXI_RREADY;
        
        -- Rising edge detect of Arb2AR_Active
        RE_AR_ACT: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                
                -- Clear ar_active_d1 early w/ ar_active
                -- So back to back ar_active assertions see the new transaction
                -- and initiate the read transfer.
                if (S_AXI_AResetn = C_RESET_ACTIVE) or ((axi_rlast_int and AXI_RREADY) = '1') then
                    ar_active_d1 <= '0';
                else
                    ar_active_d1 <= ar_active;
                end if;
            end if;
        end process RE_AR_ACT;
        
        ar_active_re <= '1' when (ar_active = '1' and ar_active_d1 = '0') else '0';


    end generate GEN_AR_SNG;        
    
    
    
    
    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_AW_DUAL
    -- Purpose:     Generate AW control state machine logic only when AXI4
    --              controller is configured for dual port mode.  In dual port
    --              mode, wr_chnl has full access over AW & port A of BRAM.
    --
    ---------------------------------------------------------------------------
    
    GEN_AR_DUAL: if (C_SINGLE_PORT_BRAM = 0) generate
    begin

        AR2Arb_Active_Clr <= '0';   -- Only used in single port case


        ---------------------------------------------------------------------------
        -- RD ADDR State Machine
        --
        -- Description:     Central processing unit for AXI write address
        --                  channel interface handling and handshaking.
        --
        -- Outputs:         araddr_pipe_ld          Not Registered
        --                  araddr_pipe_sel         Not Registered
        --                  bram_addr_ld_en         Not Registered
        --                  brst_cnt_ld_en          Not Registered
        --                  ar_active_set           Not Registered
        --
        -- WR_ADDR_SM_CMB_PROCESS:      Combinational process to determine next state.
        -- WR_ADDR_SM_REG_PROCESS:      Registered process of the state machine.
        --
        ---------------------------------------------------------------------------

        RD_ADDR_SM_CMB_PROCESS: process ( AXI_ARVALID,
                                          axi_araddr_full,
                                          ar_active,
                                          no_ar_ack,
                                          pend_rd_op,
                                          last_bram_addr,           
                                          rd_b2b_elgible,           
                                          rd_addr_sm_cs )

        begin

        -- assign default values for state machine outputs
        rd_addr_sm_ns <= rd_addr_sm_cs;
        araddr_pipe_ld_i <= '0';
        bram_addr_ld_en_i <= '0';
        brst_cnt_ld_en_i <= '0';
        ar_active_set_i <= '0';

        case rd_addr_sm_cs is


                ---------------------------- IDLE State ---------------------------

                when IDLE =>


                    -- Reload BRAM address counter on last BRAM address of current burst
                    -- if a new address is pending in the AR pipeline and is elgible to
                    -- be loaded for subsequent back-to-back performance.

                    if (last_bram_addr = '1' and rd_b2b_elgible = '1') then

                        -- Load BRAM address counter from pipelined value
                        bram_addr_ld_en_i <= '1';
                        brst_cnt_ld_en_i <= '1';

                        ar_active_set_i <= '1';


                        -- If loading BRAM counter for subsequent operation
                        -- AND ARVALID is pending on the bus, go ahead and respond
                        -- and fill ARADDR pipeline with next operation.
                        -- 
                        -- Asserting the signal to load the ARADDR pipeline here
                        -- allows the full bandwidth utilization to BRAM on
                        -- back to back bursts of two data beats.

                        if (AXI_ARVALID = '1') then
                            araddr_pipe_ld_i <= '1';
                            rd_addr_sm_ns <= LD_ARADDR;
                        else
                            rd_addr_sm_ns <= IDLE;
                        end if;


                    elsif (AXI_ARVALID = '1') then

                        -- If address pipeline is full
                        -- ARReady output is negated
                        -- Remain in this state
                        --
                        -- Add check for already pending read operation
                        -- in data SM, but waiting on throttle (even though ar_active is
                        -- already set to '0').

                        if (ar_active = '0') and (no_ar_ack = '0') and (pend_rd_op = '0') then

                            rd_addr_sm_ns <= IDLE;
                            bram_addr_ld_en_i <= '1';
                            brst_cnt_ld_en_i <= '1';
                            ar_active_set_i <= '1';


                        -- Address counter is currently busy
                        else

                            -- Check if ARADDR pipeline is not full and can be loaded
                            if (axi_araddr_full = '0') then

                                rd_addr_sm_ns <= LD_ARADDR;
                                araddr_pipe_ld_i <= '1';

                            end if;

                        end if; -- ar_active


                    -- Pending operation in pipeline that is waiting
                    -- until current operation is complete (ar_active = '0')

                    elsif (axi_araddr_full = '1') and 
                          (ar_active = '0') and 
                          (no_ar_ack = '0') and 
                          (pend_rd_op = '0') then

                        rd_addr_sm_ns <= IDLE;

                        -- Load BRAM address counter from pipelined value
                        bram_addr_ld_en_i <= '1';
                        brst_cnt_ld_en_i <= '1';

                        ar_active_set_i <= '1';

                    end if; -- ARVALID



                ---------------------------- LD_ARADDR State ---------------------------

                when LD_ARADDR =>


                    -- Check here for subsequent BRAM address load when ARADDR pipe is loaded
                    -- in previous clock cycle.
                    -- 
                    -- Reload BRAM address counter on last BRAM address of current burst
                    -- if a new address is pending in the AR pipeline and is elgible to
                    -- be loaded for subsequent back-to-back performance.

                    if (last_bram_addr = '1' and rd_b2b_elgible = '1') then

                        -- Load BRAM address counter from pipelined value
                        bram_addr_ld_en_i <= '1';
                        brst_cnt_ld_en_i <= '1';

                        ar_active_set_i <= '1';

                        -- If loading BRAM counter for subsequent operation
                        -- AND ARVALID is pending on the bus, go ahead and respond
                        -- and fill ARADDR pipeline with next operation.
                        -- 
                        -- Asserting the signal to load the ARADDR pipeline here
                        -- allows the full bandwidth utilization to BRAM on
                        -- back to back bursts of two data beats.

                        if (AXI_ARVALID = '1') then

                            araddr_pipe_ld_i <= '1';
                            rd_addr_sm_ns <= LD_ARADDR;
                            -- Stay in this state another clock cycle

                        else
                            rd_addr_sm_ns <= IDLE;
                        end if;

                    else
                        rd_addr_sm_ns <= IDLE;
                    end if;



        --coverage off
                ------------------------------ Default ----------------------------
                when others =>
                    rd_addr_sm_ns <= IDLE;
        --coverage on

            end case;

        end process RD_ADDR_SM_CMB_PROCESS;


        ---------------------------------------------------------------------------

        -- CR # 582705
        -- Ensure combinatorial SM output signals do not get set before
        -- the end of the reset (and ARREAADY can be set).
        bram_addr_ld_en <= bram_addr_ld_en_i and axi_aresetn_d2;
        brst_cnt_ld_en <= brst_cnt_ld_en_i and axi_aresetn_d2;
        ar_active_set <= ar_active_set_i and axi_aresetn_d2;
        araddr_pipe_ld <= araddr_pipe_ld_i and axi_aresetn_d2;


        RD_ADDR_SM_REG_PROCESS: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                -- if (S_AXI_AResetn = C_RESET_ACTIVE) then
                
                -- CR # 582705
                -- Ensure that ar_active does not get asserted (from SM) before 
                -- the end of reset and the ARREADY flag is set.
                if (axi_aresetn_d2 = C_RESET_ACTIVE) then
                    rd_addr_sm_cs <= IDLE;
                else
                    rd_addr_sm_cs <= rd_addr_sm_ns;
                end if;
            end if;

        end process RD_ADDR_SM_REG_PROCESS;


        ---------------------------------------------------------------------------

        -- Assert araddr_pipe_sel outside of SM logic
        -- The BRAM address counter will get loaded with value in ARADDR pipeline
        -- when data is stored in the ARADDR pipeline.

        araddr_pipe_sel <= '1' when (axi_araddr_full = '1') else '0'; 


        ---------------------------------------------------------------------------


        -- Register for ar_active

        REG_AR_ACT: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                -- if (S_AXI_AResetn = C_RESET_ACTIVE) then
                
                -- CR # 582705
                if (axi_aresetn_d2 = C_RESET_ACTIVE) then
                    ar_active <= '0';

                elsif (ar_active_set = '1') then 
                    ar_active <= '1';

                -- For code coverage closure, ensure priority encoding in if/else clause
                -- to prevent checking ar_active_set in reset clause.
                elsif (ar_active_clr = '1') then
                    ar_active <= '0';

                else 
                    ar_active <= ar_active;
                end if;
            end if;

        end process REG_AR_ACT;


    end generate GEN_AR_DUAL;


   

    ---------------------------------------------------------------------------
    --
    --  REG_BRST_CNT. 
    --  Read Burst Counter.
    --  No need to decrement burst counter.
    --  Able to load with fixed burst length value.
    --  Replace usage of proc_common_v4_0_2 library with direct HDL.
    --
    --  Size of counter = C_BRST_CNT_SIZE
    --                    Max size of burst transfer = 256 data beats
    --
    ---------------------------------------------------------------------------

    REG_BRST_CNT: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1') then

            if (brst_cnt_rst = '1') then
                brst_cnt <= (others => '0');

            -- Load burst counter
            elsif (brst_cnt_ld_en = '1') then
                brst_cnt <= brst_cnt_ld;

            -- Decrement ONLY (no increment functionality)
            elsif (brst_cnt_dec = '1') then
                brst_cnt (C_BRST_CNT_SIZE-1 downto 0) <= 
                        std_logic_vector (unsigned (brst_cnt (C_BRST_CNT_SIZE-1 downto 0)) - 1);

            end if;
        end if;

    end process REG_BRST_CNT;


    ---------------------------------------------------------------------------

    brst_cnt_rst <= not (S_AXI_AResetn);


    -- Determine burst count load value
    -- Either load BRAM counter directly from AXI bus or from stored registered value.
    -- Use mux signal for ARLEN

    BRST_CNT_LD_PROCESS : process (curr_arlen)
    variable brst_cnt_ld_int    : integer := 0;
    begin

        brst_cnt_ld_int := to_integer (unsigned (curr_arlen (7 downto 0)));
        brst_cnt_ld <= std_logic_vector (to_unsigned (brst_cnt_ld_int, 8));

    end process BRST_CNT_LD_PROCESS;



    ----------------------------------------------------------------------------




    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_BRST_MAX_W_NARROW
    -- Purpose:     Generate registered logic for brst_cnt_max when the
    --              design instantiation supports narrow operations.
    --
    ---------------------------------------------------------------------------

    GEN_BRST_MAX_W_NARROW: if (C_S_AXI_SUPPORTS_NARROW = 1) generate
    begin


        REG_BRST_MAX: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or (brst_cnt_ld_en = '1')
                
                    -- Added with single port (13.1 release)
                    or (end_brst_rd_clr = '1') then
                    brst_cnt_max <= '0';

                -- Replace usage of brst_cnt in this logic.
                -- Replace with registered signal, brst_zero, indicating the 
                -- brst_cnt to be zero when decrement.

                elsif (brst_zero = '1') and (ar_active = '1') and (pend_rd_op = '0') then 


                    -- Hold off assertion of brst_cnt_max on narrow burst transfers
                    -- Must wait until narrow burst count = 0.
                    if (curr_narrow_burst = '1') then

                        if (narrow_bram_addr_inc = '1') then
                            brst_cnt_max <= '1';
                        end if;
                    else
                        brst_cnt_max <= '1';
                    end if;

                else 
                    brst_cnt_max <= brst_cnt_max;
                end if;
            end if;

        end process REG_BRST_MAX;



    end generate GEN_BRST_MAX_W_NARROW;



    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_BRST_MAX_WO_NARROW
    -- Purpose:     Generate registered logic for brst_cnt_max when the
    --              design instantiation does not support narrow operations.
    --
    ---------------------------------------------------------------------------

    GEN_BRST_MAX_WO_NARROW: if (C_S_AXI_SUPPORTS_NARROW = 0) generate
    begin


        REG_BRST_MAX: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or (brst_cnt_ld_en = '1') then
                    brst_cnt_max <= '0';

                -- Replace usage of brst_cnt in this logic.
                -- Replace with registered signal, brst_zero, indicating the 
                -- brst_cnt to be zero when decrement.

                elsif (brst_zero = '1') and (ar_active = '1') and (pend_rd_op = '0') then 

                    -- When narrow operations are not supported in the core
                    -- configuration, no check for curr_narrow_burst on assertion.
                    brst_cnt_max <= '1';

                else 
                    brst_cnt_max <= brst_cnt_max;
                end if;
            end if;

        end process REG_BRST_MAX;


    end generate GEN_BRST_MAX_WO_NARROW;



    ---------------------------------------------------------------------------


    REG_BRST_MAX_D1: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                brst_cnt_max_d1 <= '0';
            else 
                brst_cnt_max_d1 <= brst_cnt_max;
            end if;
        end if;

    end process REG_BRST_MAX_D1;


    brst_cnt_max_re <= '1' when (brst_cnt_max = '1') and (brst_cnt_max_d1 = '0') else '0';


    -- Set flag that end of burst is reached
    -- Need to capture this condition as the burst
    -- counter may get reloaded for a subsequent read burst

    REG_END_BURST: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            -- SM may assert clear flag early (in case of narrow bursts)
            -- Wait until the end_brst_rd flag is asserted to clear the flag.

            if (S_AXI_AResetn = C_RESET_ACTIVE) or 
               (end_brst_rd_clr = '1' and end_brst_rd = '1') then
                end_brst_rd <= '0';

            elsif (brst_cnt_max_re = '1') then
                end_brst_rd <= '1';
            end if;
        end if;

    end process REG_END_BURST;



    ---------------------------------------------------------------------------

    -- Create flag that indicates burst counter is reaching ZEROs (max of burst
    -- length)

    REG_BURST_ZERO: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

             if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                ((brst_cnt_ld_en = '1') and (brst_cnt_ld /= C_BRST_CNT_ZERO)) then
                 brst_zero <= '0';

             elsif (brst_cnt_dec = '1') and (brst_cnt = C_BRST_CNT_ONE) then
                 brst_zero <= '1';
             else
                 brst_zero <= brst_zero;
             end if;

        end if;

    end process REG_BURST_ZERO;


    ---------------------------------------------------------------------------

    -- Create additional flag that indicates burst counter is reaching ONEs 
    -- (near end of burst length).  Used to disable back-to-back condition in SM.

    REG_BURST_ONE: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

             if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                ((brst_cnt_ld_en = '1') and (brst_cnt_ld /= C_BRST_CNT_ONE)) or
                ((brst_cnt_dec = '1') and (brst_cnt = C_BRST_CNT_ONE)) then
                 brst_one <= '0';

             elsif ((brst_cnt_dec = '1') and (brst_cnt = C_BRST_CNT_TWO)) or
                   ((brst_cnt_ld_en = '1') and (brst_cnt_ld = C_BRST_CNT_ONE)) then
                 brst_one <= '1';
             else
                 brst_one <= brst_one;
             end if;

        end if;

    end process REG_BURST_ONE;


    ---------------------------------------------------------------------------

    -- Register flags for read burst operation
    REG_RD_BURST: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            -- Clear axi_rd_burst flags when burst count gets to zeros (unless the burst
            -- counter is getting subsequently loaded for the new burst operation)
            -- 
            -- Replace usage of brst_cnt in this logic.
            -- Replace with registered signal, brst_zero, indicating the 
            -- brst_cnt to be zero when decrement.

            if (S_AXI_AResetn = C_RESET_ACTIVE) or (brst_zero = '1' and brst_cnt_ld_en = '0') then
                axi_rd_burst <= '0';
                axi_rd_burst_two <= '0';

            elsif (brst_cnt_ld_en = '1') then

                if (curr_arlen /= AXI_ARLEN_ONE and curr_arlen /= AXI_ARLEN_TWO) then
                    axi_rd_burst <= '1';
                else
                    axi_rd_burst <= '0';
                end if;

                if (curr_arlen = AXI_ARLEN_TWO) then
                    axi_rd_burst_two <= '1';
                else
                    axi_rd_burst_two <= '0';
                end if;

            else
                axi_rd_burst <= axi_rd_burst;
                axi_rd_burst_two <= axi_rd_burst_two;

            end if;
        end if;

    end process REG_RD_BURST;



    ---------------------------------------------------------------------------


    -- Seeing issue with axi_rd_burst getting cleared too soon
    -- on subsquent brst_cnt_ld_en early assertion and pend_rd_op is asserted.


    -- Create flag for currently active read burst operation
    -- Gets asserted when burst counter is loaded, but does not
    -- get cleared until the RD_DATA_SM has completed the read
    -- burst operation

    REG_ACT_RD_BURST: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) or (act_rd_burst_clr = '1') then
                act_rd_burst <= '0';
                act_rd_burst_two <= '0';

            elsif (act_rd_burst_set = '1') then

                -- If not loading the burst counter for a B2B operation
                -- Then act_rd_burst follows axi_rd_burst and
                -- act_rd_burst_two follows axi_rd_burst_two.

                -- Get registered value of axi_* signal.
                if (brst_cnt_ld_en = '0') then
                    act_rd_burst <= axi_rd_burst;
                    act_rd_burst_two <= axi_rd_burst_two;

                else

                    -- Otherwise, duplicate logic for axi_* signals if burst counter
                    -- is getting loaded.

                    -- For improved code coverage here
                    -- The act_rd_burst_set signal will never get asserted if the burst
                    -- size is less than two data beats.  So, the conditional check
                    -- for (curr_arlen /= AXI_ARLEN_ONE) is never evaluated.  Removed
                    -- from this if clause.

                    if (curr_arlen /= AXI_ARLEN_TWO) then
                        act_rd_burst <= '1';
                    else
                        act_rd_burst <= '0';
                    end if;


                    if (curr_arlen = AXI_ARLEN_TWO) then
                        act_rd_burst_two <= '1';
                    else
                        act_rd_burst_two <= '0';
                    end if;

                    -- Note: re-code this if/else clause.
                end if;

            else
                act_rd_burst <= act_rd_burst;
                act_rd_burst_two <= act_rd_burst_two;

            end if;
        end if;

    end process REG_ACT_RD_BURST;



    ---------------------------------------------------------------------------



    rd_adv_buf <= axi_rvalid_int and AXI_RREADY;





    ---------------------------------------------------------------------------
    -- RD DATA State Machine
    --
    -- Description:     Central processing unit for AXI write data
    --                  channel interface handling and AXI write data response
    --                  handshaking.
    --
    -- Outputs:         Name                        Type
    --
    --                  bram_en_int                 Registered
    --                  bram_addr_inc               Not Registered
    --                  brst_cnt_dec                Not Registered
    --                  rddata_mux_sel              Registered
    --                  axi_rdata_en                Not Registered
    --                  axi_rvalid_set              Registered
    --
    --
    -- RD_DATA_SM_CMB_PROCESS:      Combinational process to determine next state.
    -- RD_DATA_SM_REG_PROCESS:      Registered process of the state machine.
    --
    ---------------------------------------------------------------------------
    RD_DATA_SM_CMB_PROCESS: process ( bram_addr_ld_en,
                                      rd_adv_buf,
                                      ar_active,
                                      axi_araddr_full,                  
                                      rd_b2b_elgible_no_thr_check,      

                                      disable_b2b_brst,                 

                                      curr_arlen,                       

                                      axi_rd_burst, 
                                      axi_rd_burst_two,
                                      act_rd_burst,
                                      act_rd_burst_two,

                                      end_brst_rd,
                                      brst_zero,                        
                                      brst_one,                         

                                      axi_b2b_brst,                     

                                      bram_en_int,
                                      rddata_mux_sel,
                                      end_brst_rd_clr,
                                      no_ar_ack,
                                      pend_rd_op,
                                      axi_rlast_int,                    

                                      rd_data_sm_cs )

    begin

        -- assign default values for state machine outputs
        rd_data_sm_ns <= rd_data_sm_cs;

        bram_en_cmb <= bram_en_int;
        bram_addr_inc <= '0';
        brst_cnt_dec <= '0';

        rd_skid_buf_ld_cmb <= '0';
        rd_skid_buf_ld_imm <= '0';
        rddata_mux_sel_cmb <= rddata_mux_sel;  

        -- Change axi_rdata_en generated from SM to be a combinatorial signal
        -- Can't afford the latency when throttling on the AXI bus.
        axi_rdata_en <= '0';

        axi_rvalid_set_cmb <= '0';

        end_brst_rd_clr_cmb <= end_brst_rd_clr;

        no_ar_ack_cmb <= no_ar_ack;
        pend_rd_op_cmb <= pend_rd_op;
        act_rd_burst_set <= '0';
        act_rd_burst_clr <= '0';

        set_last_bram_addr <= '0';
        alast_bram_addr <= '0';                     
        axi_b2b_brst_cmb <= axi_b2b_brst;           
        disable_b2b_brst_cmb <= disable_b2b_brst;   

        ar_active_clr <= '0';                       

        case rd_data_sm_cs is


                ---------------------------- IDLE State ---------------------------

                when IDLE =>


                    -- Initiate BRAM read when address is available in controller
                    -- Indicated by load of BRAM address counter

                    -- Remove use of pend_rd_op signal.
                    -- Never asserted as we transition back to IDLE
                    -- Detected in code coverage

                    if (bram_addr_ld_en = '1') then

                        -- At start of new read, clear end burst signal
                        end_brst_rd_clr_cmb <= '0';

                        -- Initiate BRAM read transfer
                        bram_en_cmb <= '1';


                        -- Only count addresses & burst length for read
                        -- burst operations


                        -- If currently loading BRAM address counter
                        -- Must check curr_arlen (mux output from pipe or AXI bus)
                        -- to determine length of next operation.
                        -- If ARLEN = 1 data beat, then set last_bram_addr signal
                        -- Otherwise, increment BRAM address counter.

                        if (curr_arlen /= AXI_ARLEN_ONE) then


                            -- Start of new operation, update act_rd_burst and 
                            -- act_rd_burst_two signals
                            act_rd_burst_set <= '1';


                        else
                            -- Set flag for last_bram_addr on transition
                            -- to SNG_ADDR on single operations.
                            set_last_bram_addr <= '1';

                        end if;

                        -- Go to single active read address state
                        rd_data_sm_ns <= SNG_ADDR;


                    end if;


                ------------------------- SNG_ADDR State --------------------------

                when SNG_ADDR =>



                    -- Clear flag once pending read is recognized
                    -- Duplicate logic here in case combinatorial flag was getting
                    -- set as the SM transitioned into this state.
                    if (pend_rd_op = '1') then
                        pend_rd_op_cmb <= '0';
                    end if;


                    -- At start of new read, clear end burst signal
                    end_brst_rd_clr_cmb <= '0';


                    -- Reach this state on first BRAM address & enable assertion
                    -- For burst operation, create next BRAM address and keep enable
                    -- asserted

                    -- Note:
                    -- No ability to throttle yet as RVALID has not yet been
                    -- asserted on the AXI bus


                    -- Reset data mux select between skid buffer and BRAM
                    -- Ensure read data mux is set for BRAM data
                    rddata_mux_sel_cmb <= C_RDDATA_MUX_BRAM;  


                    -- Assert RVALID on AXI when 1st data beat available
                    -- from BRAM
                    axi_rvalid_set_cmb <= '1';                                


                    -- Reach this state when BRAM address counter is loaded
                    -- Use axi_rd_burst and axi_rd_burst_two to indicate if
                    -- operation is a single data beat burst.

                    if (axi_rd_burst = '0') and (axi_rd_burst_two = '0') then


                        -- Proceed directly to get BRAM read data
                        rd_data_sm_ns <= LAST_ADDR;

                        -- End of active current read address
                        ar_active_clr <= '1';

                        -- Negate BRAM enable
                        bram_en_cmb <= '0';

                        -- Load read data skid buffer for BRAM capture 
                        -- in next clock cycle
                        rd_skid_buf_ld_cmb <= '1';


                        -- Assert new flag to disable back-to-back bursts
                        -- due to throttling
                        disable_b2b_brst_cmb <= '1';

                        
                        -- Set flag for pending operation if bram_addr_ld_en is asserted (BRAM
                        -- address is loaded) and we are waiting for the current read burst to complete.
                        if (bram_addr_ld_en = '1') then
                            pend_rd_op_cmb <= '1';
                        end if;


                    -- Read burst
                    else

                        -- Increment BRAM address counter (2nd data beat)
                        bram_addr_inc <= '1';

                        -- Decrement BRAM burst counter (2nd data beat)
                        brst_cnt_dec <= '1';

                        -- Keep BRAM enable asserted
                        bram_en_cmb <= '1';

                        rd_data_sm_ns <= SEC_ADDR;


                        -- Load read data skid buffer for BRAM capture 
                        -- in next clock cycle
                        rd_skid_buf_ld_cmb <= '1';

                        -- Start of new operation, update act_rd_burst and 
                        -- act_rd_burst_two signals
                        act_rd_burst_set <= '1';


                        -- If new burst is 2 data beats
                        -- Then disable capability on back-to-back bursts
                        if (axi_rd_burst_two = '1') then

                            -- Assert new flag to disable back-to-back bursts
                            -- due to throttling
                            disable_b2b_brst_cmb <= '1';

                        else
                            -- Support back-to-back for all other burst lengths
                            disable_b2b_brst_cmb <= '0';

                        end if;


                    end if;




                ------------------------- SEC_ADDR State --------------------------

                when SEC_ADDR =>

                    -- Reach this state when the 2nd incremented address of the burst
                    -- is presented to the BRAM.

                    -- Only reach this state when axi_rd_burst = '1',
                    -- an active read burst.

                    -- Note:
                    -- No ability to throttle yet as RVALID has not yet been
                    -- asserted on the AXI bus


                    -- Enable AXI read data register
                    axi_rdata_en <= '1';


                    -- Only in dual port mode can the address counter get loaded early
                    if C_SINGLE_PORT_BRAM = 0 then

                        -- If we see the next address get loaded into the BRAM counter
                        -- then set flag for pending operation
                        if (bram_addr_ld_en = '1') then
                            pend_rd_op_cmb <= '1';
                        end if;

                    end if;
                    

                    -- Check here for burst length of two data transfers
                    -- If so, then the SM will NOT hit the condition of a full
                    -- pipeline:
                    -- Operation A) 1st BRAM address data on AXI bus
                    -- Operation B) 2nd BRAm address data read from BRAM
                    -- Operation C) 3rd BRAM address presented to BRAM
                    --
                    -- Full pipeline condition is hit for any read burst
                    -- length greater than 2 data beats.

                    if (axi_rd_burst_two = '1') then


                        -- No increment of BRAM address
                        -- or decrement of burst counter
                        -- Burst counter should be = zero
                        rd_data_sm_ns <= LAST_ADDR;

                        -- End of active current read address
                        ar_active_clr <= '1';

                        -- Ensure read data mux is set for BRAM data
                        rddata_mux_sel_cmb <= C_RDDATA_MUX_BRAM;                    

                        -- Negate BRAM enable
                        bram_en_cmb <= '0';


                        -- Load read data skid buffer for BRAM capture 
                        -- in next clock cycle.
                        -- This signal will negate in the next state
                        -- if the data is not accepted on the AXI bus.
                        -- So that no new data from BRAM is registered into the
                        -- read channel controller.
                        rd_skid_buf_ld_cmb <= '1';



                    else

                        -- Burst length will hit full pipeline condition

                        -- Increment BRAM address counter (3rd data beat)
                        bram_addr_inc <= '1';


                        -- Decrement BRAM burst counter (3rd data beat)
                        brst_cnt_dec <= '1';

                        -- Keep BRAM enable asserted
                        bram_en_cmb <= '1';

                        rd_data_sm_ns <= FULL_PIPE;


                        -- Assert almost last BRAM address flag
                        -- so that ARVALID logic output can remain registered
                        --
                        -- Replace usage of brst_cnt with signal, brst_one.
                        if (brst_one = '1') then
                            alast_bram_addr <= '1';                    
                        end if;

                        -- Load read data skid buffer for BRAM capture 
                        -- in next clock cycle
                        rd_skid_buf_ld_cmb <= '1';


                    end if; -- ARLEN = "0000 0001"





                ------------------------- FULL_PIPE State -------------------------

                when FULL_PIPE =>


                    -- Reach this state when all three data beats in the burst
                    -- are active
                    -- 
                    -- Operation A) 1st BRAM address data on AXI bus
                    -- Operation B) 2nd BRAM address data read from BRAM
                    -- Operation C) 3rd BRAM address presented to BRAM


                    -- Ensure read data mux is set for BRAM data
                    rddata_mux_sel_cmb <= C_RDDATA_MUX_BRAM;                    


                    -- With new pipelining capability BRAM address counter may be 
                    -- loaded in this state.  This only occurs on back-to-back 
                    -- bursts (when enabled).
                    -- No flag set for pending operation.

                    -- Modify the if clause here to check for back-to-back burst operations
                    -- If we load the BRAM address in this state for a subsequent burst, then
                    -- this condition indicates a back-to-back burst and no need to assert
                    -- the pending read operation flag.


                    -- Seeing corner case when pend_rd_op needs to be asserted and cleared
                    -- in this state.  If the BRAM address counter is loaded early, but
                    -- axi_rlast_set is delayed in getting asserted (all while in this state).
                    -- The signal, curr_narrow_burst can not get cleared.


                    -- Only in dual port mode can the address counter get loaded early
                    if C_SINGLE_PORT_BRAM = 0 then


                        -- Set flag for pending operation if bram_addr_ld_en is asserted (BRAM
                        -- address is loaded) and we are waiting for the current read burst to complete.
                        if (bram_addr_ld_en = '1') then
                            pend_rd_op_cmb <= '1';

                        -- Clear flag once pending read is recognized and
                        -- earlier read data phase is complete.
                        elsif (pend_rd_op = '1') and (axi_rlast_int = '1') then
                            pend_rd_op_cmb <= '0';

                        end if;

                    end if;


                    -- Check AXI throttling condition
                    -- If AXI bus advances and accepts read data, SM can
                    -- proceed with next data beat of burst.
                    -- If not, then go to FULL_THROTTLE state to wait for
                    -- AXI_RREADY = '1'.

                    if (rd_adv_buf = '1') then


                        -- Assert AXI read data enable for BRAM capture 
                        axi_rdata_en <= '1';

                        -- Load read data skid buffer for BRAM capture in next clock cycle
                        rd_skid_buf_ld_cmb <= '1';


                        -- Assert almost last BRAM address flag
                        -- so that ARVALID logic output can remain registered
                        --
                        -- Replace usage of brst_cnt with signal, brst_one.
                        if (brst_one = '1') then
                            alast_bram_addr <= '1';                    
                        end if;



                        -- Check burst counter for max
                        -- If max burst count is reached, no new addresses
                        -- presented to BRAM, advance to last capture data states.
                        --
                        -- For timing, replace usage of brst_cnt in this SM.
                        -- Replace with registered signal, brst_zero, indicating the 
                        -- brst_cnt to be zero when decrement.

                        if (brst_zero = '1') or (end_brst_rd = '1' and axi_b2b_brst = '0') then



                            -- Check for elgible pending read operation to support back-to-back performance.
                            -- If so, load BRAM address counter.
                            --                            
                            -- Replace rd_b2b_elgible signal check to remove path from 
                            -- arlen_pipe through rd_b2b_elgible 
                            -- (with data throttle check)
                            
                            if (rd_b2b_elgible_no_thr_check = '1') then


                                rd_data_sm_ns <= FULL_PIPE;

                                -- Set flag to indicate back-to-back read burst
                                -- RVALID will not clear in this case and remain asserted
                                axi_b2b_brst_cmb <= '1';

                                -- Set flag to update active read burst or 
                                -- read burst of two flag
                                act_rd_burst_set <= '1';



                            -- Otherwise, complete current transaction
                            else

                                -- No increment of BRAM address
                                -- or decrement of burst counter
                                -- Burst counter should be = zero
                                bram_addr_inc <= '0';
                                brst_cnt_dec <= '0';

                                rd_data_sm_ns <= LAST_ADDR;

                                -- Negate BRAM enable
                                bram_en_cmb <= '0';

                                -- End of active current read address
                                ar_active_clr <= '1';

                            end if;

                        else

                            -- Remain in this state until burst count reaches zero

                            -- Increment BRAM address counter (Nth data beat)
                            bram_addr_inc <= '1';

                            -- Decrement BRAM burst counter (Nth data beat)
                            brst_cnt_dec <= '1';

                            -- Keep BRAM enable asserted
                            bram_en_cmb <= '1';


                            -- Skid buffer load will remain asserted
                            -- AXI read data register is asserted

                        end if;



                    else

                        -- Throttling condition detected                    
                        rd_data_sm_ns <= FULL_THROTTLE;

                        -- Ensure that AXI read data output register is disabled
                        -- due to throttle condition.
                        axi_rdata_en <= '0';

                        -- Skid buffer gets loaded from BRAM read data in next clock
                        -- cycle ONLY.
                        -- Only on transition to THROTTLE state does skid buffer get loaded.

                        -- Negate load of read data skid buffer for BRAM capture 
                        -- in next clock cycle due to detection of Throttle condition
                        rd_skid_buf_ld_cmb <= '0';


                        -- BRAM address is NOT getting incremented 
                        -- (same for burst counter)
                        bram_addr_inc <= '0';
                        brst_cnt_dec <= '0';


                        -- If transitioning to throttle state
                        -- Then next register enable assertion of the AXI read data
                        -- output register needs to come from the skid buffer
                        -- Set read data mux select here for SKID_BUFFER data
                        rddata_mux_sel_cmb <= C_RDDATA_MUX_SKID_BUF;                    


                        -- Detect if at end of burst read as we transition to FULL_THROTTLE
                        -- If so, negate the BRAM enable even if prior to throttle condition
                        -- on AXI bus.  Read skid buffer will hold last beat of data in burst.
                        --
                        -- For timing purposes, replace usage of brst_cnt in this SM.
                        -- Replace with registered signal, brst_zero, indicating the 
                        -- brst_cnt to be zero when decrement.

                        if (brst_zero = '1') or (end_brst_rd = '1') then


                            -- No back to back "non bubble" support when AXI master 
                            -- is throttling on current burst.
                            -- Seperate signal throttle_last_data will be asserted outside SM.

                            -- End of burst read, negate BRAM enable
                            bram_en_cmb <= '0';


                            -- Assert new flag to disable back-to-back bursts
                            -- due to throttling
                            disable_b2b_brst_cmb <= '1';



                        -- Disable B2B capability if throttling detected when
                        -- burst count is equal to one.
                        --
                        -- For timing purposes, replace usage of brst_cnt in this SM.
                        -- Replace with registered signal, brst_one, indicating the 
                        -- brst_cnt to be one when decrement.

                        elsif (brst_one = '1') then


                            -- Assert new flag to disable back-to-back bursts
                            -- due to throttling
                            disable_b2b_brst_cmb <= '1';


                        -- Throttle, but not end of burst
                        else
                            bram_en_cmb <= '1';

                        end if;


                    end if; -- rd_adv_buf (RREADY throttle)



                ------------------------- FULL_THROTTLE State ---------------------

                when FULL_THROTTLE =>


                    -- Reach this state when the AXI bus throttles on the AXI data
                    -- beat read from BRAM (when the read pipeline is fully active)


                    -- Flag disable_b2b_brst_cmb should be asserted as we transition
                    -- to this state. Flag is asserted near the end of a read burst
                    -- to prevent the back-to-back performance pipelining in the BRAM
                    -- address counter.



                    -- Detect if at end of burst read
                    -- If so, negate the BRAM enable even if prior to throttle condition
                    -- on AXI bus.  Read skid buffer will hold last beat of data in burst.
                    --
                    -- For timing, replace usage of brst_cnt in this SM.
                    -- Replace with registered signal, brst_zero, indicating the 
                    -- brst_cnt to be zero when decrement.
                    
                    if (brst_zero = '1') or (end_brst_rd = '1') then
                        bram_en_cmb <= '0';
                    end if;

                    
                    -- Set new flag for pending operation if bram_addr_ld_en is asserted (BRAM
                    -- address is loaded) and we are waiting for the current read burst to complete.
                    if (bram_addr_ld_en = '1') then
                        pend_rd_op_cmb <= '1';

                    -- Clear flag once pending read is recognized and
                    -- earlier read data phase is complete.

                    elsif (pend_rd_op = '1') and (axi_rlast_int = '1') then
                        pend_rd_op_cmb <= '0';
                    end if;
                    
                    

                    -- Wait for RREADY to be asserted w/ RVALID on AXI bus
                    if (rd_adv_buf = '1') then


                        -- Ensure read data mux is set for skid buffer data
                        rddata_mux_sel_cmb <= C_RDDATA_MUX_SKID_BUF;

                        -- Ensure that AXI read data output register is enabled
                        axi_rdata_en <= '1';


                        -- Must reload skid buffer here from BRAM data
                        -- so if needed can be presented to AXI bus on the following clock cycle
                        rd_skid_buf_ld_imm <= '1';



                        -- When detecting end of throttle condition
                        -- Check first if burst count is complete

                        -- Check burst counter for max
                        -- If max burst count is reached, no new addresses
                        -- presented to BRAM, advance to last capture data states.
                        --
                        -- For timing, replace usage of brst_cnt in this SM.
                        -- Replace with registered signal, brst_zero, indicating the 
                        -- brst_cnt to be zero when decrement.

                        if (brst_zero = '1') or (end_brst_rd = '1') then


                            -- No back-to-back performance when AXI master throttles
                            -- If we reach the end of the burst, proceed to LAST_ADDR state.


                            -- No increment of BRAM address
                            -- or decrement of burst counter
                            -- Burst counter should be = zero
                            bram_addr_inc <= '0';
                            brst_cnt_dec <= '0';

                            rd_data_sm_ns <= LAST_ADDR;

                            -- Negate BRAM enable
                            bram_en_cmb <= '0';

                            -- End of active current read address
                            ar_active_clr <= '1';



                        -- Not end of current burst w/ throttle condition
                        else

                            -- Go back to FULL_PIPE
                            rd_data_sm_ns <= FULL_PIPE;


                            -- Assert almost last BRAM address flag
                            -- so that ARVALID logic output can remain registered
                            --
                            -- For timing purposes, replace usage of brst_cnt in this SM.
                            -- Replace with registered signal, brst_one, indicating the 
                            -- brst_cnt to be one when decrement.
                            if (brst_one = '1') then
                                alast_bram_addr <= '1';                    
                            end if;



                            -- Increment BRAM address counter (Nth data beat)
                            bram_addr_inc <= '1';

                            -- Decrement BRAM burst counter (Nth data beat)
                            brst_cnt_dec <= '1';
                            
                            -- Keep BRAM enable asserted
                            bram_en_cmb <= '1';
                            


                        end if; -- Burst Max                     

                    else

                        -- Stay in this state

                        -- Ensure that AXI read data output register is disabled
                        -- due to throttle condition.
                        axi_rdata_en <= '0';

                        -- Ensure that skid buffer is not getting loaded with
                        -- current read data from BRAM
                        rd_skid_buf_ld_cmb <= '0';

                        -- BRAM address is NOT getting incremented 
                        -- (same for burst counter)
                        bram_addr_inc <= '0';
                        brst_cnt_dec <= '0';


                    end if; -- rd_adv_buf (RREADY throttle)





                ------------------------- LAST_ADDR State -------------------------

                when LAST_ADDR =>


                    -- Reach this state in the clock cycle following the last address 
                    -- presented to the BRAM. Capture the last BRAM data beat in the
                    -- next clock cycle.
                    --
                    -- Data is presented to AXI bus (if no throttling detected) and
                    -- loaded into the skid buffer.


                    -- If we reach this state after back to back burst transfers
                    -- then clear the flag to ensure that RVALID will clear when RLAST
                    -- is recognized
                    if (axi_b2b_brst = '1') then
                        axi_b2b_brst_cmb <= '0';
                    end if;




                    -- Clear flag that indicates end of read burst
                    -- Once we reach this state, we have recognized the burst complete.
                    --
                    -- It is getting asserted too early
                    -- and recognition of the end of the burst is missed when throttling
                    -- on the last two data beats in the read.
                    end_brst_rd_clr_cmb <= '1';


                    -- Set new flag for pending operation if ar_active is asserted (BRAM
                    -- address has already been loaded) and we are waiting for the current
                    -- read burst to complete.  If those two conditions apply, set this flag.

                    -- For dual port, support checking for early writes into BRAM address counter
                    
                    if (C_SINGLE_PORT_BRAM = 0) and ((ar_active = '1' and end_brst_rd = '1') or (bram_addr_ld_en = '1')) then
                    -- Support back-to-backs for single AND dual port modes.
                    
                    -- if ((ar_active = '1' and end_brst_rd = '1') or (bram_addr_ld_en = '1')) then
                    -- if (ar_active = '1' and end_brst_rd = '1') or (bram_addr_ld_en = '1') then
                        pend_rd_op_cmb <= '1';
                    end if;


                    -- Load read data skid buffer for BRAM is asserted on transition
                    -- into this state.  Only gets negated if done with operation
                    -- as detected in below if clause.


                    -- Check flag for no subsequent operations
                    -- Clear that now, with current operation completing
                    if (no_ar_ack = '1') then
                        no_ar_ack_cmb <= '0';
                    end if;


                    -- Check for single AXI read operations
                    -- If so, wait for RREADY to be asserted

                    -- Check for burst and bursts of two as seperate signals.
                    if (act_rd_burst = '0') and (act_rd_burst_two = '0') then


                        -- Create rvalid_set to only be asserted for a single clock
                        -- cycle.
                        -- Will get set as transitioning to LAST_ADDR on single read operations
                        -- Only assert RVALID here on single operations

                        -- Enable AXI read data register
                        axi_rdata_en <= '1';


                        -- Data will not yet be acknowledged on AXI
                        -- in this state.
                       
                        -- Go to wait for last data beat
                        rd_data_sm_ns <= LAST_DATA;

                        -- Set read data mux select for SKID BUF
                        rddata_mux_sel_cmb <= C_RDDATA_MUX_SKID_BUF;



                    else

                        -- Only check throttling on AXI during read data burst operations

                        -- Check AXI throttling condition
                        -- If AXI bus advances and accepts read data, SM can
                        -- proceed with next data beat.
                        -- If not, then go to LAST_THROTTLE state to wait for
                        -- AXI_RREADY = '1'.

                        if (rd_adv_buf = '1') then


                            -- Assert AXI read data enable for BRAM capture 
                            -- in next clock cycle

                            -- Enable AXI read data register
                            axi_rdata_en <= '1';

                            -- Ensure read data mux is set for BRAM data
                            rddata_mux_sel_cmb <= C_RDDATA_MUX_BRAM;



                            -- Burst counter already at zero.  Reached this state due to NO 
                            -- pending ARADDR in the read address pipeline.  However, check
                            -- here for any new read addresses.

                            -- New ARADDR detected and loaded into BRAM address counter

                            -- Add check here for previously loaded BRAM address
                            -- ar_active will be asserted (and qualify that with the
                            -- condition that the read burst is complete, for narrow reads).

                            if (bram_addr_ld_en = '1') then

                                -- Initiate BRAM read transfer
                                bram_en_cmb <= '1';


                                -- Instead of transitioning to SNG_ADDR
                                -- go to wait for last data beat.
                                rd_data_sm_ns <= LAST_DATA_AR_PEND;


                            else

                                -- No pending read address to initiate next read burst
                                -- Go to capture last data beat from BRAM and present on AXI bus.                
                                rd_data_sm_ns <= LAST_DATA;


                            end if; -- bram_addr_ld_en (New read burst)


                        else

                            -- Throttling condition detected                    
                            rd_data_sm_ns <= LAST_THROTTLE;

                            -- Ensure that AXI read data output register is disabled
                            -- due to throttle condition.
                            axi_rdata_en <= '0';                        


                            -- Skid buffer gets loaded from BRAM read data in next clock
                            -- cycle ONLY.
                            -- Only on transition to THROTTLE state does skid buffer get loaded.

                            -- Set read data mux select for SKID BUF
                            rddata_mux_sel_cmb <= C_RDDATA_MUX_SKID_BUF;


                        end if; -- rd_adv_buf (RREADY throttle)

                    end if; -- AXI read burst



                ------------------------- LAST_THROTTLE State ---------------------

                when LAST_THROTTLE =>


                    -- Reach this state when the AXI bus throttles on the last data
                    -- beat read from BRAM
                    -- Data to be sourced from read skid buffer


                    -- Add check in LAST_THROTTLE as well as LAST_ADDR
                    -- as we may miss the setting of this flag for a subsequent operation.
                    
                    -- For dual port, support checking for early writes into BRAM address counter
                    if (C_SINGLE_PORT_BRAM = 0) and ((ar_active = '1' and end_brst_rd = '1') or (bram_addr_ld_en = '1')) then
                    
                    -- Support back-to-back for single AND dual port modes.
                    -- if ((ar_active = '1' and end_brst_rd = '1') or (bram_addr_ld_en = '1')) then
                        pend_rd_op_cmb <= '1';
                    end if;



                    -- Wait for RREADY to be asserted w/ RVALID on AXI bus
                    if (rd_adv_buf = '1') then


                        -- Assert AXI read data enable for BRAM capture 
                        axi_rdata_en <= '1';

                        -- Set read data mux select for SKID BUF
                        rddata_mux_sel_cmb <= C_RDDATA_MUX_SKID_BUF;

                        -- No pending read address to initiate next read burst
                        -- Go to capture last data beat from BRAM and present on AXI bus.                
                        rd_data_sm_ns <= LAST_DATA;

                        -- Load read data skid buffer for BRAM capture in next clock cycle 
                        -- of last data read

                        -- Read Skid buffer already loaded with last data beat from BRAM
                        -- Does not need to be asserted again in this state


                    else

                        -- Stay in this state
                        -- Ensure that AXI read data output register is disabled
                        axi_rdata_en <= '0';

                        -- Ensure that skid buffer is not getting loaded with
                        -- current read data from BRAM
                        rd_skid_buf_ld_cmb <= '0';

                        -- BRAM address is NOT getting incremented 
                        -- (same for burst counter)
                        bram_addr_inc <= '0';
                        brst_cnt_dec <= '0';


                        -- Keep RVALID asserted on AXI
                        -- No need to assert RVALID again


                    end if; -- rd_adv_buf (RREADY throttle)




                ------------------------- LAST_DATA State -------------------------

                when LAST_DATA =>


                    -- Reach this state when last BRAM data beat is
                    -- presented on AXI bus.

                    -- For a read burst, RLAST is not asserted until SM reaches
                    -- this state.


                    -- Ok to accept new operation if throttling detected
                    -- during current operation (and flag was previously set
                    -- to disable the back-to-back performance).
                    disable_b2b_brst_cmb <= '0';



                    -- Stay in this state until RREADY is asserted on AXI bus
                    -- Indicated by assertion of rd_adv_buf
                    if (rd_adv_buf = '1') then


                        -- Last data beat acknowledged on AXI bus                    
                        -- Check for new read burst or proceed back to IDLE
                        -- New ARADDR detected and loaded into BRAM address counter

                        -- Note: this condition may occur when C_SINGLE_PORT_BRAM = 0 or 1

                        if (bram_addr_ld_en = '1') or (pend_rd_op = '1') then

                            -- Clear flag once pending read is recognized
                            if (pend_rd_op = '1') then
                                pend_rd_op_cmb <= '0';
                            end if;

                            -- Initiate BRAM read transfer
                            bram_en_cmb <= '1';

                            -- Only count addresses & burst length for read
                            -- burst operations


                            -- Go to SNG_ADDR state
                            rd_data_sm_ns <= SNG_ADDR;


                            -- If current operation was a burst, clear the active
                            -- burst flag
                            if (act_rd_burst = '1') or (act_rd_burst_two = '1') then
                                act_rd_burst_clr <= '1';
                            end if;


                            -- If we are loading the BRAM, then we have to view the curr_arlen
                            -- signal to determine if the next operation is a single transfer.
                            -- Or if the BRAM address counter is already loaded (and we reach
                            -- this if clause due to pend_rd_op then the axi_* signals will indicate
                            -- if the next operation is a burst or not.
                            -- If the operation is a single transaction, then set the last_bram_addr
                            -- signal when we reach SNG_ADDR.

                            if (bram_addr_ld_en = '1') then

                                if (curr_arlen = AXI_ARLEN_ONE) then

                                    -- Set flag for last_bram_addr on transition
                                    -- to SNG_ADDR on single operations.
                                    set_last_bram_addr <= '1';

                                end if;

                            elsif (pend_rd_op = '1') then

                                if (axi_rd_burst = '0' and axi_rd_burst_two = '0') then                            
                                    set_last_bram_addr <= '1';
                                end if;

                            end if;



                        else

                            -- No pending read address to initiate next read burst.
                            -- Go to IDLE                
                            rd_data_sm_ns <= IDLE;

                            -- If current operation was a burst, clear the active
                            -- burst flag
                            if (act_rd_burst = '1') or (act_rd_burst_two = '1') then
                                act_rd_burst_clr <= '1';
                            end if;

                        end if;

                    else


                        -- Throttling condition detected                    

                        -- Ensure that AXI read data output register is disabled
                        -- due to throttle condition.
                        axi_rdata_en <= '0';



                        -- If new ARADDR detected and loaded into BRAM address counter
                        if (bram_addr_ld_en = '1') then

                            -- Initiate BRAM read transfer
                            bram_en_cmb <= '1';

                            -- Only count addresses & burst length for read
                            -- burst operations


                            -- Instead of transitioning to SNG_ADDR
                            -- to wait for last data beat.
                            rd_data_sm_ns <= LAST_DATA_AR_PEND;


                            -- For singles, block any subsequent loads into BRAM address
                            -- counter from AR SM
                            no_ar_ack_cmb <= '1';


                        end if;


                    end if; -- rd_adv_buf (RREADY throttle)



                ------------------------ LAST_DATA_AR_PEND --------------------

                when LAST_DATA_AR_PEND => 


                    -- Ok to accept new operation if throttling detected
                    -- during current operation (and flag was previously set
                    -- to disable the back-to-back performance).
                    disable_b2b_brst_cmb <= '0';


                    -- Reach this state when new BRAM address is loaded into
                    -- BRAM address counter
                    -- But waiting for last RREADY/RVALID/RLAST to be asserted
                    -- Once this occurs, continue with pending AR operation

                    if (rd_adv_buf = '1') then

                        -- Go to SNG_ADDR state
                        rd_data_sm_ns <= SNG_ADDR;


                        -- If current operation was a burst, clear the active
                        -- burst flag

                        if (act_rd_burst = '1') or (act_rd_burst_two = '1') then
                            act_rd_burst_clr <= '1';
                        end if;


                        -- In this state, the BRAM address counter is already loaded,
                        -- the axi_rd_burst and axi_rd_burst_two signals will indicate
                        -- if the next operation is a burst or not.
                        -- If the operation is a single transaction, then set the last_bram_addr
                        -- signal when we reach SNG_ADDR.

                        if (axi_rd_burst = '0' and axi_rd_burst_two = '0') then                            
                            set_last_bram_addr <= '1';
                        end if;


                        -- Code coverage tests are reporting that reaching this state
                        -- always when axi_rd_burst = '0' and axi_rd_burst_two = '0',
                        -- so no bursting operations.


                    end if;


        --coverage off
                ------------------------------ Default ----------------------------
                when others =>
                    rd_data_sm_ns <= IDLE;
        --coverage on

        end case;

    end process RD_DATA_SM_CMB_PROCESS;
    

    ---------------------------------------------------------------------------

    RD_DATA_SM_REG_PROCESS: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                rd_data_sm_cs <= IDLE;
                bram_en_int <= '0';

                rd_skid_buf_ld_reg <= '0';
                rddata_mux_sel <= C_RDDATA_MUX_BRAM;

                axi_rvalid_set <= '0';
                end_brst_rd_clr <= '0';
                no_ar_ack <= '0';
                pend_rd_op <= '0';

                axi_b2b_brst <= '0';                            
                disable_b2b_brst <= '0';   
                
            else
                rd_data_sm_cs <= rd_data_sm_ns;
                bram_en_int <= bram_en_cmb;

                rd_skid_buf_ld_reg <= rd_skid_buf_ld_cmb;
                rddata_mux_sel <= rddata_mux_sel_cmb;

                axi_rvalid_set <= axi_rvalid_set_cmb;
                end_brst_rd_clr <= end_brst_rd_clr_cmb;
                no_ar_ack <= no_ar_ack_cmb;
                pend_rd_op <= pend_rd_op_cmb;

                axi_b2b_brst <= axi_b2b_brst_cmb;
                disable_b2b_brst <= disable_b2b_brst_cmb;

            end if;
        end if;

    end process RD_DATA_SM_REG_PROCESS;


    ---------------------------------------------------------------------------





    ---------------------------------------------------------------------------


    -- Create seperate registered process for last_bram_addr signal.
    -- Only asserted for a single clock cycle
    -- Gets set when the burst counter is loaded with 0's (for a single data beat operation)
    -- (indicated by set_last_bram_addr from DATA SM)
    -- or when the burst counter is decrement and the current value = 1


    REG_LAST_BRAM_ADDR: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                last_bram_addr <= '0';

            -- The signal, set_last_bram_addr, is asserted when the DATA SM transitions to SNG_ADDR
            -- on a single data beat burst.  Can not use condition of loading burst counter
            -- with the value of 0's (as the burst counter may be loaded during prior single operation
            -- when waiting on last throttle/data beat, ie. rd_adv_buf not yet asserted).

            elsif (set_last_bram_addr = '1') or 

                   -- On burst operations at the last BRAM address presented to BRAM
                  (brst_cnt_dec = '1' and brst_cnt = C_BRST_CNT_ONE) then                  
                last_bram_addr <= '1';
            else
                last_bram_addr <= '0';
            end if;
        end if;

    end process REG_LAST_BRAM_ADDR;


    ---------------------------------------------------------------------------






    ---------------------------------------------------------------------------
    --
    -- *** AXI Read Data Channel Interface ***
    --
    ---------------------------------------------------------------------------

    rd_skid_buf_ld <= rd_skid_buf_ld_reg or rd_skid_buf_ld_imm;


    ---------------------------------------------------------------------------
    -- Generate:        GEN_RDATA_NO_ECC
    -- Purpose:         Generation of AXI_RDATA output register without ECC
    --                  logic (C_ECC = 0 parameterization in design)
    ---------------------------------------------------------------------------
 
    GEN_RDATA_NO_ECC: if C_ECC = 0 generate
    signal axi_rdata_int    : std_logic_vector (C_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
    begin

        ---------------------------------------------------------------------------
        -- AXI RdData Skid Buffer/Register
        -- Sized according to size of AXI/BRAM data width
        ---------------------------------------------------------------------------
        
        REG_RD_BUF: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    rd_skid_buf <= (others => '0');

                -- Add immediate load of read skid buffer
                -- Occurs in the case when at full throttle and RREADY/RVALID are asserted
                elsif (rd_skid_buf_ld = '1') then
                    rd_skid_buf <= BRAM_RdData (C_AXI_DATA_WIDTH-1 downto 0);
                else
                    rd_skid_buf <= rd_skid_buf;
                end if;
            end if;

        end process REG_RD_BUF;


        -- Rd Data Mux (selects between skid buffer and BRAM read data)
        -- Select control signal from SM determines register load value
        axi_rdata_mux <= BRAM_RdData (C_AXI_DATA_WIDTH-1 downto 0) when (rddata_mux_sel = C_RDDATA_MUX_BRAM) else
                         rd_skid_buf;


        ---------------------------------------------------------------------------
        -- Generate:        GEN_RDATA
        -- Purpose:         Generate each bit of AXI_RDATA.
        ---------------------------------------------------------------------------
        GEN_RDATA: for i in C_AXI_DATA_WIDTH-1 downto 0 generate
        begin

            REG_RDATA: process (S_AXI_AClk)
            begin

                if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                    -- Clear output after last data beat accepted by requesting AXI master
                    if (S_AXI_AResetn = C_RESET_ACTIVE) or 

                    -- Don't clear RDDATA when a back to back burst is occuring on RLAST & RVALID assertion
                    -- For improved code coverage, can remove the signal, axi_rvalid_int from this if clause.  
                    -- It will always be asserted in this case.
                    
                       (axi_rlast_int = '1' and AXI_RREADY = '1' and axi_b2b_brst = '0') then
                        axi_rdata_int (i) <= '0';

                    elsif (axi_rdata_en = '1') then
                        axi_rdata_int (i) <= axi_rdata_mux (i);

                    else
                        axi_rdata_int (i) <= axi_rdata_int (i);
                    end if;
                end if;

            end process REG_RDATA;


        end generate GEN_RDATA;
        
              
        -- If C_ECC = 0, direct output assignment to AXI_RDATA
        AXI_RDATA <= axi_rdata_int;



    end generate GEN_RDATA_NO_ECC;

    ---------------------------------------------------------------------------




    ---------------------------------------------------------------------------
    -- Generate:        GEN_RDATA_ECC
    -- Purpose:         Generation of AXI_RDATA output register when ECC
    --                  logic is enabled (C_ECC = 1 parameterization in design)
    ---------------------------------------------------------------------------
 
    GEN_RDATA_ECC: if C_ECC = 1 generate
       
    subtype syndrome_bits is std_logic_vector(0 to C_INT_ECC_WIDTH-1);
    -- 0:6 for 32-bit ECC
    -- 0:7 for 64-bit ECC

    type correct_data_table_type is array (natural range 0 to C_AXI_DATA_WIDTH-1) of syndrome_bits;
   
    signal rd_skid_buf_i        : std_logic_vector (C_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
    signal axi_rdata_int        : std_logic_vector (C_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
    signal axi_rdata_int_corr   : std_logic_vector (C_AXI_DATA_WIDTH-1 downto 0) := (others => '0'); 

    begin



        -- Remove GEN_RD_BUF that was doing bit reversal.
        -- Replace with direct register assignments.  Sized according to AXI data width.
        
        REG_RD_BUF: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    rd_skid_buf_i <= (others => '0');

                -- Add immediate load of read skid buffer
                -- Occurs in the case when at full throttle and RREADY/RVALID are asserted
                elsif (rd_skid_buf_ld = '1') then
                    rd_skid_buf_i (C_AXI_DATA_WIDTH-1 downto 0) <= UnCorrectedRdData (0 to C_AXI_DATA_WIDTH-1);
                else
                    rd_skid_buf_i <= rd_skid_buf_i;
                end if;
            end if;

        end process REG_RD_BUF;



        -- Rd Data Mux (selects between skid buffer and BRAM read data)
        -- Select control signal from SM determines register load value
        -- axi_rdata_mux holds data + ECC bits.
        -- Previous mux on input to checkbit_handler logic.
        -- Removed now (mux inserted after checkbit_handler logic before register stage)
        --
        -- axi_rdata_mux <= BRAM_RdData (C_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0) when (rddata_mux_sel = C_RDDATA_MUX_BRAM) else
        --                  rd_skid_buf_i;


        -- Remove GEN_RDATA that was doing bit reversal.

        REG_RDATA: process (S_AXI_AClk)
        begin
            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   (axi_rlast_int = '1' and AXI_RREADY = '1' and axi_b2b_brst = '0') then
                    axi_rdata_int <= (others => '0');

                elsif (axi_rdata_en = '1') then
                
                    -- Track uncorrected data vector with AXI RDATA output pipeline                   
                    -- Mimic mux logic here (from previous post checkbit XOR logic register)
                    if (rddata_mux_sel = C_RDDATA_MUX_BRAM) then
                        axi_rdata_int (C_AXI_DATA_WIDTH-1 downto 0) <= UnCorrectedRdData (0 to C_AXI_DATA_WIDTH-1);
                    else
                        axi_rdata_int <= rd_skid_buf_i;
                    end if; 
               
                else
                    axi_rdata_int <= axi_rdata_int;
                end if;
            end if;
        end process REG_RDATA;
                  
        
        -- When C_ECC = 1, correct any single bit errors on output read data.
        -- Post register stage to improve timing on ECC logic data path.
        -- Use registers in AXI Interconnect IP core.
        -- Perform bit swapping on output of correct_one_bit 
        -- module (axi_rdata_int_corr signal).
        -- AXI_RDATA (i) <= axi_rdata_int (i) when (Enable_ECC = '0') 
        --                                 else axi_rdata_int_corr (C_AXI_DATA_WIDTH-1-i);

        
        -- Found in HW debug
        -- axi_rdata_int is reversed to be returned on AXI bus.
        -- AXI_RDATA (i) <= axi_rdata_int (C_AXI_DATA_WIDTH-1-i) when (Enable_ECC = '0') 
        --                                 else axi_rdata_int_corr (C_AXI_DATA_WIDTH-1-i);


        -- Remove bit reversal on AXI_RDATA output.
        AXI_RDATA <= axi_rdata_int when (Enable_ECC = '0' or Sl_UE_i = '1') else axi_rdata_int_corr;




        -- v1.03a
        
        ------------------------------------------------------------------------
        -- Generate:     GEN_HAMMING_ECC_CORR
        --
        -- Purpose:      Determine type of ECC encoding.  Hsiao or Hamming.  
        --               Add parameter/generate level.
        --               Generate statements to correct BRAM read data 
        --               dependent on ECC type.
        ------------------------------------------------------------------------
        GEN_HAMMING_ECC_CORR: if C_ECC_TYPE = 0 generate
        begin


            ------------------------------------------------------------------------
            -- Generate:  CHK_ECC_32
            -- Purpose:   Check ECC data unique for 32-bit BRAM.
            ------------------------------------------------------------------------
            CHK_ECC_32: if C_AXI_DATA_WIDTH = 32 generate

            constant correct_data_table_32 : correct_data_table_type := (
              0 => "1100001",  1 => "1010001",  2 => "0110001",  3 => "1110001",
              4 => "1001001",  5 => "0101001",  6 => "1101001",  7 => "0011001",
              8 => "1011001",  9 => "0111001",  10 => "1111001",  11 => "1000101",
              12 => "0100101",  13 => "1100101",  14 => "0010101",  15 => "1010101",
              16 => "0110101",  17 => "1110101",  18 => "0001101",  19 => "1001101",
              20 => "0101101",  21 => "1101101",  22 => "0011101",  23 => "1011101",
              24 => "0111101",  25 => "1111101",  26 => "1000011",  27 => "0100011",
              28 => "1100011",  29 => "0010011",  30 => "1010011",  31 => "0110011"
              );

            signal syndrome_4_reg : std_logic_vector (0 to 1) := (others => '0');           -- Only used in 32-bit ECC
            signal syndrome_6_reg : std_logic_vector (0 to 5)  := (others => '0');            -- Specific for 32-bit ECC

            begin
                ---------------------------------------------------------------------------

                -- Register ECC syndrome value to correct any single bit errors
                -- post-register on AXI read data.

                REG_SYNDROME: process (S_AXI_AClk)
                begin        
                    if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then  

                        if (S_AXI_AResetn = C_RESET_ACTIVE) then
                            syndrome_reg <= (others => '0');
                            syndrome_4_reg <= (others => '0');
                            syndrome_6_reg <= (others => '0');

                        -- Align register stage of syndrome with AXI read data pipeline
                        elsif (axi_rdata_en = '1') then
                            syndrome_reg <= Syndrome; 
                            syndrome_4_reg <= Syndrome_4;
                            syndrome_6_reg <= Syndrome_6;
                        else
                            syndrome_reg <= syndrome_reg;
                            syndrome_4_reg <= syndrome_4_reg;
                            syndrome_6_reg <= syndrome_6_reg;
                        end if;
                    end if;

                end process REG_SYNDROME;


                ---------------------------------------------------------------------------

                -- Do last XOR on specific syndrome bits after pipeline stage before 
                -- correct_one_bit module.

                syndrome_reg_i (0 to 3) <= syndrome_reg (0 to 3);

                PARITY_CHK4: entity work.parity
                generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 2)
                port map (
                  InA   =>  syndrome_4_reg (0 to 1),                        -- [in  std_logic_vector(0 to C_SIZE - 1)]
                  Res   =>  syndrome_reg_i (4) );                           -- [out std_logic]

                syndrome_reg_i (5) <= syndrome_reg (5);

                PARITY_CHK6: entity work.parity
                generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
                port map (
                  InA   =>  syndrome_6_reg (0 to 5),                        -- [in  std_logic_vector(0 to C_SIZE - 1)]
                  Res   =>  syndrome_reg_i (6) );                           -- [out std_logic]



                ---------------------------------------------------------------------------
                -- Generate: GEN_CORR_32
                -- Purpose:  Generate corrected read data based on syndrome value.
                --           All vectors oriented (0:N)
                ---------------------------------------------------------------------------
                GEN_CORR_32: for i in 0 to C_AXI_DATA_WIDTH-1 generate
                begin

                    -----------------------------------------------------------------------
                    -- Instance:        CORR_ONE_BIT_32
                    -- Description:     Correct output read data based on syndrome vector.
                    --                  A single error can be corrected by decoding the
                    --                  syndrome value.
                    --                  Input signal is declared (N:0).
                    --                  Output signal is (N:0).
                    --                  In order to reuse correct_one_bit module,
                    --                  the single data bit correction is done LSB to MSB
                    --                  in generate statement loop.
                    -----------------------------------------------------------------------

                    CORR_ONE_BIT_32: entity work.correct_one_bit
                    generic map (
                        C_USE_LUT6    => C_USE_LUT6,
						Correct_Value => correct_data_table_32 (i))   
                    port map (
					    DIn           => axi_rdata_int (31-i),   -- This is to match with LMB Controller Hamming Encoder logic (Bit Reversal)
                        Syndrome      => syndrome_reg_i,
                        DCorr         => axi_rdata_int_corr (31-i));  -- This is to match with LMB Controller Hamming Encoder logic (Bit Reversal)

                end generate GEN_CORR_32;


            end generate CHK_ECC_32;


            ------------------------------------------------------------------------
            -- Generate:  CHK_ECC_64
            -- Purpose:   Check ECC data unique for 64-bit BRAM.
            ------------------------------------------------------------------------
            CHK_ECC_64: if C_AXI_DATA_WIDTH = 64 generate

            constant correct_data_table_64 : correct_data_table_type := (
              0 => "11000001",  1 => "10100001",  2 => "01100001",  3 => "11100001",
              4 => "10010001",  5 => "01010001",  6 => "11010001",  7 => "00110001",
              8 => "10110001",  9 => "01110001",  10 => "11110001",  11 => "10001001",
              12 => "01001001",  13 => "11001001",  14 => "00101001",  15 => "10101001",
              16 => "01101001",  17 => "11101001",  18 => "00011001",  19 => "10011001",
              20 => "01011001",  21 => "11011001",  22 => "00111001",  23 => "10111001",
              24 => "01111001",  25 => "11111001",  26 => "10000101",  27 => "01000101",
              28 => "11000101",  29 => "00100101",  30 => "10100101",  31 => "01100101",
              32 => "11100101",  33 => "00010101",  34 => "10010101",  35 => "01010101",
              36 => "11010101",  37 => "00110101",  38 => "10110101",  39 => "01110101",
              40 => "11110101",  41 => "00001101",  42 => "10001101",  43 => "01001101",
              44 => "11001101",  45 => "00101101",  46 => "10101101",  47 => "01101101",      
              48 => "11101101",  49 => "00011101",  50 => "10011101",  51 => "01011101",
              52 => "11011101",  53 => "00111101",  54 => "10111101",  55 => "01111101",
              56 => "11111101",  57 => "10000011",  58 => "01000011",  59 => "11000011",
              60 => "00100011",  61 => "10100011",  62 => "01100011",  63 => "11100011"
              );

            signal syndrome_7_reg       : std_logic_vector (0 to 11) := (others => '0');           -- Specific for 64-bit ECC
            signal syndrome_7_a         : std_logic;
            signal syndrome_7_b         : std_logic;
            begin


                ---------------------------------------------------------------------------

                -- Register ECC syndrome value to correct any single bit errors
                -- post-register on AXI read data.

                REG_SYNDROME: process (S_AXI_AClk)
                begin        
                    if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then  

                        -- Align register stage of syndrome with AXI read data pipeline
                        if (axi_rdata_en = '1') then
                            syndrome_reg <= Syndrome; 
                            syndrome_7_reg <= Syndrome_7;

                        else
                            syndrome_reg <= syndrome_reg;
                            syndrome_7_reg <= syndrome_7_reg;
                        end if;
                    end if;

                end process REG_SYNDROME;


                ---------------------------------------------------------------------------

                -- Do last XOR on select syndrome bits after pipeline stage 
                -- before correct_one_bit_64 module.

                PARITY_CHK7_A: entity work.parity
                generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
                port map (
                  InA   =>  syndrome_7_reg (0 to 5),                 -- [in  std_logic_vector(0 to C_SIZE - 1)]
                  Res   =>  syndrome_7_a );                          -- [out std_logic]

                PARITY_CHK7_B: entity work.parity
                generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
                port map (
                  InA   =>  syndrome_7_reg (6 to 11),                -- [in  std_logic_vector(0 to C_SIZE - 1)]
                  Res   =>  syndrome_7_b );                          -- [out std_logic]


                -- Do last XOR on Syndrome MSB after pipeline stage before correct_one_bit module
                -- PASSES:      syndrome_reg_i (7) <= syndrome_reg (7) xor syndrome_7_b_reg;    
                syndrome_reg_i (7) <= syndrome_7_a xor syndrome_7_b;    
                syndrome_reg_i (0 to 6) <= syndrome_reg (0 to 6);


                ---------------------------------------------------------------------------
                -- Generate: GEN_CORR_64
                -- Purpose:  Generate corrected read data based on syndrome value.
                --           All vectors oriented (0:N)
                ---------------------------------------------------------------------------
                GEN_CORR_64: for i in 0 to C_AXI_DATA_WIDTH-1 generate
                begin

                    -----------------------------------------------------------------------
                    -- Instance:        CORR_ONE_BIT_64
                    -- Description:     Correct output read data based on syndrome vector.
                    --                  A single error can be corrected by decoding the
                    --                  syndrome value.
                    -----------------------------------------------------------------------

                    CORR_ONE_BIT_64: entity work.correct_one_bit_64
                    generic map (
                        C_USE_LUT6    => C_USE_LUT6,
                        Correct_Value => correct_data_table_64 (i))
                    port map (
                        DIn           => axi_rdata_int (i),
                        Syndrome      => syndrome_reg_i,
                        DCorr         => axi_rdata_int_corr (i));

                end generate GEN_CORR_64;

            end generate CHK_ECC_64;


        end generate GEN_HAMMING_ECC_CORR;




        -- v1.03a
        
        ------------------------------------------------------------------------
        -- Generate:     GEN_HSIAO_ECC_CORR
        --
        -- Purpose:      Determine type of ECC encoding.  Hsiao or Hamming.  
        --               Add parameter/generate level.
        --               Derived from MIG v3.7 Hsiao HDL.
        --               Generate statements to correct BRAM read data 
        --               dependent on ECC type.
        ------------------------------------------------------------------------
        GEN_HSIAO_ECC_CORR: if C_ECC_TYPE = 1 generate

        type type_int0 is array (C_AXI_DATA_WIDTH - 1 downto 0) of std_logic_vector (ECC_WIDTH - 1 downto 0);

        signal h_matrix     : type_int0;
        signal flip_bits    : std_logic_vector(C_AXI_DATA_WIDTH - 1 downto 0);
        signal ecc_rddata_r : std_logic_vector(C_AXI_DATA_WIDTH - 1 downto 0);

        begin


            -- Reconstruct H-matrix
            H_COL: for n in 0 to C_AXI_DATA_WIDTH - 1 generate
            begin
                H_BIT: for p in 0 to  ECC_WIDTH - 1 generate
                begin
                    h_matrix (n)(p) <=  h_rows (p * CODE_WIDTH + n);
                end generate H_BIT;
            end generate H_COL;
 
            
            -- Based on syndrome value, determine bits to flip in BRAM read data.
            GEN_FLIP_BIT: for r in 0 to C_AXI_DATA_WIDTH - 1 generate
            begin
               flip_bits (r) <= BOOLEAN_TO_STD_LOGIC (h_matrix (r) = syndrome_r);
            end generate GEN_FLIP_BIT;

            ecc_rddata_r <= axi_rdata_int;            

            axi_rdata_int_corr (C_AXI_DATA_WIDTH-1 downto 0) <= -- UnCorrectedRdData (0 to C_AXI_DATA_WIDTH-1) xor
                                                                ecc_rddata_r (C_AXI_DATA_WIDTH-1 downto 0) xor
                                                                flip_bits (C_AXI_DATA_WIDTH-1 downto 0);

       
       
        end generate GEN_HSIAO_ECC_CORR;



    end generate GEN_RDATA_ECC;
    
    
    ---------------------------------------------------------------------------
    
    



    ---------------------------------------------------------------------------
    -- Generate:    GEN_RID_SNG
    -- Purpose:     Generate RID output pipeline when the core is configured
    --              in a single port mode.
    ---------------------------------------------------------------------------
    
    GEN_RID_SNG: if (C_SINGLE_PORT_BRAM = 1) generate
    begin
    
        REG_RID_TEMP: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    axi_rid_temp <= (others => '0');

                elsif (bram_addr_ld_en = '1') then            
                    axi_rid_temp <= AXI_ARID;
                else
                    axi_rid_temp <= axi_rid_temp;
                end if;
            end if;
        end process REG_RID_TEMP;


        REG_RID: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   (axi_rlast_int = '1' and AXI_RREADY = '1') then
                    axi_rid_int <= (others => '0');

                elsif (bram_addr_ld_en = '1') then            
                    axi_rid_int <= AXI_ARID;

                elsif (axi_rvalid_set = '1') or (axi_b2b_rid_adv = '1') then    
                    axi_rid_int <= axi_rid_temp;
                else
                    axi_rid_int <= axi_rid_int;            
                end if;

            end if;
        end process REG_RID;
        
        
        -- Advance RID pipeline values
        axi_b2b_rid_adv <= '1' when (axi_rlast_int = '1' and 
                                     AXI_RREADY = '1' and 
                                     axi_b2b_brst = '1') 
                                else '0'; 


    end generate GEN_RID_SNG;



    ---------------------------------------------------------------------------
    -- Generate:    GEN_RID
    -- Purpose:     Generate RID in dual port mode (with read address pipeline).
    ---------------------------------------------------------------------------
    
    GEN_RID: if (C_SINGLE_PORT_BRAM = 0) generate
    begin
    

        ---------------------------------------------------------------------------
        -- RID Output Register
        --
        -- Output RID value either comes from pipelined value or directly wrapped
        -- ARID value.  Determined by address pipeline usage.
        ---------------------------------------------------------------------------

        -- Create intermediate temporary RID output register
        REG_RID_TEMP: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    axi_rid_temp <= (others => '0');

                -- When BRAM address counter gets loaded
                -- Set output RID value based on address source
                elsif (bram_addr_ld_en = '1') and (axi_rid_temp_full = '0') then            

                    -- If BRAM address counter gets loaded directly from 
                    -- AXI bus, then save ARID value for wrapping to RID
                    if (araddr_pipe_sel = '0') then
                        axi_rid_temp <= AXI_ARID;

                    else
                        -- Use pipelined AWID value
                        axi_rid_temp <= axi_arid_pipe;
                    end if;

                -- Add condition to check for temp utilized (temp_full now = '0'), but a 
                -- pending RID is stored in temp2.  Must advance the pipeline.

                elsif ((axi_rvalid_set = '1' or axi_b2b_rid_adv = '1') and (axi_rid_temp2_full = '1')) or
                      (axi_rid_temp_full_fe = '1' and axi_rid_temp2_full = '1') then

                    axi_rid_temp <= axi_rid_temp2;
                else
                    axi_rid_temp <= axi_rid_temp;
                end if;
            end if;
        end process REG_RID_TEMP;




        -- Create flag that indicates if axi_rid_temp is full
        REG_RID_TEMP_FULL: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
                if (S_AXI_AResetn = C_RESET_ACTIVE) or 

                   (axi_rid_temp_full = '1' and 
                    (axi_rvalid_set = '1' or axi_b2b_rid_adv = '1') and 
                    axi_rid_temp2_full = '0') then

                    axi_rid_temp_full <= '0';

                elsif (bram_addr_ld_en = '1') or 

                      ((axi_rvalid_set = '1' or axi_b2b_rid_adv = '1') and (axi_rid_temp2_full = '1')) or     
                      (axi_rid_temp_full_fe = '1' and axi_rid_temp2_full = '1') then

                    axi_rid_temp_full <= '1';

                else
                    axi_rid_temp_full <= axi_rid_temp_full;

                end if;
            end if;
        end process REG_RID_TEMP_FULL;


        -- Create flag to detect falling edge of axi_rid_temp_full flag
        REG_RID_TEMP_FULL_D1: process (S_AXI_AClk)
        begin
            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    axi_rid_temp_full_d1 <= '0';
                else
                    axi_rid_temp_full_d1 <= axi_rid_temp_full;    
                end if;
            end if;
        end process REG_RID_TEMP_FULL_D1;


        axi_rid_temp_full_fe <= '1' when (axi_rid_temp_full = '0' and 
                                          axi_rid_temp_full_d1 = '1') else '0';


        ---------------------------------------------------------------------------


        -- Create intermediate temporary RID output register
        REG_RID_TEMP2: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    axi_rid_temp2 <= (others => '0');

                -- When BRAM address counter gets loaded
                -- Set output RID value based on address source
                elsif (bram_addr_ld_en = '1') and (axi_rid_temp_full = '1') then            

                    -- If BRAM address counter gets loaded directly from 
                    -- AXI bus, then save ARID value for wrapping to RID
                    if (araddr_pipe_sel = '0') then
                        axi_rid_temp2 <= AXI_ARID;
                    else
                        -- Use pipelined AWID value
                        axi_rid_temp2 <= axi_arid_pipe;
                    end if;
                else
                    axi_rid_temp2 <= axi_rid_temp2;

                end if;
            end if;
        end process REG_RID_TEMP2;


        -- Create flag that indicates if axi_rid_temp2 is full
        REG_RID_TEMP2_FULL: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   (axi_rid_temp2_full = '1' and (axi_rvalid_set = '1' or axi_b2b_rid_adv = '1')) or 
                   (axi_rid_temp_full_fe = '1' and axi_rid_temp2_full = '1') then

                    axi_rid_temp2_full <= '0';

                elsif (bram_addr_ld_en = '1') and (axi_rid_temp_full = '1') then            
                    axi_rid_temp2_full <= '1';
                else
                    axi_rid_temp2_full <= axi_rid_temp2_full;
                end if;
            end if;
        end process REG_RID_TEMP2_FULL;


        ---------------------------------------------------------------------------


        -- Output RID register is enabeld when RVALID is asserted on the AXI bus
        -- Clear RID when AXI_RLAST is asserted on AXI bus during handshaking sequence
        -- and recognized by AXI requesting master.

        REG_RID: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or 

                   -- For improved code coverage, can remove the signal, axi_rvalid_int from statement.
                   (axi_rlast_int = '1' and AXI_RREADY = '1' and axi_b2b_brst = '0') then
                    axi_rid_int <= (others => '0');

                -- Add back to back case to advance RID
                elsif (axi_rvalid_set = '1') or (axi_b2b_rid_adv = '1') then  
                    axi_rid_int <= axi_rid_temp;
                else
                    axi_rid_int <= axi_rid_int;            
                end if;

            end if;
        end process REG_RID;

        -- Advance RID pipeline values
        axi_b2b_rid_adv <= '1' when (axi_rlast_int = '1' and 
                                     AXI_RREADY = '1' and 
                                     axi_b2b_brst = '1') 
                                else '0'; 

    end generate GEN_RID;
    


    ---------------------------------------------------------------------------
    -- Generate:    GEN_RRESP
    -- Purpose:     Create register output unique when ECC is disabled.
    --              Only possible output value = OKAY response.
    ---------------------------------------------------------------------------
    GEN_RRESP: if C_ECC = 0 generate
    begin

        -----------------------------------------------------------------------
        -- AXI_RRESP Output Register
        --
        -- Set when RVALID is asserted on AXI bus.
        -- Clear when AXI_RLAST is asserted on AXI bus during handshaking 
        -- sequence and recognized by AXI requesting master.
        -----------------------------------------------------------------------
        REG_RRESP: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or 

                   -- For improved code coverage, remove signal, axi_rvalid_int, it will always be asserted.
                   (axi_rlast_int = '1' and AXI_RREADY = '1') then
                    axi_rresp_int <= (others => '0');

                elsif (axi_rvalid_set = '1') then
                    -- AXI BRAM only supports OK response for normal operations
                    -- Exclusive operations not yet supported              
                    axi_rresp_int <= RESP_OKAY;
                else
                    axi_rresp_int <= axi_rresp_int;

                end if;

            end if;

        end process REG_RRESP;

    end generate GEN_RRESP;



    ---------------------------------------------------------------------------
    -- Generate:    GEN_RRESP_ECC
    -- Purpose:     Create register output unique when ECC is disabled.
    --              Only possible output value = OKAY response.
    ---------------------------------------------------------------------------
    GEN_RRESP_ECC: if C_ECC = 1 generate
    begin

        -----------------------------------------------------------------------
        -- AXI_RRESP Output Register
        --
        -- Set when RVALID is asserted on AXI bus.
        -- Clear when AXI_RLAST is asserted on AXI bus during handshaking 
        -- sequence and recognized by AXI requesting master.
        -----------------------------------------------------------------------
        REG_RRESP: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or 

                   -- For improved code coverage, remove signal, axi_rvalid_int, it will always be asserted.
                   (axi_rlast_int = '1' and AXI_RREADY = '1') then
                    axi_rresp_int <= (others => '0');

                elsif (axi_rvalid_set = '1') then
                    -- AXI BRAM only supports OK response for normal operations
                    -- Exclusive operations not yet supported  
                    
                    -- For ECC implementation
                    -- Check that an uncorrectable error has not occured.
                    -- If so, then respond with RESP_SLVERR on AXI.
                    -- Ok to use combinatorial signal here.  The Sl_UE_i
                    -- flag is generated based on the registered syndrome value.
                    -- if (Sl_UE_i = '1') then
                    --     axi_rresp_int <= RESP_SLVERR;
                    -- else
                        axi_rresp_int <= RESP_OKAY;
                    -- end if;
                    
                else
                    axi_rresp_int <= axi_rresp_int;

                end if;

            end if;

        end process REG_RRESP;

    end generate GEN_RRESP_ECC;





    ---------------------------------------------------------------------------
    -- AXI_RVALID Output Register
    --
    -- Set AXI_RVALID when read data SM indicates.
    -- Clear when AXI_RLAST is asserted on AXI bus during handshaking sequence
    -- and recognized by AXI requesting master.
    ---------------------------------------------------------------------------

    REG_RVALID: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) or 


                -- Clear AXI_RVALID at the end of tranfer when able to clear
                -- (axi_rlast_int = '1' and axi_rvalid_int = '1' and AXI_RREADY = '1' and 
                -- For improved code coverage, remove signal axi_rvalid_int.
                (axi_rlast_int = '1' and AXI_RREADY = '1' and 

                -- Added axi_rvalid_clr_ok to check if during a back-to-back burst
                -- and the back-to-back is elgible for streaming performance
                axi_rvalid_clr_ok = '1') then
               
                axi_rvalid_int <= '0';
                
            elsif (axi_rvalid_set = '1') then
                axi_rvalid_int <= '1';
            else
                axi_rvalid_int <= axi_rvalid_int;
            
            end if;

        end if;

    end process REG_RVALID;



    -- Create flag that gets set when we load BRAM address early in a B2B scenario
    -- This will prevent the RVALID from getting cleared at the end of the current burst
    -- Otherwise, the RVALID gets cleared after RLAST/RREADY dual assertion
    

    REG_RVALID_CLR: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                axi_rvalid_clr_ok <= '0';

            -- When the new address loaded into the BRAM counter is for a back-to-back operation
            -- Do not clear the RVALID
            elsif (rd_b2b_elgible = '1' and bram_addr_ld_en = '1') then
                axi_rvalid_clr_ok <= '0';
            
            -- Else when we start a new transaction (that is not back-to-back)
            -- Then enable the RVALID to get cleared upon RLAST/RREADY

            elsif (bram_addr_ld_en = '1') or 

                  (axi_rvalid_clr_ok = '0' and 
                   (disable_b2b_brst = '1' or disable_b2b_brst_cmb = '1') and 
                   last_bram_addr = '1') or

                    -- Add check for current SM state
                    -- If LAST_ADDR state reached, no longer performing back-to-back
                    -- transfers and keeping data streaming on AXI bus.
                  (rd_data_sm_cs = LAST_ADDR) then
            
                axi_rvalid_clr_ok <= '1';
                
            else
                axi_rvalid_clr_ok <= axi_rvalid_clr_ok;            
            end if;
        end if;

    end process REG_RVALID_CLR;


    ---------------------------------------------------------------------------





    ---------------------------------------------------------------------------
    -- AXI_RLAST Output Register
    --
    -- Set AXI_RLAST when read data SM indicates.
    -- Clear when AXI_RLAST is asserted on AXI bus during handshaking sequence
    -- and recognized by AXI requesting master.
    ---------------------------------------------------------------------------

    REG_RLAST: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            -- To improve code coverage, remove
            -- use of axi_rvalid_int (it will always be asserted with RLAST).
            if (S_AXI_AResetn = C_RESET_ACTIVE) or 
               (axi_rlast_int = '1' and AXI_RREADY = '1' and axi_rlast_set = '0') then
                axi_rlast_int <= '0';

            elsif (axi_rlast_set = '1') then
                axi_rlast_int <= '1';
            else
                axi_rlast_int <= axi_rlast_int;

            end if;
        end if;

    end process REG_RLAST;



    
    ---------------------------------------------------------------------------
    
    -- Generate complete flag
    do_cmplt_burst_cmb <= '1' when (last_bram_addr = '1' and 
                                    axi_rd_burst = '1' and 
                                    axi_rd_burst_two = '0') else '0';
    
    -- Register complete flags  

    REG_CMPLT_BURST: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) or (do_cmplt_burst_clr = '1') then
                do_cmplt_burst <= '0';
            elsif (do_cmplt_burst_cmb = '1') then
                do_cmplt_burst <= '1';
            else
                do_cmplt_burst <= do_cmplt_burst;
            end if;

        end if;

    end process REG_CMPLT_BURST;
    

    ---------------------------------------------------------------------------





    ---------------------------------------------------------------------------
    -- RLAST State Machine
    --
    -- Description:     SM to generate axi_rlast_set signal.
    --                  Created based on IR # 555346 to track when RLAST needs 
    --                  to be asserted for back to back transfers
    --                  Uses the indication when last BRAM address is presented 
    --                  and then counts the handshaking cycles on the AXI bus 
    --                  (RVALID and RREADY both asserted).
    --                  Uses rd_adv_buf to perform this operation.
    --
    -- Output:          Name                        Type
    --                  axi_rlast_set               Not Registered
    --                  do_cmplt_burst_clr          Not Registered
    --
    --
    -- RLAST_SM_CMB_PROCESS:      Combinational process to determine next state.
    -- RLAST_SM_REG_PROCESS:      Registered process of the state machine.
    --
    ---------------------------------------------------------------------------
    RLAST_SM_CMB_PROCESS: process ( 
                                    do_cmplt_burst,                                    
                                    last_bram_addr,
                                    rd_adv_buf,                                    
                                    act_rd_burst,                                    
                                    axi_rd_burst,
                                    act_rd_burst_two,                                    
                                    axi_rd_burst_two,                                    
                                    axi_rlast_int,                                    
                                    rlast_sm_cs )

    begin

    -- assign default values for state machine outputs
    rlast_sm_ns <= rlast_sm_cs;
    axi_rlast_set <= '0';
    do_cmplt_burst_clr <= '0';    

    case rlast_sm_cs is
                       

            ---------------------------- IDLE State ---------------------------
            
            when IDLE =>

                -- If last read address is presented to BRAM
                if (last_bram_addr = '1') then
                    
                    -- If the operation is a single read operation
                    if (axi_rd_burst = '0') and (axi_rd_burst_two = '0') then
                        
                        -- Go to wait for last data beat
                        rlast_sm_ns <= W8_LAST_DATA;
                        
                    
                    -- Else the transaction is a burst
                    else
                    
                        -- Throttle condition on 3rd to last data beat
                        if (rd_adv_buf = '0') then
                        
                            -- If AXI read burst = 2 (only two data beats to capture)
                            if (axi_rd_burst_two = '1' or act_rd_burst_two = '1') then                         
                                rlast_sm_ns <= W8_THROTTLE_B2;                              
                                
                            else
                                rlast_sm_ns <= W8_THROTTLE;
                            end if;
                        
                        
                        -- No throttle on 3rd to last data beat
                        else
                                                    
                            -- Only back-to-back support when burst size is greater
                            -- than two data beats.  We will never toggle on a burst > 2
                            -- when last_bram_addr is asserted (as this is no toggle
                            -- condition)
                                                    
                            -- Go to wait for 2nd to last data beat
                            rlast_sm_ns <= W8_2ND_LAST_DATA;
                            
                            do_cmplt_burst_clr <= '1';
                            
                        end if;                        
                    end if;
                end if;



            ------------------------- W8_THROTTLE State -----------------------
            
            when W8_THROTTLE =>

                if (rd_adv_buf = '1') then
                                       
                    -- Go to wait for 2nd to last data beat
                    rlast_sm_ns <= W8_2ND_LAST_DATA;
                    
                    -- If do_cmplt_burst flag is set, then clear it
                    if (do_cmplt_burst = '1') then
                        do_cmplt_burst_clr <= '1';
                    end if;
                    
                            
                    
                end if;


            ---------------------- W8_2ND_LAST_DATA State ---------------------
            
            when W8_2ND_LAST_DATA =>
            
                if (rd_adv_buf = '1') then
                
                    -- Assert RLAST on AXI
                    axi_rlast_set <= '1';
                    rlast_sm_ns <= W8_LAST_DATA;  
                                        
                end if;


            ------------------------- W8_LAST_DATA State ----------------------
            
            when W8_LAST_DATA =>
                
                -- If pending single to complete, keep RLAST asserted

                -- Added to only assert axi_rlast_set for a single clock cycle
                -- when we enter this state and are here waiting for the
                -- throttle on the AXI bus.

                if (axi_rlast_int = '1') then
                    axi_rlast_set <= '0';
                else
                    axi_rlast_set <= '1';
                end if;


                -- Wait for last data beat to transition back to IDLE
                if (rd_adv_buf = '1') then               
                    rlast_sm_ns <= IDLE;          
                end if;
                
                
                
            -------------------------- W8_THROTTLE_B2 ------------------------
            
            when W8_THROTTLE_B2 =>
                
                -- Wait for last data beat to transition back to IDLE
                -- and set RLAST
                if (rd_adv_buf = '1') then                 
                    rlast_sm_ns <= IDLE; 
                    axi_rlast_set <= '1';
                end if;


    --coverage off
            ------------------------------ Default ----------------------------
            when others =>
                rlast_sm_ns <= IDLE;
    --coverage on

        end case;
        
    end process RLAST_SM_CMB_PROCESS;


    ---------------------------------------------------------------------------

    RLAST_SM_REG_PROCESS: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
        
            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                rlast_sm_cs <= IDLE;
            else
                rlast_sm_cs <= rlast_sm_ns;
            end if;
        end if;
        
    end process RLAST_SM_REG_PROCESS;


    ---------------------------------------------------------------------------












    ---------------------------------------------------------------------------
    -- *** ECC Logic ***
    ---------------------------------------------------------------------------



    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_ECC
    -- Purpose:     Generate BRAM ECC write data and check ECC on read operations.
    --              Create signals to update ECC registers (lite_ecc_reg module interface).
    --
    ---------------------------------------------------------------------------

    GEN_ECC: if C_ECC = 1 generate
        
    signal bram_din_a_i     : std_logic_vector(0 to C_AXI_DATA_WIDTH+C_ECC_WIDTH-1) := (others => '0'); -- Set for port data width
    signal CE_Q             : std_logic := '0';
    signal Sl_CE_i          : std_logic := '0';
    signal bram_en_int_d1   : std_logic := '0';
    signal bram_en_int_d2   : std_logic := '0';

    begin
    
        -- Generate signal to advance BRAM read address pipeline to
        -- capture address for ECC error conditions (in lite_ecc_reg module).
        -- BRAM_Addr_En <= bram_addr_inc or narrow_bram_addr_inc_re or 
        --                         ((bram_en_int or bram_en_int_reg) and not (axi_rd_burst) and not (axi_rd_burst_two));


        BRAM_Addr_En <= bram_addr_inc or narrow_bram_addr_inc_re or rd_adv_buf or
                                ((bram_en_int or bram_en_int_d1 or bram_en_int_d2) and not (axi_rd_burst) and not (axi_rd_burst_two));

    
        -- Enable 2nd & 3rd pipeline stage for BRAM address storage with single read transfers.
        BRAM_EN_REG: process(S_AXI_AClk) is
        begin
            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                bram_en_int_d1 <= bram_en_int;
                bram_en_int_d2 <= bram_en_int_d1;
            end if;
        end process BRAM_EN_REG;
        
    

        -- v1.03a
        
        ------------------------------------------------------------------------
        -- Generate:     GEN_HAMMING_ECC
        -- Purpose:      Determine type of ECC encoding.  Hsiao or Hamming.  
        --               Add parameter/generate level.
        ------------------------------------------------------------------------
        GEN_HAMMING_ECC: if C_ECC_TYPE = 0 generate
        begin


           ------------------------------------------------------------------------
           -- Generate:  GEN_ECC_32
           -- Purpose:   Check ECC data unique for 32-bit BRAM.
           --            Add extra '0' at MSB of ECC vector for data2mem alignment
           --            w/ 32-bit BRAM data widths.
           --            ECC bits are in upper order bits.
           ------------------------------------------------------------------------
           GEN_ECC_32: if C_AXI_DATA_WIDTH = 32 generate
            signal bram_din_a_rev            : std_logic_vector(31 downto 0) := (others => '0'); -- Specific to BRAM data width
            signal bram_din_ecc_a_rev            : std_logic_vector(6 downto 0) := (others => '0'); -- Specific to BRAM data width
           begin
			 

                ---------------------------------------------------------------------------
                -- Instance:        CHK_HANDLER_32
                -- Description:     Generate ECC bits for checking data read from BRAM.
                --                  All vectors oriented (0:N)
                ---------------------------------------------------------------------------
--			    process (bram_din_a_i) begin
--                for k in 0 to 31  loop
--				  bram_din_a_rev(k) <= bram_din_a_i(39-k);
--				end loop; 
--                for k in 0 to 6  loop
--				  bram_din_ecc_a_rev(0) <= bram_din_a_i(6-k);
--				end loop; 
--				end process;

                CHK_HANDLER_32: entity work.checkbit_handler
                  generic map (
                    C_ENCODE   => false,                 -- [boolean]
                    C_USE_LUT6 => C_USE_LUT6)            -- [boolean]
                  port map (

                    -- In 32-bit BRAM use case:     DataIn (8:39)
                    --                              CheckIn (1:7)
                    DataIn          => bram_din_a_i(C_INT_ECC_WIDTH+1 to C_INT_ECC_WIDTH+C_AXI_DATA_WIDTH),         -- [in  std_logic_vector(0 to 31)]
                    CheckIn         => bram_din_a_i(1 to C_INT_ECC_WIDTH),                                          -- [in  std_logic_vector(0 to 6)]
                    --DataIn          => bram_din_a_rev,         -- [in  std_logic_vector(0 to 31)]
                    --CheckIn         => bram_din_ecc_a_rev,                                          -- [in  std_logic_vector(0 to 6)]
                    CheckOut        => open,                                                                        -- [out std_logic_vector(0 to 6)]
                    Syndrome        => Syndrome,                                                                    -- [out std_logic_vector(0 to 6)]
                    Syndrome_4      => Syndrome_4,                                                                  -- [out std_logic_vector(0 to 1)]
                    Syndrome_6      => Syndrome_6,                                                                  -- [out std_logic_vector(0 to 5)]
                    Syndrome_Chk    => syndrome_reg_i,                                                              -- [out std_logic_vector(0 to 6)]
                    Enable_ECC      => Enable_ECC,                                                                  -- [in  std_logic]
                    UE_Q            => UE_Q,                                                                        -- [in  std_logic]
                    CE_Q            => CE_Q,                                                                        -- [in  std_logic]
                    UE              => Sl_UE_i,                                                                     -- [out std_logic]
                    CE              => Sl_CE_i );                                                                   -- [out std_logic]


                    -- GEN_CORR_32 generate & correct_one_bit instantiation moved to generate
                    -- of AXI RDATA output register logic.


            end generate GEN_ECC_32;       
            

           ------------------------------------------------------------------------
           -- Generate:  GEN_ECC_64
           -- Purpose:   Check ECC data unique for 64-bit BRAM.
           --            No extra '0' at MSB of ECC vector for data2mem alignment
           --            w/ 64-bit BRAM data widths.
           --            ECC bits are in upper order bits.
           ------------------------------------------------------------------------
           GEN_ECC_64: if C_AXI_DATA_WIDTH = 64 generate
           begin

                ---------------------------------------------------------------------------
                -- Instance:        CHK_HANDLER_64
                -- Description:     Generate ECC bits for checking data read from BRAM.
                --                  All vectors oriented (0:N)
                ---------------------------------------------------------------------------

                CHK_HANDLER_64: entity work.checkbit_handler_64
                  generic map (
                    C_ENCODE        =>  false,                 -- [boolean]
                    C_REG           =>  false,                 -- [boolean]
                    C_USE_LUT6      =>  C_USE_LUT6)            -- [boolean]
                  port map (
                    Clk             =>  S_AXI_AClk,                                                                  -- [in  std_logic]
                    -- In 64-bit BRAM use case:     DataIn (8:71)
                    --                              CheckIn (0:7)
                    DataIn          =>  bram_din_a_i (C_INT_ECC_WIDTH to C_INT_ECC_WIDTH+C_AXI_DATA_WIDTH-1),        -- [in  std_logic_vector(0 to 63)]
                    CheckIn         =>  bram_din_a_i (0 to C_INT_ECC_WIDTH-1),                                       -- [in  std_logic_vector(0 to 7)]

                    CheckOut        =>  open,                                                                        -- [out std_logic_vector(0 to 7)]
                    Syndrome        =>  Syndrome,                                                                    -- [out std_logic_vector(0 to 7)]
                    Syndrome_7      =>  Syndrome_7,
                    Syndrome_Chk    =>  syndrome_reg_i,                                                              -- [in  std_logic_vector(0 to 7)]
                    Enable_ECC      =>  Enable_ECC,                                                                  -- [in  std_logic]
                    UE_Q            =>  UE_Q,                                                                        -- [in  std_logic]
                    CE_Q            =>  CE_Q,                                                                        -- [in  std_logic]
                    UE              =>  Sl_UE_i,                                                                     -- [out std_logic]
                    CE              =>  Sl_CE_i );                                                                   -- [out std_logic]


                    -- GEN_CORR_64 generate & correct_one_bit instantiation moved to generate
                    -- of AXI RDATA output register logic.


            end generate GEN_ECC_64;
        
        
        end generate GEN_HAMMING_ECC;
        
 
 

        -- v1.03a

        ------------------------------------------------------------------------
        -- Generate:     GEN_HSIAO_ECC
        -- Purpose:      Determine type of ECC encoding.  Hsiao or Hamming.  
        --               Add parameter/generate level.
        --               Derived from MIG v3.7 Hsiao HDL.
        ------------------------------------------------------------------------
        GEN_HSIAO_ECC: if C_ECC_TYPE = 1 generate

        constant ECC_WIDTH  : integer := C_INT_ECC_WIDTH;
        signal syndrome_ns  : std_logic_vector (ECC_WIDTH - 1 downto 0) := (others => '0');

        begin
 
            -- Generate ECC check bits and syndrome values based on 
            -- BRAM read data.
            -- Generate appropriate single or double bit error flags.      
 
            
            -- Instantiate ecc_gen_hsiao module, generated from MIG
            I_ECC_GEN_HSIAO: entity work.ecc_gen
            generic map (
                code_width  => CODE_WIDTH,
                ecc_width   => ECC_WIDTH,
                data_width  => C_AXI_DATA_WIDTH
            )
            port map (
                -- Output
                h_rows  => h_rows (CODE_WIDTH * ECC_WIDTH - 1 downto 0)
            );
            

            GEN_RD_ECC: for m in 0 to ECC_WIDTH - 1 generate
            begin
                syndrome_ns (m) <= REDUCTION_XOR ( -- bram_din_a_i (0 to CODE_WIDTH-1) 
                                                   BRAM_RdData (CODE_WIDTH-1 downto 0)
                                                   and h_rows ((m*CODE_WIDTH)+CODE_WIDTH-1 downto (m*CODE_WIDTH)));
            end generate GEN_RD_ECC;

            -- Insert register stage for syndrome.
            -- Same as Hamming ECC code.  Syndrome value is registered.
            REG_SYNDROME: process (S_AXI_AClk)
            begin        
                if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then            
                    syndrome_r <= syndrome_ns;                    
                end if;
            end process REG_SYNDROME;


            Sl_CE_i <= not (REDUCTION_NOR (syndrome_r (ECC_WIDTH-1 downto 0))) and (REDUCTION_XOR (syndrome_r (ECC_WIDTH-1 downto 0)));
            Sl_UE_i <= not (REDUCTION_NOR (syndrome_r (ECC_WIDTH-1 downto 0))) and not(REDUCTION_XOR (syndrome_r (ECC_WIDTH-1 downto 0)));

 
        end generate GEN_HSIAO_ECC;
 
 
 
         -- Capture correctable/uncorrectable error from BRAM read
         CORR_REG: process(S_AXI_AClk) is
         begin
             if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                 if (Enable_ECC = '1') and 
                    (axi_rvalid_int = '1' and AXI_RREADY = '1') then     -- Capture error flags 
                     CE_Q <= Sl_CE_i;
                     UE_Q <= Sl_UE_i;
                 else              
                     CE_Q <= '0';
                     UE_Q <= '0';
                 end if;          
             end if;
         end process CORR_REG;

 
        -- The signal, axi_rdata_en loads the syndrome_reg.
        -- Use the AXI RVALID/READY signals to capture state of UE and CE.
        -- Since flag generation uses the registered syndrome value.
 
        -- ECC register block gets registered UE or CE conditions to update
        -- ECC registers/interrupt/flag outputs.
        Sl_CE <= CE_Q;
        Sl_UE <= UE_Q;
        
        -- CE_Failing_We <= Sl_CE_i and Enable_ECC and axi_rvalid_set;
        CE_Failing_We <= CE_Q;
                            
                            
        ---------------------------------------------------------------------------
        -- Generate BRAM read data vector assignment to always be from Port A
        -- in a single port BRAM configuration.
        -- Map BRAM_RdData (Port A) (N:0) to bram_din_a_i (0:N)
        -- Including read back ECC bits.
        --
        -- Port A or Port B sourcing done at full_axi module level
        ---------------------------------------------------------------------------
        -- Original design with mux (BRAM vs. Skid Buffer) on input side of checkbit_handler logic.
        -- Move mux to enable on AXI RDATA register.
        bram_din_a_i (0 to C_AXI_DATA_WIDTH+C_ECC_WIDTH-1) <= BRAM_RdData (C_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0);
        

        -- Map data vector from BRAM to use in correct_one_bit module with 
        -- register syndrome (post AXI RDATA register).
        UnCorrectedRdData (0 to C_AXI_DATA_WIDTH-1) <= bram_din_a_i (C_ECC_WIDTH to C_ECC_WIDTH+C_AXI_DATA_WIDTH-1);

                      
     end generate GEN_ECC;



    ---------------------------------------------------------------------------



    ---------------------------------------------------------------------------
    -- Generate:    GEN_NO_ECC
    -- Purpose:     Drive default output signals when ECC is diabled.
    ---------------------------------------------------------------------------

    GEN_NO_ECC: if C_ECC = 0 generate
    begin
    
        BRAM_Addr_En <= '0';
        CE_Failing_We <= '0'; 
        Sl_CE <= '0'; 
        Sl_UE <= '0'; 

    end generate GEN_NO_ECC;










    ---------------------------------------------------------------------------
    --
    -- *** BRAM Interface Signals ***
    --
    ---------------------------------------------------------------------------


    BRAM_En <= bram_en_int;   




    ---------------------------------------------------------------------------
    -- BRAM Address Generate
    ---------------------------------------------------------------------------


    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_L_BRAM_ADDR
    -- Purpose:     Generate zeros on lower order address bits adjustable
    --              based on BRAM data width.
    --
    ---------------------------------------------------------------------------

    GEN_L_BRAM_ADDR: for i in C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0 generate
    begin    
        BRAM_Addr (i) <= '0';        
    end generate GEN_L_BRAM_ADDR;


    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_BRAM_ADDR
    -- Purpose:     Assign BRAM address output from address counter.
    --
    ---------------------------------------------------------------------------

    GEN_BRAM_ADDR: for i in C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR generate
    begin    

        BRAM_Addr (i) <= bram_addr_int (i);        
    end generate GEN_BRAM_ADDR;
    
    
    ---------------------------------------------------------------------------





end architecture implementation;










-------------------------------------------------------------------------------
-- wr_chnl.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
-------------------------------------------------------------------------------
-- Filename:        wr_chnl.vhd
--
-- Description:     This file is the top level module for the AXI BRAM
--                  controller write channel interfaces.  Controls all
--                  handshaking and data flow on the AXI write address (AW),
--                  write data (W) and write response (B) channels.
--
--
-- VHDL-Standard:   VHDL'93
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- correct_one_bit.vhd
--
--
-------------------------------------------------------------------------------
--
-- History:
-- 
-- JLJ      2/2/2011       v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Minor code cleanup.
--  Remove library version # dependency.  Replace with work library.
-- ^^^^^^
-- JLJ      2/3/2011       v1.03a
-- ~~~~~~
--  Edits for scalability and support of 512 and 1024-bit data widths.
-- ^^^^^^
-- JLJ      2/10/2011      v1.03a
-- ~~~~~~
--  Initial integration of Hsiao ECC algorithm.
--  Add C_ECC_TYPE top level parameter.
-- ^^^^^^
-- JLJ      2/14/2011      v1.03a
-- ~~~~~~
--  Shift Hsiao ECC generate logic so not dependent on C_S_AXI_DATA_WIDTH.
-- ^^^^^^
-- JLJ      2/18/2011      v1.03a
-- ~~~~~~
--  Update WE size based on 128-bit ECC configuration.
--  Update for usage of ecc_gen.vhd module directly from MIG.
--  Clean-up XST warnings.
-- ^^^^^^
-- JLJ      2/22/2011      v1.03a
-- ~~~~~~
--  Found issue with ECC decoding on read path.  Remove MSB '0' usage 
--  in syndrome calculation, since h_matrix is based on 32 + 7 = 39 bits.
-- ^^^^^^
-- JLJ      2/23/2011      v1.03a
-- ~~~~~~
--  Code clean-up.
--  Move all MIG functions to package body.
-- ^^^^^^
-- JLJ      2/28/2011      v1.03a
-- ~~~~~~
--  Fix mapping on BRAM_WE with bram_we_int for 128-bit w/ ECC.
-- ^^^^^^
-- JLJ      3/1/2011        v1.03a
-- ~~~~~~
--  Fix XST handling for DIV functions.  Create seperate process when
--  divisor is not constant and a power of two.
-- ^^^^^^
-- JLJ      3/17/2011      v1.03a
-- ~~~~~~
--  Add comments as noted in Spyglass runs. And general code clean-up.
--  Fix double clock assertion of CE/UE error flags when asserted
--  during the RMW sequence.
-- ^^^^^^
-- JLJ      3/23/2011      v1.03a
-- ~~~~~~
--  Code clean-up.
-- ^^^^^^
-- JLJ      3/30/2011      v1.03a
-- ~~~~~~
--  Add code coverage on/off statements.
-- ^^^^^^
-- JLJ      4/8/2011      v1.03a
-- ~~~~~~
--  Modify back-to-back capability to remove combinatorial loop 
--  on WREADY to AXI interface.  Add internal constant, C_REG_WREADY.
--  Update axi_wready_int reset value (ensure it is '0').
--
--  Create new SM for C_REG_WREADY with dual port.  Seperate assertion of BVALID
--  from WREADY.  Create a FIFO to store AWID/BID values.
--  Use counter (with max of 8 ID values) to allow WREADY assertions 
--  to be ahead of BVALID assertions.
--  Add sub module, SRL_FIFO.
-- ^^^^^^
-- JLJ      4/11/2011      v1.03a
-- ~~~~~~
--  Implement similar updates on WREADY for single port & ECC configurations.
--  Remove use of signal, axi_wready_sng with constant, C_REG_WREADY.
--
--  For single port operation with registered WREADY, provide BVALID counter
--  value to arbitration SM, add output signal, AW2Arb_BVALID_Cnt.
--
--  Create an additional SM for single port when C_REG_WREADY.
-- ^^^^^^
-- JLJ      4/14/2011      v1.03a
-- ~~~~~~
--  Remove attempt to create AXI write data pipeline full flag outside of SM
--  logic.  Add corner case checks for BID FIFO/BVALID counter.
-- ^^^^^^
-- JLJ      4/15/2011      v1.03a
-- ~~~~~~
--  Clean up all code not related to C_REG_WREADY.  
--  Goal to remove internal constant, C_REG_WREADY.
--  Work on size optimization.  Implement signals to represent BVALID 
--  counter values.
-- ^^^^^^
-- JLJ      4/20/2011      v1.03a
-- ~~~~~~
--  Code clean up.  Remove unused signals.
--  Remove additional generate blocks with C_REG_WREADY.
-- ^^^^^^
-- JLJ      4/21/2011      v1.03a
-- ~~~~~~
--  Code clean up.  Remove use of IF_IS_AXI4 constant.
--  Create new SM TYPE for each configuration.
-- ^^^^^^
-- JLJ      4/22/2011      v1.03a
-- ~~~~~~
--  Add check in data SM on back-to-back for BVALID counter max.
--  Clean up AXI_WREADY generate blocks.
-- ^^^^^^
-- JLJ      4/22/2011         v1.03a
-- ~~~~~~
--  Code clean up.
-- ^^^^^^
-- JLJ      5/6/2011      v1.03a
-- ~~~~~~
--  Remove usage of C_FAMILY.  
--  Hard code C_USE_LUT6 constant.
-- ^^^^^^
-- JLJ      5/26/2011      v1.03a
-- ~~~~~~
--  Fix CR # 609695.
--  Modify usage of WLAST.  Ensure that WLAST is qualified with
--  WVALID/WREADY assertions.
--
--  With CR # 609695, update else clause for narrow_burst_cnt_ld to 
--  remove simulation warnings when axi_byte_div_curr_awsize = zero.
--
--  Catch code clean up with WLAST in data SM for axi_wr_burst_cmb
--  signal assertion.
-- ^^^^^^
--
--
--  
-------------------------------------------------------------------------------

-- Library declarations

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.srl_fifo;
use work.wrap_brst;
use work.ua_narrow;
use work.checkbit_handler;
use work.checkbit_handler_64;
use work.correct_one_bit;
use work.correct_one_bit_64;
use work.ecc_gen;
use work.axi_bram_ctrl_funcs.all;



------------------------------------------------------------------------------


entity wr_chnl is
generic (


    --  C_FAMILY : string := "virtex6";
        -- Specify the target architecture type

    C_AXI_ADDR_WIDTH    : integer := 32;
      -- Width of AXI address bus (in bits)
    
    C_BRAM_ADDR_ADJUST_FACTOR   : integer := 2;
      -- Adjust factor to BRAM address width based on data width (in bits)

    C_AXI_DATA_WIDTH  : integer := 32;
      -- Width of AXI data bus (in bits)
      
    C_AXI_ID_WIDTH : INTEGER := 4;
        --  AXI ID vector width

    C_S_AXI_SUPPORTS_NARROW : INTEGER := 1;
        -- Support for narrow burst operations

    C_S_AXI_PROTOCOL : string := "AXI4";
        -- Set to "AXI4LITE" to optimize out burst transaction support

    C_SINGLE_PORT_BRAM : INTEGER := 0;
        -- Enable single port usage of BRAM

    C_ECC : integer := 0;
        -- Enables or disables ECC functionality
        
    C_ECC_WIDTH : integer := 8;
        -- Width of ECC data vector
        
    C_ECC_TYPE : integer := 0          -- v1.03a 
        -- ECC algorithm format, 0 = Hamming code, 1 = Hsiao code

    );
  port (


    -- AXI Global Signals
    S_AXI_AClk              : in    std_logic;
    S_AXI_AResetn           : in    std_logic;      

    -- AXI Write Address Channel Signals (AW)
    AXI_AWID                : in    std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
    AXI_AWADDR              : in    std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0);

    AXI_AWLEN               : in    std_logic_vector(7 downto 0);
        -- Specifies the number of data transfers in the burst
        -- "0000 0000"  1 data transfer
        -- "0000 0001"  2 data transfers
        -- ...
        -- "1111 1111" 256 data transfers
        
    AXI_AWSIZE              : in    std_logic_vector(2 downto 0);
        -- Specifies the max number of data bytes to transfer in each data beat
        -- "000"    1 byte to transfer
        -- "001"    2 bytes to transfer
        -- "010"    3 bytes to transfer
        -- ...
        
    
    AXI_AWBURST             : in    std_logic_vector(1 downto 0);
        -- Specifies burst type
        -- "00" FIXED = Fixed burst address (handled as INCR)
        -- "01" INCR = Increment burst address
        -- "10" WRAP = Incrementing address burst that wraps to lower order address at boundary
        -- "11" Reserved (not checked)
    
    AXI_AWLOCK              : in    std_logic;                          -- Currently unused         
    AXI_AWCACHE             : in    std_logic_vector(3 downto 0);       -- Currently unused
    AXI_AWPROT              : in    std_logic_vector(2 downto 0);       -- Currently unused
    AXI_AWVALID             : in    std_logic;
    AXI_AWREADY             : out   std_logic;


    -- AXI Write Data Channel Signals (W)
    AXI_WDATA               : in    std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0);
    AXI_WSTRB               : in    std_logic_vector(C_AXI_DATA_WIDTH/8-1 downto 0);
    AXI_WLAST               : in    std_logic;

    AXI_WVALID              : in    std_logic;
    AXI_WREADY              : out   std_logic;


    -- AXI Write Data Response Channel Signals (B)
    AXI_BID                 : out   std_logic_vector(C_AXI_ID_WIDTH-1 downto 0);
    AXI_BRESP               : out   std_logic_vector(1 downto 0);

    AXI_BVALID              : out   std_logic;
    AXI_BREADY              : in    std_logic;

 
    -- ECC Register Interface Signals
    Enable_ECC              : in    std_logic;
    BRAM_Addr_En            : out   std_logic := '0';
    FaultInjectClr          : out   std_logic := '0'; 
    CE_Failing_We           : out   std_logic := '0'; 
    Sl_CE                   : out   std_logic := '0'; 
    Sl_UE                   : out   std_logic := '0'; 
    Active_Wr               : out   std_logic := '0';

    FaultInjectData         : in    std_logic_vector (C_AXI_DATA_WIDTH-1 downto 0);
    FaultInjectECC          : in    std_logic_vector (C_ECC_WIDTH-1 downto 0);
    

    -- Single Port Arbitration Signals
    Arb2AW_Active               : in    std_logic;
    AW2Arb_Busy                 : out   std_logic := '0';
    AW2Arb_Active_Clr           : out   std_logic := '0';
    AW2Arb_BVALID_Cnt           : out   std_logic_vector (2 downto 0) := (others => '0');

    Sng_BRAM_Addr_Rst           : out   std_logic := '0';
    Sng_BRAM_Addr_Ld_En         : out   std_logic := '0';
    Sng_BRAM_Addr_Ld            : out   std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) := (others => '0');
    Sng_BRAM_Addr_Inc           : out   std_logic := '0';
    Sng_BRAM_Addr               : in    std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR);
    
    
    -- BRAM Write Port Interface Signals
    BRAM_En                 : out   std_logic := '0';
    BRAM_WE                 : out   std_logic_vector (C_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_AXI_DATA_WIDTH/128))-1 downto 0);
    BRAM_Addr               : out   std_logic_vector (C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
    BRAM_WrData             : out   std_logic_vector (C_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0) := (others => '0');
    BRAM_RdData             : in    std_logic_vector (C_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0)
       
    

    );


end entity wr_chnl;


-------------------------------------------------------------------------------

architecture implementation of wr_chnl is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";


-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------

-- All functions defined in axi_bram_ctrl_funcs package.

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

-- Reset active level (common through core)
constant C_RESET_ACTIVE     : std_logic := '0';


constant RESP_OKAY      : std_logic_vector (1 downto 0) := "00";    -- Normal access OK response
constant RESP_SLVERR    : std_logic_vector (1 downto 0) := "10";    -- Slave error
-- For future support.      constant RESP_EXOKAY    : std_logic_vector (1 downto 0) := "01";    -- Exclusive access OK response
-- For future support.      constant RESP_DECERR    : std_logic_vector (1 downto 0) := "11";    -- Decode error


-- Set constants for AWLEN equal to a count of one or two beats.
constant AXI_AWLEN_ONE  : std_logic_vector (7 downto 0) := (others => '0');
constant AXI_AWLEN_TWO  : std_logic_vector (7 downto 0) := "00000001";
constant AXI_AWSIZE_ONE : std_logic_vector (2 downto 0) := "001";



-- Determine maximum size for narrow burst length counter
-- When C_AXI_DATA_WIDTH = 32, minimum narrow width burst is 8 bits
--              resulting in a count 3 downto 0 => so minimum counter width = 2 bits.
-- When C_AXI_DATA_WIDTH = 256, minimum narrow width burst is 8 bits
--              resulting in a count 31 downto 0 => so minimum counter width = 5 bits.

constant C_NARROW_BURST_CNT_LEN     : integer := log2 (C_AXI_DATA_WIDTH/8);
constant NARROW_CNT_MAX     : std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0) := (others => '0');



-- AXI Size Constants
--      constant C_AXI_SIZE_1BYTE       : std_logic_vector (2 downto 0) := "000";   -- 1 byte
--      constant C_AXI_SIZE_2BYTE       : std_logic_vector (2 downto 0) := "001";   -- 2 bytes
--      constant C_AXI_SIZE_4BYTE       : std_logic_vector (2 downto 0) := "010";   -- 4 bytes = max size for 32-bit BRAM
--      constant C_AXI_SIZE_8BYTE       : std_logic_vector (2 downto 0) := "011";   -- 8 bytes = max size for 64-bit BRAM
--      constant C_AXI_SIZE_16BYTE      : std_logic_vector (2 downto 0) := "100";   -- 16 bytes = max size for 128-bit BRAM
--      constant C_AXI_SIZE_32BYTE      : std_logic_vector (2 downto 0) := "101";   -- 32 bytes = max size for 256-bit BRAM
--      constant C_AXI_SIZE_64BYTE      : std_logic_vector (2 downto 0) := "110";   -- 64 bytes = max size for 512-bit BRAM
--      constant C_AXI_SIZE_128BYTE     : std_logic_vector (2 downto 0) := "111";   -- 128 bytes = max size for 1024-bit BRAM


-- Determine max value of ARSIZE based on the AXI data width.
-- Use function in axi_bram_ctrl_funcs package.
constant C_AXI_SIZE_MAX         : std_logic_vector (2 downto 0) := Create_Size_Max (C_AXI_DATA_WIDTH);




-- Modify C_BRAM_ADDR_SIZE to be adjusted for BRAM data width
-- When BRAM data width = 32 bits, BRAM_Addr (1:0) = "00"
-- When BRAM data width = 64 bits, BRAM_Addr (2:0) = "000"
-- When BRAM data width = 128 bits, BRAM_Addr (3:0) = "0000"
-- When BRAM data width = 256 bits, BRAM_Addr (4:0) = "00000"
-- Move to full_axi module
-- constant C_BRAM_ADDR_ADJUST_FACTOR  : integer := log2 (C_AXI_DATA_WIDTH/8);
-- Not used
-- constant C_BRAM_ADDR_ADJUST : integer := C_AXI_ADDR_WIDTH - C_BRAM_ADDR_ADJUST_FACTOR;

constant C_AXI_DATA_WIDTH_BYTES     : integer := C_AXI_DATA_WIDTH/8;

-- AXI Burst Types
-- AXI Spec 4.4
constant C_AXI_BURST_WRAP       : std_logic_vector (1 downto 0) := "10";  
constant C_AXI_BURST_INCR       : std_logic_vector (1 downto 0) := "01";  
constant C_AXI_BURST_FIXED      : std_logic_vector (1 downto 0) := "00";  


-- Internal ECC data width size.
constant C_INT_ECC_WIDTH : integer := Int_ECC_Size (C_AXI_DATA_WIDTH);


-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------



-------------------------------------------------------------------------------
-- AXI Write Address Channel Signals
-------------------------------------------------------------------------------


-- State machine type declarations
type WR_ADDR_SM_TYPE is ( IDLE,
                          LD_AWADDR
                        );
                    
signal wr_addr_sm_cs, wr_addr_sm_ns : WR_ADDR_SM_TYPE;

signal aw_active_set                : std_logic := '0';
signal aw_active_set_i              : std_logic := '0';

signal aw_active_clr                : std_logic := '0';
signal delay_aw_active_clr_cmb      : std_logic := '0'; 
signal delay_aw_active_clr          : std_logic := '0';
signal aw_active                    : std_logic := '0';
signal aw_active_d1                 : std_logic := '0';
signal aw_active_re                 : std_logic := '0';

signal axi_awaddr_pipe      : std_logic_vector (C_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');

signal curr_awaddr_lsb      : std_logic_vector (C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0) := (others => '0');

signal awaddr_pipe_ld       : std_logic := '0';
signal awaddr_pipe_ld_i     : std_logic := '0';

signal awaddr_pipe_sel      : std_logic := '0';
    -- '0' indicates mux select from AXI
    -- '1' indicates mux select from AW Addr Register
signal axi_awaddr_full      : std_logic := '0';

signal axi_awid_pipe        : std_logic_vector (C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal axi_awsize_pipe      : std_logic_vector(2 downto 0) := (others => '0');
signal curr_awsize          : std_logic_vector(2 downto 0) := (others => '0');
signal curr_awsize_reg      : std_logic_vector (2 downto 0) := (others => '0');


-- Narrow Burst Signals
signal curr_narrow_burst_cmb    : std_logic := '0';
signal curr_narrow_burst        : std_logic := '0';
signal curr_narrow_burst_en     : std_logic := '0';

signal narrow_burst_cnt_ld      : std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0) := (others => '0');
signal narrow_burst_cnt_ld_reg  : std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0) := (others => '0');
signal narrow_burst_cnt_ld_mod  : std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0) := (others => '0');

signal narrow_addr_rst          : std_logic := '0';     
signal narrow_addr_ld_en        : std_logic := '0';
signal narrow_addr_dec          : std_logic := '0';


signal axi_awlen_pipe           : std_logic_vector(7 downto 0) := (others => '0');

signal axi_awlen_pipe_1_or_2    : std_logic := '0';     
signal curr_awlen               : std_logic_vector(7 downto 0) := (others => '0');
signal curr_awlen_reg           : std_logic_vector(7 downto 0) := (others => '0');

signal curr_awlen_reg_1_or_2    : std_logic := '0';     


signal axi_awburst_pipe         : std_logic_vector(1 downto 0) := (others => '0');
signal axi_awburst_pipe_fixed   : std_logic := '0';     

signal curr_awburst             : std_logic_vector(1 downto 0) := (others => '0');
signal curr_wrap_burst          : std_logic := '0';
signal curr_wrap_burst_reg      : std_logic := '0';

signal curr_incr_burst          : std_logic := '0';     
signal curr_fixed_burst         : std_logic := '0';     
signal curr_fixed_burst_reg     : std_logic := '0';     

signal max_wrap_burst_mod       : std_logic := '0';

signal axi_awready_int          : std_logic := '0';

signal axi_aresetn_d1           : std_logic := '0';
signal axi_aresetn_d2           : std_logic := '0';
signal axi_aresetn_re           : std_logic := '0';
signal axi_aresetn_re_reg       : std_logic := '0';


-- BRAM Address Counter    
signal bram_addr_ld_en              : std_logic := '0';
signal bram_addr_ld_en_i            : std_logic := '0';


signal bram_addr_ld_en_mod          : std_logic := '0';

signal bram_addr_ld                 : std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)
                                        := (others => '0');
signal bram_addr_ld_wrap            : std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)
                                        := (others => '0');

signal bram_addr_inc                : std_logic := '0';
signal bram_addr_inc_mod            : std_logic := '0';
signal bram_addr_inc_wrap_mod       : std_logic := '0';         

signal bram_addr_rst                : std_logic := '0';
signal bram_addr_rst_cmb            : std_logic := '0';


signal narrow_bram_addr_inc         : std_logic := '0';
signal narrow_bram_addr_inc_d1      : std_logic := '0';
signal narrow_bram_addr_inc_re      : std_logic := '0';

signal narrow_addr_int              : std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0) := (others => '0');

signal curr_ua_narrow_wrap          : std_logic := '0';
signal curr_ua_narrow_incr          : std_logic := '0';     
signal ua_narrow_load               : std_logic_vector (C_NARROW_BURST_CNT_LEN-1 downto 0) := (others => '0');




-------------------------------------------------------------------------------
-- AXI Write Data Channel Signals
-------------------------------------------------------------------------------


-- State machine type declarations
type WR_DATA_SM_TYPE is (   IDLE,
                            W8_AWADDR,
                                                            -- W8_BREADY,
                            SNG_WR_DATA,
                            BRST_WR_DATA,
                                                            -- NEW_BRST_WR_DATA,
                            B2B_W8_WR_DATA                  --,
                                                            -- B2B_W8_BRESP,
                                                            -- W8_BRESP  
                          );
                    
signal wr_data_sm_cs, wr_data_sm_ns : WR_DATA_SM_TYPE;



type WR_DATA_SNG_SM_TYPE is (   IDLE,
                                SNG_WR_DATA,
                                BRST_WR_DATA  );

signal wr_data_sng_sm_cs, wr_data_sng_sm_ns : WR_DATA_SNG_SM_TYPE;



type WR_DATA_ECC_SM_TYPE is (   IDLE,
                                RMW_RD_DATA,
                                RMW_CHK_DATA,
                                RMW_MOD_DATA,
                                RMW_WR_DATA   );

signal wr_data_ecc_sm_cs, wr_data_ecc_sm_ns : WR_DATA_ECC_SM_TYPE;


-- Wr Data Buffer/Register
signal wrdata_reg_ld        : std_logic := '0';
signal axi_wready_int       : std_logic := '0';
signal axi_wready_int_mod   : std_logic := '0';
signal axi_wdata_full_cmb   : std_logic := '0';
signal axi_wdata_full       : std_logic := '0';
signal axi_wdata_empty      : std_logic := '0';
signal axi_wdata_full_reg   : std_logic := '0';



-- WE Generator Signals
signal clr_bram_we_cmb      : std_logic := '0';
signal clr_bram_we          : std_logic := '0';
signal bram_we_ld           : std_logic := '0';

signal axi_wr_burst_cmb     : std_logic := '0';
signal axi_wr_burst         : std_logic := '0';


signal wr_b2b_elgible           : std_logic := '0';
-- CR # 609695      signal last_data_ack            : std_logic := '0';
-- CR # 609695      signal last_data_ack_throttle   : std_logic := '0';
signal last_data_ack_mod        : std_logic := '0';
-- CR # 609695      signal w8_b2b_bresp             : std_logic := '0';


signal axi_wlast_d1             : std_logic := '0';
signal axi_wlast_re             : std_logic := '0';


-- Single Port Signals

-- Write busy flags only used in ECC configuration
-- when waiting for BVALID/BREADY handshake
signal wr_busy_cmb              : std_logic := '0';    
signal wr_busy_reg              : std_logic := '0';

-- Only used by ECC register module.
signal active_wr_cmb            : std_logic := '0';
signal active_wr_reg            : std_logic := '0';


-------------------------------------------------------------------------------
-- AXI Write Response Channel Signals
-------------------------------------------------------------------------------

signal axi_bid_temp         : std_logic_vector (C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal axi_bid_temp_full    : std_logic := '0';

signal axi_bid_int          : std_logic_vector (C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal axi_bresp_int        : std_logic_vector (1 downto 0) := (others => '0');
signal axi_bvalid_int       : std_logic := '0';
signal axi_bvalid_set_cmb   : std_logic := '0';


-------------------------------------------------------------------------------
-- Internal BRAM Signals
-------------------------------------------------------------------------------

signal reset_bram_we        : std_logic := '0';
signal set_bram_we_cmb      : std_logic := '0';
signal set_bram_we          : std_logic := '0';
signal bram_we_int          : std_logic_vector (C_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0');
signal bram_en_cmb          : std_logic := '0';
signal bram_en_int          : std_logic := '0';

signal bram_addr_int        : std_logic_vector (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)
                                    := (others => '0');

signal bram_wrdata_int      : std_logic_vector (C_AXI_DATA_WIDTH-1 downto 0) := (others => '0');


-------------------------------------------------------------------------------
-- ECC Signals
-------------------------------------------------------------------------------

signal CorrectedRdData          : std_logic_vector(0 to C_AXI_DATA_WIDTH-1);
signal RdModifyWr_Modify        : std_logic := '0';  -- Modify cycle in read modify write sequence 
signal RdModifyWr_Write         : std_logic := '0';  -- Write cycle in read modify write sequence 
signal WrData                   : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
signal WrData_cmb               : std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0) := (others => '0');

signal UE_Q                     : std_logic := '0';


-------------------------------------------------------------------------------
-- BVALID  Signals
-------------------------------------------------------------------------------

signal bvalid_cnt_inc       : std_logic := '0';
signal bvalid_cnt_inc_d1    : std_logic := '0';
signal bvalid_cnt_dec       : std_logic := '0';
signal bvalid_cnt           : std_logic_vector (2 downto 0) := (others => '0');
signal bvalid_cnt_amax      : std_logic := '0';
signal bvalid_cnt_max       : std_logic := '0';
signal bvalid_cnt_non_zero  : std_logic := '0';


-------------------------------------------------------------------------------
-- BID FIFO  Signals
-------------------------------------------------------------------------------

signal bid_fifo_rst         : std_logic := '0';
signal bid_fifo_ld_en       : std_logic := '0';
signal bid_fifo_ld          : std_logic_vector (C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal bid_fifo_rd_en       : std_logic := '0';
signal bid_fifo_rd          : std_logic_vector (C_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal bid_fifo_not_empty   : std_logic := '0';

signal bid_gets_fifo_load       : std_logic := '0';
signal bid_gets_fifo_load_d1    : std_logic := '0';

signal first_fifo_bid           : std_logic := '0';
signal b2b_fifo_bid             : std_logic := '0';





-------------------------------------------------------------------------------
-- Architecture Body
-------------------------------------------------------------------------------


begin 



    ---------------------------------------------------------------------------
    -- AXI Write Address Channel Output Signals
    ---------------------------------------------------------------------------
    AXI_AWREADY <= axi_awready_int;



    ---------------------------------------------------------------------------
    -- AXI Write Data Channel Output Signals
    ---------------------------------------------------------------------------

    -- WREADY same signal assertion regardless of ECC or single port configuration.
    AXI_WREADY <= axi_wready_int_mod;
    
    

    ---------------------------------------------------------------------------
    -- AXI Write Response Channel Output Signals
    ---------------------------------------------------------------------------

    AXI_BRESP <= axi_bresp_int;
    AXI_BVALID <= axi_bvalid_int;

    AXI_BID <= axi_bid_int;   





    ---------------------------------------------------------------------------
    -- *** AXI Write Address Channel Interface ***
    ---------------------------------------------------------------------------

    
    ---------------------------------------------------------------------------
    -- Generate:    GEN_AW_PIPE_SNG
    -- Purpose:     Only generate pipeline registers when in dual port BRAM mode.
    ---------------------------------------------------------------------------

    GEN_AW_PIPE_SNG: if C_SINGLE_PORT_BRAM = 1 generate
    begin
    
        -- Unused AW pipeline (set default values)
        awaddr_pipe_ld <= '0';
        axi_awaddr_pipe <= AXI_AWADDR;
        axi_awid_pipe <= AXI_AWID;
        axi_awsize_pipe <= AXI_AWSIZE;
        axi_awlen_pipe <= AXI_AWLEN;
        axi_awburst_pipe <= AXI_AWBURST;
        axi_awlen_pipe_1_or_2 <= '0';
        axi_awburst_pipe_fixed <= '0';
        axi_awaddr_full <= '0';
            
    end generate GEN_AW_PIPE_SNG;



    ---------------------------------------------------------------------------
    -- Generate:    GEN_AW_PIPE_DUAL
    -- Purpose:     Only generate pipeline registers when in dual port BRAM mode.
    ---------------------------------------------------------------------------

    GEN_AW_PIPE_DUAL: if C_SINGLE_PORT_BRAM = 0 generate
    begin


        -----------------------------------------------------------------------
        --
        -- AXI Write Address Buffer/Register
        -- (mimic behavior of address pipeline for AXI_AWID)
        --
        -----------------------------------------------------------------------

        GEN_AWADDR: for i in C_AXI_ADDR_WIDTH-1 downto 0 generate
        begin

            REG_AWADDR: process (S_AXI_AClk)
            begin

                if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                    if (awaddr_pipe_ld = '1') then
                        axi_awaddr_pipe (i) <= AXI_AWADDR (i);
                    else
                        axi_awaddr_pipe (i) <= axi_awaddr_pipe (i);

                    end if;
                end if;

            end process REG_AWADDR;

        end generate GEN_AWADDR;



        -----------------------------------------------------------------------
        
        -- Register AWID

        REG_AWID: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (awaddr_pipe_ld = '1') then
                    axi_awid_pipe <= AXI_AWID;
                else
                    axi_awid_pipe <= axi_awid_pipe;

                end if;
            end if;

        end process REG_AWID;



        ---------------------------------------------------------------------------

        -- In parallel to AWADDR pipeline and AWID
        -- Use same control signals to capture AXI_AWSIZE, AXI_AWLEN & AXI_AWBURST.

        -- Register AXI_AWSIZE, AXI_AWLEN & AXI_AWBURST


        REG_AWCTRL: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (awaddr_pipe_ld = '1') then
                    axi_awsize_pipe <= AXI_AWSIZE;
                    axi_awlen_pipe <= AXI_AWLEN;
                    axi_awburst_pipe <= AXI_AWBURST;
                else
                    axi_awsize_pipe <= axi_awsize_pipe;
                    axi_awlen_pipe <= axi_awlen_pipe;
                    axi_awburst_pipe <= axi_awburst_pipe;

                end if;
            end if;

        end process REG_AWCTRL;



        ---------------------------------------------------------------------------


        -- Create signals that indicate value of AXI_AWLEN in pipeline stage
        -- Used to decode length of burst when BRAM address can be loaded early
        -- when pipeline is full.
        --
        -- Add early decode of AWBURST in pipeline.


        REG_AWLEN_PIPE: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (awaddr_pipe_ld = '1') then

                    -- Create merge to decode AWLEN of ONE or TWO
                    if (AXI_AWLEN = AXI_AWLEN_ONE) or (AXI_AWLEN = AXI_AWLEN_TWO) then
                        axi_awlen_pipe_1_or_2 <= '1';
                    else
                        axi_awlen_pipe_1_or_2 <= '0';
                    end if;


                    -- Early decode on value in pipeline of AWBURST
                    if (AXI_AWBURST = C_AXI_BURST_FIXED) then
                        axi_awburst_pipe_fixed <= '1';                
                    else
                        axi_awburst_pipe_fixed <= '0';
                    end if;


                else

                    axi_awlen_pipe_1_or_2 <= axi_awlen_pipe_1_or_2;
                    axi_awburst_pipe_fixed <= axi_awburst_pipe_fixed;

                end if;
            end if;

        end process REG_AWLEN_PIPE;


        ---------------------------------------------------------------------------


        -- Create full flag for AWADDR pipeline
        -- Set when write address register is loaded.
        -- Cleared when write address stored in register is loaded into BRAM
        -- address counter.


        REG_WRADDR_FULL: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   (bram_addr_ld_en = '1' and awaddr_pipe_sel = '1') then
                    axi_awaddr_full <= '0';

                elsif (awaddr_pipe_ld = '1') then
                    axi_awaddr_full <= '1';
                else
                    axi_awaddr_full <= axi_awaddr_full;

                end if;
            end if;

        end process REG_WRADDR_FULL;



        ---------------------------------------------------------------------------



    end generate GEN_AW_PIPE_DUAL;





    ---------------------------------------------------------------------------
    -- Generate:    GEN_DUAL_ADDR_CNT
    -- Purpose:     Instantiate BRAM address counter unique for wr_chnl logic
    --              only when controller configured in dual port mode.
    ---------------------------------------------------------------------------
    
    GEN_DUAL_ADDR_CNT: if (C_SINGLE_PORT_BRAM = 0) generate
    begin
    

        ----------------------------------------------------------------------------

        -- Replace I_ADDR_CNT module usage of pf_counter in proc_common library.
        -- Only need to use lower 12-bits of address due to max AXI burst size
        -- Since AXI guarantees bursts do not cross 4KB boundary, the counting part 
        -- of I_ADDR_CNT can be reduced to max 4KB. 
        --
        --  Counter size is adjusted based on data width of BRAM.
        --  For example, 32-bit data width BRAM, BRAM_Addr (1:0)
        --  are fixed at "00".  So, counter increments from
        --  (C_AXI_ADDR_WIDTH - 1 : C_BRAM_ADDR_ADJUST).
        
        ----------------------------------------------------------------------------


        I_ADDR_CNT: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                -- Reset usage differs from RD CHNL
                if (bram_addr_rst = '1') then
                    bram_addr_int <= (others => '0');

                elsif (bram_addr_ld_en_mod = '1') then
                    bram_addr_int <= bram_addr_ld;

                elsif (bram_addr_inc_mod = '1') then
                    bram_addr_int (C_AXI_ADDR_WIDTH-1 downto 12) <= 
                            bram_addr_int (C_AXI_ADDR_WIDTH-1 downto 12);
                    bram_addr_int (11 downto C_BRAM_ADDR_ADJUST_FACTOR) <= 
                            std_logic_vector (unsigned (bram_addr_int (11 downto C_BRAM_ADDR_ADJUST_FACTOR)) + 1);

                    end if;

                end if;

        end process I_ADDR_CNT;


        -- Set defaults to shared address counter
        -- Only used in single port configurations
        Sng_BRAM_Addr_Rst <= '0';
        Sng_BRAM_Addr_Ld_En <= '0';
        Sng_BRAM_Addr_Ld <= (others => '0');
        Sng_BRAM_Addr_Inc <= '0';
        

    end generate GEN_DUAL_ADDR_CNT;
    
    
    
    ---------------------------------------------------------------------------
    -- Generate:    GEN_SNG_ADDR_CNT
    -- Purpose:     When configured in single port BRAM mode, address counter
    --              is shared with rd_chnl module.  Assign output signals here
    --              to counter instantiation at full_axi module level.
    ---------------------------------------------------------------------------
    GEN_SNG_ADDR_CNT: if (C_SINGLE_PORT_BRAM = 1) generate
    begin
    
        Sng_BRAM_Addr_Rst <= bram_addr_rst;
        Sng_BRAM_Addr_Ld_En <= bram_addr_ld_en_mod;
        Sng_BRAM_Addr_Ld <= bram_addr_ld;
        Sng_BRAM_Addr_Inc <= bram_addr_inc_mod;
        bram_addr_int <= Sng_BRAM_Addr; 
    

    end generate GEN_SNG_ADDR_CNT;




    ---------------------------------------------------------------------------
    --
    -- Add BRAM counter reset for @ end of transfer
    -- 
    -- Create a unique BRAM address reset signal
    -- If the write transaction is throttling on the AXI bus, then
    -- the BRAM EN may get negated during the write transfer
    --
    -- Use combinatorial output from SM, bram_addr_rst_cmb, but ensure the
    -- BRAM address is not reset while loading a new address.

    bram_addr_rst <= (not (S_AXI_AResetn)) or (bram_addr_rst_cmb and 
                                               not (bram_addr_ld_en_mod) and not (bram_addr_inc_mod));


    ---------------------------------------------------------------------------


    -- BRAM address counter load mux
    -- 
    -- Either load BRAM counter directly from AXI bus or from stored registered value
    --
    -- Added bram_addr_ld_wrap for loading on wrap burst types
    -- Use registered signal to indicate current operation is a WRAP burst
    --
    -- Do not load bram_addr_ld_wrap when bram_addr_ld_en signal is asserted at beginning of write burst
    -- BRAM address counter load.  Due to condition when max_wrap_burst_mod remains asserted, due to BRAM address
    -- counter not incrementing (at the end of the previous write burst).

    --  bram_addr_ld <= bram_addr_ld_wrap when 
    --                      (max_wrap_burst_mod = '1' and curr_wrap_burst_reg = '1' and bram_addr_ld_en = '0') else    
    --                  axi_awaddr_pipe (C_BRAM_ADDR_SIZE-1 downto C_BRAM_ADDR_ADJUST_FACTOR) 
    --                      when (awaddr_pipe_sel = '1') else 
    --                  AXI_AWADDR (C_BRAM_ADDR_SIZE-1 downto C_BRAM_ADDR_ADJUST_FACTOR);

    -- Replace C_BRAM_ADDR_SIZE w/ C_AXI_ADDR_WIDTH parameter usage

    bram_addr_ld <= bram_addr_ld_wrap when 
                        (max_wrap_burst_mod = '1' and curr_wrap_burst_reg = '1' and bram_addr_ld_en = '0') else    
                    axi_awaddr_pipe (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) 
                        when (awaddr_pipe_sel = '1') else 
                    AXI_AWADDR (C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR);



    ---------------------------------------------------------------------------
    
   

    -- On wrap burst max loads (simultaneous BRAM address increment is asserted).
    -- Ensure that load has higher priority over increment.

    -- Use registered signal to indicate current operation is a WRAP burst
    --   bram_addr_ld_en_mod <= '1' when (bram_addr_ld_en = '1' or 
    --                                    (max_wrap_burst_mod = '1' and 
    --                                     curr_wrap_burst_reg = '1' and 
    --                                     bram_addr_inc_mod = '1'))
    --                           else '0';


    -- Use duplicate version of bram_addr_ld_en in effort
    -- to reduce fanout of signal routed to BRAM address counter
    bram_addr_ld_en_mod <= '1' when (bram_addr_ld_en = '1' or 
                                     (max_wrap_burst_mod = '1' and 
                                      curr_wrap_burst_reg = '1' and 
                                      bram_addr_inc_wrap_mod = '1'))
                            else '0';



    -- Create a special bram_addr_inc_mod for use in the bram_addr_ld_en_mod signal
    -- logic.  No need for the check if the current operation is NOT a fixed AND a wrap
    -- burst.  The transfer will be one or the other.

    -- Found issue when narrow FIXED length burst is incorrectly 
    -- incrementing BRAM address counter
    bram_addr_inc_wrap_mod <= bram_addr_inc when (curr_narrow_burst = '0') 
                            else narrow_bram_addr_inc_re;





    ----------------------------------------------------------------------------

    -- Handling for WRAP burst types
    --
    -- For WRAP burst types, the counter value will roll over when the burst
    -- boundary is reached.
    -- Boundary is reached based on ARSIZE and ARLEN.
    --
    -- Goal is to minimize muxing on initial load of counter value.
    -- On WRAP burst types, detect when the max address is reached.
    -- When the max address is reached, re-load counter with lower
    -- address value set to '0'.



    ----------------------------------------------------------------------------


    -- Detect valid WRAP burst types    
    curr_wrap_burst <= '1' when (curr_awburst = C_AXI_BURST_WRAP) else '0';


    -- Detect INCR & FIXED burst type operations
    curr_incr_burst <= '1' when (curr_awburst = C_AXI_BURST_INCR) else '0';    


    curr_fixed_burst <= '1' when (curr_awburst = C_AXI_BURST_FIXED) else '0';


    ----------------------------------------------------------------------------


    -- Register curr_wrap_burst signal when BRAM address counter is initially
    -- loaded

    REG_CURR_WRAP_BRST: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1') then

            -- Add reset same as BRAM address counter
            if (S_AXI_AResetn = C_RESET_ACTIVE) or (bram_addr_rst = '1' and bram_addr_ld_en = '0') then
                curr_wrap_burst_reg <= '0';

            elsif (bram_addr_ld_en = '1') then 
                curr_wrap_burst_reg <= curr_wrap_burst;

            else
                curr_wrap_burst_reg <= curr_wrap_burst_reg;
            end if;

        end if;

    end process REG_CURR_WRAP_BRST;



    ----------------------------------------------------------------------------


    -- Register curr_fixed_burst signal when BRAM address counter is initially
    -- loaded

    REG_CURR_FIXED_BRST: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1') then

            -- Add reset same as BRAM address counter
            if (S_AXI_AResetn = C_RESET_ACTIVE) or (bram_addr_rst = '1' and bram_addr_ld_en = '0') then
                curr_fixed_burst_reg <= '0';

            elsif (bram_addr_ld_en = '1') then 
                curr_fixed_burst_reg <= curr_fixed_burst;

            else
                curr_fixed_burst_reg <= curr_fixed_burst_reg;
            end if;

        end if;

    end process REG_CURR_FIXED_BRST;


    ----------------------------------------------------------------------------





    ---------------------------------------------------------------------------
    --
    -- Instance: I_WRAP_BRST
    --
    -- Description:
    --
    --      Instantiate WRAP_BRST module
    --      Logic to generate the wrap around value to load into the BRAM address
    --      counter on WRAP burst transactions.
    --      WRAP value is based on current AWLEN, AWSIZE (for narrows) and
    --      data width of BRAM module.
    --
    ---------------------------------------------------------------------------

    I_WRAP_BRST : entity work.wrap_brst
    generic map (

        C_AXI_ADDR_WIDTH                =>  C_AXI_ADDR_WIDTH                ,
        C_BRAM_ADDR_ADJUST_FACTOR       =>  C_BRAM_ADDR_ADJUST_FACTOR       ,
        C_AXI_DATA_WIDTH                =>  C_AXI_DATA_WIDTH              

    )
    port map (

        S_AXI_AClk                  =>  S_AXI_AClk                  ,
        S_AXI_AResetn               =>  S_AXI_AResetn               ,   

        curr_axlen                  =>  curr_awlen                  ,
        curr_axsize                 =>  curr_awsize                 ,
        curr_narrow_burst           =>  curr_narrow_burst           ,
        narrow_bram_addr_inc_re     =>  narrow_bram_addr_inc_re     ,
        bram_addr_ld_en             =>  bram_addr_ld_en             ,
        bram_addr_ld                =>  bram_addr_ld                ,
        bram_addr_int               =>  bram_addr_int               ,
        bram_addr_ld_wrap           =>  bram_addr_ld_wrap           ,
        max_wrap_burst_mod          =>  max_wrap_burst_mod     

    );    
    
    
    
    

    ---------------------------------------------------------------------------
    -- Generate:    GEN_WO_NARROW
    -- Purpose:     Create BRAM address increment signal when narrow bursts
    --              are disabled.
    ---------------------------------------------------------------------------

    GEN_WO_NARROW: if (C_S_AXI_SUPPORTS_NARROW = 0) generate
    begin

        -- For non narrow burst operations, use bram_addr_inc from data SM.
        -- Add in check that burst type is not FIXED, curr_fixed_burst_reg
        bram_addr_inc_mod <= bram_addr_inc and not (curr_fixed_burst_reg);
        
        -- The signal, curr_narrow_burst should always be set to '0' when narrow bursts
        -- are disabled.
        curr_narrow_burst <= '0';
        narrow_bram_addr_inc_re <= '0';   
    

    end generate GEN_WO_NARROW;


    ---------------------------------------------------------------------------

    
    -- Only instantiate NARROW_CNT and supporting logic when narrow transfers
    -- are supported and utilized by masters in the AXI system.
    -- The design parameter, C_S_AXI_SUPPORTS_NARROW will indicate this.
    
     


    ---------------------------------------------------------------------------
    -- Generate:    GEN_NARROW_CNT
    -- Purpose:     Instantiate narrow counter and logic when narrow
    --              operation support is enabled.
    --              And, only instantiate logic for narrow operations when
    --              AXI bus protocol is not set for AXI-LITE.
    ---------------------------------------------------------------------------

    GEN_NARROW_CNT: if (C_S_AXI_SUPPORTS_NARROW = 1) generate
    begin



        -- Based on current operation being a narrow burst, hold off BRAM
        -- address increment until narrow burst fits BRAM data width.
        -- For non narrow burst operations, use bram_addr_inc from data SM.

        -- Add in check that burst type is not FIXED, curr_fixed_burst_reg
        bram_addr_inc_mod <= (bram_addr_inc and not (curr_fixed_burst_reg)) when (curr_narrow_burst = '0') 
                                -- else narrow_bram_addr_inc_re;
                                -- Seeing incorrect BRAM address increment on narrow 
                                -- fixed length burst operations.
                                -- Add this check for curr_fixed_burst_reg
                             else (narrow_bram_addr_inc_re and not (curr_fixed_burst_reg));



        ---------------------------------------------------------------------------
        --
        -- Generate seperate smaller counter for narrow burst operations
        -- Replace I_NARROW_CNT module usage of pf_counter_top from proc_common library.
        --
        -- Counter size is adjusted based on size of data burst.
        --
        -- For example, 32-bit data width BRAM, minimum narrow width 
        -- burst is 8 bits resulting in a count 3 downto 0.  So the
        -- minimum counter width = 2 bits.
        --
        -- When C_AXI_DATA_WIDTH = 256, minimum narrow width burst 
        -- is 8 bits resulting in a count 31 downto 0.  So the
        -- minimum counter width = 5 bits.
        --
        -- Size of counter = C_NARROW_BURST_CNT_LEN
        --
        ---------------------------------------------------------------------------

        I_NARROW_CNT: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                if (narrow_addr_rst = '1') then
                    narrow_addr_int <= (others => '0');
                
                -- Load narrow address counter
                elsif (narrow_addr_ld_en = '1') then
                    narrow_addr_int <= narrow_burst_cnt_ld_mod;

                -- Decrement ONLY (no increment functionality)
                elsif (narrow_addr_dec = '1') then
                    narrow_addr_int (C_NARROW_BURST_CNT_LEN-1 downto 0) <= 
                            std_logic_vector (unsigned (narrow_addr_int (C_NARROW_BURST_CNT_LEN-1 downto 0)) - 1);

                end if;

            end if;

        end process I_NARROW_CNT;


        ---------------------------------------------------------------------------


        narrow_addr_rst <= not (S_AXI_AResetn);


        -- Narrow burst counter load mux
        -- Modify narrow burst count load value based on
        -- unalignment of AXI address value
        -- Account for INCR burst types at unaligned addresses
        narrow_burst_cnt_ld_mod <= ua_narrow_load when (curr_ua_narrow_wrap = '1' or curr_ua_narrow_incr = '1') else
                                   narrow_burst_cnt_ld when (bram_addr_ld_en = '1') else
                                   narrow_burst_cnt_ld_reg;


        narrow_addr_dec <= bram_addr_inc when (curr_narrow_burst = '1') else '0';

        narrow_addr_ld_en <= (curr_narrow_burst_cmb and bram_addr_ld_en) or narrow_bram_addr_inc_re;


        narrow_bram_addr_inc <= '1' when (narrow_addr_int = NARROW_CNT_MAX) and (curr_narrow_burst = '1') 

                                             -- Ensure that narrow address counter doesn't 
                                             -- flag max or get loaded to
                                             -- reset narrow counter until AXI read data 
                                             -- bus has acknowledged current
                                             -- data on the AXI bus.  Use rd_adv_buf signal 
                                             -- to indicate the non throttle
                                             -- condition on the AXI bus.

                                             and (bram_addr_inc = '1')                                             
                                    else '0';



        -- Detect rising edge of narrow_bram_addr_inc
        REG_NARROW_BRAM_ADDR_INC: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    narrow_bram_addr_inc_d1 <= '0';
                else
                    narrow_bram_addr_inc_d1 <= narrow_bram_addr_inc;
                end if;

            end if;
        end process REG_NARROW_BRAM_ADDR_INC;


        narrow_bram_addr_inc_re <= '1' when (narrow_bram_addr_inc = '1') and 
                                            (narrow_bram_addr_inc_d1 = '0') 
                                    else '0';


        ---------------------------------------------------------------------------

 
     end generate GEN_NARROW_CNT;



    ---------------------------------------------------------------------------
    -- Generate:    GEN_AWREADY
    -- Purpose:     AWREADY is only created here when in dual port BRAM mode.
    ---------------------------------------------------------------------------
    
    GEN_AWREADY: if (C_SINGLE_PORT_BRAM = 0) generate
    begin

        
        -- v1.03a
        
        ----------------------------------------------------------------------------
        --  AXI_AWREADY Output Register
        --  Description:    Keep AXI_AWREADY output asserted until AWADDR pipeline
        --                  is full.  When a full condition is reached, negate
        --                  AWREADY as another AW address can not be accepted.
        --                  Add condition to keep AWReady asserted if loading current
        ---                 AWADDR pipeline value into the BRAM address counter.
        --                  Indicated by assertion of bram_addr_ld_en & awaddr_pipe_sel.
        --
        ----------------------------------------------------------------------------

        REG_AWREADY: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    axi_awready_int <= '0';

                -- Detect end of S_AXI_AResetn to assert AWREADY and accept 
                -- new AWADDR values
                elsif (axi_aresetn_re_reg = '1') or (bram_addr_ld_en = '1' and awaddr_pipe_sel = '1') then
                    axi_awready_int <= '1';

                elsif (awaddr_pipe_ld = '1') then
                    axi_awready_int <= '0';
                else
                    axi_awready_int <= axi_awready_int;
                end if;
            end if;

        end process REG_AWREADY;



        ----------------------------------------------------------------------------

        -- Need to detect end of reset cycle to assert AWREADY on AXI bus
        REG_ARESETN: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                axi_aresetn_d1 <= S_AXI_AResetn;
                axi_aresetn_d2 <= axi_aresetn_d1;
                axi_aresetn_re_reg <= axi_aresetn_re;
            end if;

        end process REG_ARESETN;


        -- Create combinatorial RE detect of S_AXI_AResetn
        axi_aresetn_re <= '1' when (S_AXI_AResetn = '1' and axi_aresetn_d1 = '0') else '0';



    end generate GEN_AWREADY;



    ----------------------------------------------------------------------------



    -- Specify current AWSIZE signal 
    -- Address pipeline MUX
    curr_awsize <= axi_awsize_pipe when (awaddr_pipe_sel = '1') else AXI_AWSIZE;


    -- Register curr_awsize when bram_addr_ld_en = '1'

    REG_AWSIZE: process (S_AXI_AClk)
    begin
    
        if (S_AXI_AClk'event and S_AXI_AClk = '1') then
    
            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                curr_awsize_reg <= (others => '0');
                
            elsif (bram_addr_ld_en = '1') then
                curr_awsize_reg <= curr_awsize;
                
            else
                curr_awsize_reg <= curr_awsize_reg;
            end if;
    
        end if;
    end process REG_AWSIZE;




    

    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_NARROW_EN
    -- Purpose:     Only instantiate logic to determine if current burst
    --              is a narrow burst when narrow bursting logic is supported.
    --
    ---------------------------------------------------------------------------

    GEN_NARROW_EN: if (C_S_AXI_SUPPORTS_NARROW = 1) generate
    begin


        -----------------------------------------------------------------------
        -- Determine "narrow" burst transfers
        -- Compare the AWSIZE to the BRAM data width
        -----------------------------------------------------------------------

        -- v1.03a
        -- Detect if current burst operation is of size /= to the full
        -- AXI data bus width.  If not, then the current operation is a 
        -- "narrow" burst.
        
        curr_narrow_burst_cmb <= '1' when (curr_awsize /= C_AXI_SIZE_MAX) else '0';


        ---------------------------------------------------------------------------


        curr_narrow_burst_en <= '1' when (bram_addr_ld_en = '1') and 
                                     (curr_awlen /= AXI_AWLEN_ONE) and 
                                     (curr_fixed_burst = '0')
                                    else '0';


        -- Register flag indicating the current operation
        -- is a narrow write burst
        NARROW_BURST_REG: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                -- Need to reset this flag at end of narrow burst operation
                -- Use handshaking signals on AXI
                if (S_AXI_AResetn = C_RESET_ACTIVE) or 

                    -- Check for back to back narrow burst.  If that is the case, then
                    -- do not clear curr_narrow_burst flag.

                   (axi_wlast_re = '1' and
                    curr_narrow_burst_en = '0'
                    
                    -- If ECC is enabled, no clear to curr_narrow_burst when WLAST is asserted
                    -- this causes the BRAM address to incorrectly get asserted on the last
                    -- beat in the burst (due to delay in RMW logic)
                    
                    and C_ECC = 0) then

                    curr_narrow_burst <= '0';                  


                elsif (curr_narrow_burst_en = '1') then
                    curr_narrow_burst <= curr_narrow_burst_cmb;
                end if;

            end if;

        end process NARROW_BURST_REG;


        ---------------------------------------------------------------------------

        -- Detect RE of AXI_WLAST
        -- Only used when narrow bursts are enabled.
        
        WLAST_REG: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    axi_wlast_d1 <= '0';
                else
                    -- axi_wlast_d1 <= AXI_WLAST and axi_wready_int_mod;
                    -- CR # 609695
                    axi_wlast_d1 <= AXI_WLAST and axi_wready_int_mod and AXI_WVALID;
                end if;

            end if;

        end process WLAST_REG;

        -- axi_wlast_re <= (AXI_WLAST and axi_wready_int_mod) and not (axi_wlast_d1);
        -- CR # 609695
        axi_wlast_re <= (AXI_WLAST and axi_wready_int_mod and AXI_WVALID) and not (axi_wlast_d1);



    end generate GEN_NARROW_EN;




    ---------------------------------------------------------------------------
    -- Generate registered flag that active burst is a "narrow" burst
    -- and load narrow burst counter
    ---------------------------------------------------------------------------



    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_NARROW_CNT_LD
    -- Purpose:     Only instantiate logic to determine narrow burst counter
    --              load value when narrow bursts are enabled.
    --
    ---------------------------------------------------------------------------

    GEN_NARROW_CNT_LD: if (C_S_AXI_SUPPORTS_NARROW = 1) generate
    
    signal curr_awsize_unsigned : unsigned (2 downto 0) := (others => '0');
    signal axi_byte_div_curr_awsize : integer := 1;
    
    begin


        -- v1.03a
        -- Create narrow burst counter load value based on current operation
        -- "narrow" data width (indicated by value of AWSIZE).
        
        curr_awsize_unsigned <= unsigned (curr_awsize);
            
        -- XST does not support divisors that are not constants and powers of 2.
        -- Create process to create a fixed value for divisor.
        
        -- Replace this statement:
        --     narrow_burst_cnt_ld <= std_logic_vector (
        --                             to_unsigned (
        --                                    (C_AXI_DATA_WIDTH_BYTES / (2**(to_integer (curr_awsize_unsigned))) ) - 1, 
        --                                     C_NARROW_BURST_CNT_LEN));
        
        
        --     -- With this new process and subsequent signal assignment:
        --     DIV_AWSIZE: process (curr_awsize_unsigned)
        --     begin
        --     
        --         case (to_integer (curr_awsize_unsigned)) is
        --             when 0 =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 1;
        --             when 1 =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 2;
        --             when 2 =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 4;
        --             when 3 =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 8;
        --             when 4 =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 16;
        --             when 5 =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 32;
        --             when 6 =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 64;
        --             when 7 =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 128;
        --         --coverage off
        --             when others => axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES;
        --         --coverage on
        --         end case;
        --     
        --     end process DIV_AWSIZE;


        -- w/ CR # 609695

        -- With this new process and subsequent signal assignment:
        DIV_AWSIZE: process (curr_awsize_unsigned)
        begin

            case (curr_awsize_unsigned) is
                when "000" =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 1;
                when "001" =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 2;
                when "010" =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 4;
                when "011" =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 8;
                when "100" =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 16;
                when "101" =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 32;
                when "110" =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 64;
                when "111" =>   axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES / 128;
            --coverage off
                when others => axi_byte_div_curr_awsize <= C_AXI_DATA_WIDTH_BYTES;
            --coverage on
            end case;

        end process DIV_AWSIZE;

        
        
        ---------------------------------------------------------------------------
        
        -- Create narrow burst count load value.
        --
        -- Size is based on [C_NARROW_BURST_CNT_LEN-1 : 0]
        -- For 32-bit BRAM, C_NARROW_BURST_CNT_LEN = 2.
        -- For 64-bit BRAM, C_NARROW_BURST_CNT_LEN = 3.
        -- For 128-bit BRAM, C_NARROW_BURST_CNT_LEN = 4. (etc.)
        --
        -- Signal, narrow_burst_cnt_ld signal is sized according to C_AXI_DATA_WIDTH.
        

        -- Updated else clause for simulation warnings w/ CR # 609695

        narrow_burst_cnt_ld <= std_logic_vector (
                                to_unsigned (
                                        (axi_byte_div_curr_awsize) - 1, 
                                        C_NARROW_BURST_CNT_LEN))
                               when (axi_byte_div_curr_awsize > 0)
                               else std_logic_vector (to_unsigned (0, C_NARROW_BURST_CNT_LEN));


        ---------------------------------------------------------------------------

        -- Register narrow_burst_cnt_ld
        REG_NAR_BRST_CNT_LD: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1') then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    narrow_burst_cnt_ld_reg <= (others => '0');
                elsif (bram_addr_ld_en = '1') then 
                    narrow_burst_cnt_ld_reg <= narrow_burst_cnt_ld;
                else
                    narrow_burst_cnt_ld_reg <= narrow_burst_cnt_ld_reg;
                end if;

            end if;
        end process REG_NAR_BRST_CNT_LD;


        ---------------------------------------------------------------------------
   


    end generate GEN_NARROW_CNT_LD;





    ----------------------------------------------------------------------------

    -- Specify current AWBURST signal 
    -- Input address pipeline MUX
    curr_awburst <= axi_awburst_pipe when (awaddr_pipe_sel = '1') else AXI_AWBURST;

    ----------------------------------------------------------------------------

    -- Specify current AWBURST signal 
    -- Input address pipeline MUX
    curr_awlen <= axi_awlen_pipe when (awaddr_pipe_sel = '1') else AXI_AWLEN;

    
    
    
    -- Duplicate early decode of AWLEN value to use in wr_b2b_elgible logic
    
    REG_CURR_AWLEN: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                curr_awlen_reg_1_or_2 <= '0';

            elsif (bram_addr_ld_en = '1') then

                -- Create merge to decode AWLEN of ONE or TWO
                if (curr_awlen = AXI_AWLEN_ONE) or (curr_awlen = AXI_AWLEN_TWO) then
                    curr_awlen_reg_1_or_2 <= '1';
                else
                    curr_awlen_reg_1_or_2 <= '0';
                end if;
            else
                curr_awlen_reg_1_or_2 <= curr_awlen_reg_1_or_2;
            end if;
        end if;

    end process REG_CURR_AWLEN;
    
        
    
    
    ----------------------------------------------------------------------------





    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_UA_NARROW
    -- Purpose:     Only instantiate logic for burst narrow WRAP operations when
    --              AXI bus protocol is not set for AXI-LITE and narrow
    --              burst operations are supported.
    --
    ---------------------------------------------------------------------------
       
    GEN_UA_NARROW: if (C_S_AXI_SUPPORTS_NARROW = 1) generate
    begin


        ---------------------------------------------------------------------------

        -- New logic to detect unaligned address on a narrow WRAP burst transaction.
        -- If this condition is met, then the narrow burst counter will be
        -- initially loaded with an offset value corresponding to the unalignment
        -- in the ARADDR value.


        -- Create a sub module for all logic to determine the narrow burst counter
        -- offset value on unaligned WRAP burst operations.
        
        -- Module generates the following signals:
        --
        --      => curr_ua_narrow_wrap, to indicate the current
        --         operation is an unaligned narrow WRAP burst.
        --
        --      => curr_ua_narrow_incr, to load narrow burst counter
        --         for unaligned INCR burst operations.
        --
        --      => ua_narrow_load, narrow counter load value.
        --         Sized, (C_NARROW_BURST_CNT_LEN-1 downto 0)
        --        
        ---------------------------------------------------------------------------
      

        ---------------------------------------------------------------------------
        -- Instance: I_UA_NARROW
        --
        -- Description:
        --
        --      Creates a narrow burst count load value when an operation
        --      is an unaligned narrow WRAP or INCR burst type.  Used by
        --      I_NARROW_CNT module.
        --
        --      Logic is customized for each C_AXI_DATA_WIDTH.
        ---------------------------------------------------------------------------

        I_UA_NARROW : entity work.ua_narrow
        generic map (
            C_AXI_DATA_WIDTH            =>  C_AXI_DATA_WIDTH            ,
            C_BRAM_ADDR_ADJUST_FACTOR   =>  C_BRAM_ADDR_ADJUST_FACTOR   ,
            C_NARROW_BURST_CNT_LEN      =>  C_NARROW_BURST_CNT_LEN
        )
        port map (

            curr_wrap_burst             =>  curr_wrap_burst             ,       -- in
            curr_incr_burst             =>  curr_incr_burst             ,       -- in
            bram_addr_ld_en             =>  bram_addr_ld_en             ,       -- in

            curr_axlen                  =>  curr_awlen                  ,       -- in
            curr_axsize                 =>  curr_awsize                 ,       -- in
            curr_axaddr_lsb             =>  curr_awaddr_lsb             ,       -- in
            
            curr_ua_narrow_wrap         =>  curr_ua_narrow_wrap         ,       -- out
            curr_ua_narrow_incr         =>  curr_ua_narrow_incr         ,       -- out
            ua_narrow_load              =>  ua_narrow_load                      -- out

        );    
    
    
    
        -- Use in all C_AXI_DATA_WIDTH generate statements

        -- Only probe least significant BRAM address bits
        -- C_BRAM_ADDR_ADJUST_FACTOR offset down to 0.
        curr_awaddr_lsb <= axi_awaddr_pipe (C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0) 
                            when (awaddr_pipe_sel = '1') else 
                        AXI_AWADDR (C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0);




    end generate GEN_UA_NARROW;

   
    

    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_AW_SNG
    -- Purpose:     If single port BRAM configuration, set all AW flags from
    --              logic generated in sng_port_arb module.
    --
    ---------------------------------------------------------------------------
    

    GEN_AW_SNG: if (C_SINGLE_PORT_BRAM = 1) generate
    begin
        
        aw_active <= Arb2AW_Active;
        bram_addr_ld_en <= aw_active_re;
        AW2Arb_Active_Clr <= aw_active_clr;
        AW2Arb_Busy <= wr_busy_reg;
        AW2Arb_BVALID_Cnt <= bvalid_cnt;
        
 
    end generate GEN_AW_SNG;    
    
    
    
    -- Rising edge detect of aw_active
    -- For single port configurations, aw_active = Arb2AW_Active.
    -- For dual port configurations, aw_active generated in ADDR SM.
    RE_AW_ACT: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1') then
            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                aw_active_d1 <= '0';
            else
                aw_active_d1 <= aw_active;
            end if;
        end if;
    end process RE_AW_ACT;
    
    aw_active_re <= '1' when (aw_active = '1' and aw_active_d1 = '0') else '0';

    

    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_AW_DUAL
    -- Purpose:     Generate AW control state machine logic only when AXI4
    --              controller is configured for dual port mode.  In dual port
    --              mode, wr_chnl has full access over AW & port A of BRAM.
    --
    ---------------------------------------------------------------------------
    
    
    GEN_AW_DUAL: if (C_SINGLE_PORT_BRAM = 0) generate
    begin


        AW2Arb_Active_Clr <= '0';   -- Only used in single port case
        AW2Arb_Busy <= '0';         -- Only used in single port case

        AW2Arb_BVALID_Cnt <= (others => '0');


        ----------------------------------------------------------------------------


        
        REG_LAST_DATA_ACK: process (S_AXI_AClk)
        begin
            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    last_data_ack_mod <= '0';
                else
                    -- last_data_ack_mod <= AXI_WLAST;
                    -- CR # 609695
                    last_data_ack_mod <= AXI_WLAST and AXI_WVALID and axi_wready_int_mod;
                end if;
            end if;
        end process REG_LAST_DATA_ACK;



        ----------------------------------------------------------------------------




        ---------------------------------------------------------------------------
        -- WR ADDR State Machine
        --
        -- Description:     Central processing unit for AXI write address
        --                  channel interface handling and handshaking.
        --
        -- Outputs:         awaddr_pipe_ld      Combinatorial
        --                  awaddr_pipe_sel
        --                  bram_addr_ld_en
        --
        --
        --
        -- WR_ADDR_SM_CMB_PROCESS:      Combinational process to determine next state.
        -- WR_ADDR_SM_REG_PROCESS:      Registered process of the state machine.
        ---------------------------------------------------------------------------
        WR_ADDR_SM_CMB_PROCESS: process ( AXI_AWVALID,
                                          bvalid_cnt_max,
                                          axi_awaddr_full,
                                          aw_active,

                                          wr_b2b_elgible,           
                                          last_data_ack_mod,        

                                          wr_addr_sm_cs )

        begin

        -- assign default values for state machine outputs
        wr_addr_sm_ns <= wr_addr_sm_cs;
        awaddr_pipe_ld_i <= '0';
        bram_addr_ld_en_i <= '0';
        aw_active_set_i <= '0';


        case wr_addr_sm_cs is


                ---------------------------- IDLE State ---------------------------

                when IDLE =>


                    -- Check for pending operation in address pipeline that may
                    -- be elgible for back-to-back performance to BRAM.

                    -- Prevent loading BRAM address counter if BID FIFO can not
                    -- store the AWID value.  Check the BVALID counter.

                    if (wr_b2b_elgible = '1') and (last_data_ack_mod = '1') and
                       -- Ensure the BVALID counter does not roll over (max = 8 ID values)
                       (bvalid_cnt_max = '0') then

                        wr_addr_sm_ns <= IDLE;

                        -- Load BRAM address counter from pipelined value
                        bram_addr_ld_en_i <= '1';

                        aw_active_set_i <= '1';


                    -- Ensure AWVALID is recognized.
                    -- Address pipeline may be loaded, but BRAM counter 
                    -- can not be loaded if at max of BID FIFO.
                    
                    elsif (AXI_AWVALID = '1') then
                           
                        -- If address pipeline is full
                        -- AWReady output is negated

                        -- If write address logic is ready for new operation
                        -- Load BRAM address counter and set aw_active = '1'
                        -- If address pipeline is already full to start next operation
                        -- load address counter from pipeline.

                        -- Prevent loading BRAM address counter if BID FIFO can not
                        -- store the AWID value.  Check the BVALID counter.
                    
                        -- Remain in this state
                        if (aw_active = '0') and 
                          -- Ensure the BVALID counter does not roll over (max = 8 ID values)
                           (bvalid_cnt_max = '0') then

                            wr_addr_sm_ns <= IDLE;
                            
                            -- Stay in this state to capture AWVALID if asserted
                            -- in next clock cycle.

                            bram_addr_ld_en_i <= '1';

                            aw_active_set_i <= '1';


                        -- Address counter is currently busy.
                        -- No check on BVALID counter for address pipeline load.
                        -- Only the BRAM address counter is checked for BID FIFO capacity.
                        
                        else

                            -- Check if AWADDR pipeline is not full and can be loaded
                            if (axi_awaddr_full = '0') then

                                wr_addr_sm_ns <= LD_AWADDR;
                                awaddr_pipe_ld_i <= '1';

                            end if;

                        end if; -- aw_active


                    -- Pending operation in pipeline that is waiting
                    -- until current operation is complete (aw_active = '0')

                    elsif (axi_awaddr_full = '1') and (aw_active = '0') and 
                          -- Ensure the BVALID counter does not roll over (max = 8 ID values)
                          (bvalid_cnt_max = '0') then

                        wr_addr_sm_ns <= IDLE;

                        -- Load BRAM address counter from pipelined value
                        bram_addr_ld_en_i <= '1';

                        aw_active_set_i <= '1';

                    end if; -- AWVALID




                ---------------------------- LD_AWADDR State ---------------------------

                when LD_AWADDR =>

                    wr_addr_sm_ns <= IDLE;

                    if (wr_b2b_elgible = '1') and (last_data_ack_mod = '1') and 
                       -- Ensure the BVALID counter does not roll over (max = 8 ID values)
                       (bvalid_cnt_max = '0') then

                        -- Load BRAM address counter from pipelined value
                        bram_addr_ld_en_i <= '1';

                        aw_active_set_i <= '1';

                    end if;


        --coverage off
                ------------------------------ Default ----------------------------
                when others =>
                    wr_addr_sm_ns <= IDLE;
        --coverage on

            end case;

        end process WR_ADDR_SM_CMB_PROCESS;



        ---------------------------------------------------------------------------

        -- CR # 582705
        -- Ensure combinatorial SM output signals do not get set before
        -- the end of the reset (and ARREAADY can be set).
        bram_addr_ld_en <= bram_addr_ld_en_i and axi_aresetn_d2;
        aw_active_set <= aw_active_set_i and axi_aresetn_d2;
        awaddr_pipe_ld <= awaddr_pipe_ld_i and axi_aresetn_d2;


        WR_ADDR_SM_REG_PROCESS: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                -- if (S_AXI_AResetn = C_RESET_ACTIVE) then

                -- CR # 582705
                -- Ensure that ar_active does not get asserted (from SM) before 
                -- the end of reset and the ARREADY flag is set.
                if (axi_aresetn_d2 = C_RESET_ACTIVE) then
                    wr_addr_sm_cs <= IDLE;                
                else
                    wr_addr_sm_cs <= wr_addr_sm_ns;
                end if;
            end if;

        end process WR_ADDR_SM_REG_PROCESS;


        ---------------------------------------------------------------------------

        -- Asserting awaddr_pipe_sel outside of SM logic
        -- The BRAM address counter will get loaded with value in AWADDR pipeline
        -- when data is stored in the AWADDR pipeline.

        awaddr_pipe_sel <= '1' when (axi_awaddr_full = '1') else '0';
        
        ---------------------------------------------------------------------------

        -- Register for aw_active 
        REG_AW_ACT: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
            
                -- CR # 582705
                -- if (S_AXI_AResetn = C_RESET_ACTIVE) then
                if (axi_aresetn_d2 = C_RESET_ACTIVE) then
                    aw_active <= '0';
                
                elsif (aw_active_set = '1') then 
                    aw_active <= '1';

                elsif (aw_active_clr = '1') then 
                    aw_active <= '0';
                else 
                    aw_active <= aw_active;
                end if;
            end if;
        end process REG_AW_ACT;

        ---------------------------------------------------------------------------


    end generate GEN_AW_DUAL;










    ---------------------------------------------------------------------------
    -- *** AXI Write Data Channel Interface ***
    ---------------------------------------------------------------------------




    ---------------------------------------------------------------------------
    -- AXI WrData Buffer/Register
    ---------------------------------------------------------------------------

    GEN_WRDATA: for i in C_AXI_DATA_WIDTH-1 downto 0 generate
    begin

        REG_WRDATA: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (wrdata_reg_ld = '1') then
                    bram_wrdata_int (i) <= AXI_WDATA (i);
                else
                    bram_wrdata_int (i) <= bram_wrdata_int (i);

                end if;
            end if;

        end process REG_WRDATA;

    end generate GEN_WRDATA;




    ---------------------------------------------------------------------------
    -- Generate:    GEN_WR_NO_ECC
    -- Purpose:     Generate BRAM WrData and WE signals based on AXI_WRDATA
    --              and AXI_WSTRBs when C_ECC is disabled.
    ---------------------------------------------------------------------------

    GEN_WR_NO_ECC: if C_ECC = 0 generate
    begin
    

        ---------------------------------------------------------------------------
        -- AXI WSTRB Buffer/Register
        -- Use AXI write data channel data strobe signals to generate BRAM WE.
        ---------------------------------------------------------------------------

        REG_BRAM_WE: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                -- Ensure we don't clear WE when loading subsequent WSTRB value
                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   (clr_bram_we = '1' and bram_we_ld = '0') then 
                    bram_we_int <= (others => '0');

                elsif (bram_we_ld = '1') then                          
                    bram_we_int <= AXI_WSTRB;

                else
                    bram_we_int <= bram_we_int;  
                end if;

            end if;

        end process REG_BRAM_WE;




        ----------------------------------------------------------------------------

        -- New logic to detect if pending operation in AWADDR pipeline is
        -- elgible for back-to-back no "bubble" performance. And BRAM address
        -- counter can be loaded upon last BRAM address presented for the current
        -- operation.

        -- This condition exists when the AWADDR pipeline is full and the pending
        -- operation is a burst >= length of two data beats.
        -- And not a FIXED burst type (must be INCR or WRAP type).
        --
        -- Narrow bursts are be neglible 
        --
        -- Add check to complete current single and burst of two data bursts
        -- prior to loading BRAM counter

        wr_b2b_elgible <= '1' when (axi_awaddr_full = '1') and

                                    -- Replace comparator logic here with register signal (pre pipeline stage
                                    -- on axi_awlen_pipe value
                                    -- Use merge in decode of ONE or TWO
                                   (axi_awlen_pipe_1_or_2 /= '1') and

                                   (axi_awburst_pipe_fixed /= '1') and

                                   -- Use merge in decode of ONE or TWO
                                   (curr_awlen_reg_1_or_2 /= '1')

                            else '0';


        ----------------------------------------------------------------------------


    end generate GEN_WR_NO_ECC;


    ---------------------------------------------------------------------------
    -- Generate:    GEN_WR_ECC
    -- Purpose:     Generate BRAM WrData and WE signals based on AXI_WRDATA
    --              and AXI_WSTRBs when C_ECC is enabled.
    ---------------------------------------------------------------------------

    GEN_WR_ECC: if C_ECC = 1 generate
    begin
    
    
        wr_b2b_elgible <= '0';

        ---------------------------------------------------------------------------
        -- AXI WSTRB Buffer/Register
        -- Use AXI write data channel data strobe signals to generate BRAM WE.
        ---------------------------------------------------------------------------

        REG_BRAM_WE: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                -- Ensure we don't clear WE when loading subsequent WSTRB value
                if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                   (reset_bram_we = '1') then
                    bram_we_int <= (others => '0');

                elsif (set_bram_we = '1') then
                    bram_we_int <= (others => '1');

                else
                    bram_we_int <= bram_we_int;  
                end if;

            end if;

        end process REG_BRAM_WE;


    end generate GEN_WR_ECC;



    -----------------------------------------------------------------------



    -- v1.03a

    -----------------------------------------------------------------------
    --
    --  Implement WREADY to be a registered output.  Used by all configurations.
    --  This will disable the back-to-back streamlined WDATA
    --  for write operations to BRAM.
    --
    -----------------------------------------------------------------------
    
    REG_WREADY: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                axi_wready_int_mod <= '0';

            -- Keep AXI WREADY asserted unless write data register is full
            -- Use combinatorial signal from SM.
            
            elsif (axi_wdata_full_cmb = '1') then
                axi_wready_int_mod <= '0';
            else
                axi_wready_int_mod <= '1';

            end if;
        end if;

    end process REG_WREADY;

    
        

    ---------------------------------------------------------------------------







    ----------------------------------------------------------------------------
    -- Generate:    GEN_WDATA_SM_ECC
    -- Purpose:     Create seperate SM for ECC read-modify-write logic.
    --              Only used in single port BRAM mode.  So, no address
    --              pipelining.  Must use aw_active from arbitration logic
    --              to determine start of write to BRAM.
    --
    ----------------------------------------------------------------------------

    -- Test using same write data SM for single or dual port configuration.
    -- The difference is the source of aw_active.  In a single port configuration,
    -- the aw_active is coming from the arbiter SM.  In a dual port configuration,
    -- the aw_active is coming from the write address SM in this module.

    GEN_WDATA_SM_ECC: if C_ECC = 1 generate
    begin

        -- Unused in this SM configuration
        bram_we_ld <= '0';
        bram_addr_rst_cmb <= '0';    

        -- Output only used by ECC register module.
        Active_Wr <= active_wr_reg;


        ---------------------------------------------------------------------------
        --
        -- WR DATA State Machine
        --
        -- Description:     Central processing unit for AXI write data
        --                  channel interface handling and AXI write data response
        --                  handshaking when ECC is enabled.  SM will handle
        --                  each transaction as a read-modify-write to ensure
        --                  the correct ECC bits are stored in BRAM.
        --
        --                  Dedicated to single port BRAM interface.  Transaction
        --                  is not initiated until valid AWADDR is arbitration,
        --                  ie. aw_active will be asserted.  SM can do early reads
        --                  while waiting for WVALID to be asserted.
        --
        --                  Valid AWADDR recieve indicator comes from arbitration 
        --                  logic (aw_active will be asserted).
        --
        -- Outputs:         Name                    Type
        --
        --                  aw_active_clr           Not Registered
        --                  axi_wdata_full_reg      Registered
        --                  wrdata_reg_ld           Not Registered
        --                  bvalid_cnt_inc          Not Registered 
        --                  bram_addr_inc           Not Registered
        --                  bram_en_int             Registered
        --                  reset_bram_we           Not Registered
        --                  set_bram_we             Not Registered
        --
        --
        -- WR_DATA_ECC_SM_CMB_PROCESS:      Combinational process to determine next state.
        -- WR_DATA_ECC_SM_REG_PROCESS:      Registered process of the state machine.
        --
        ---------------------------------------------------------------------------

        WR_DATA_ECC_SM_CMB_PROCESS: process (   AXI_WVALID,
                                                AXI_WLAST,
                                                aw_active,
                                                wr_busy_reg,
                                                axi_wdata_full_reg,
                                                axi_wr_burst,   
                                                AXI_BREADY,
                                                active_wr_reg,
                                                wr_data_ecc_sm_cs )

        begin

        -- Assign default values for state machine outputs
        wr_data_ecc_sm_ns <= wr_data_ecc_sm_cs;
        aw_active_clr <= '0';
        wr_busy_cmb <= wr_busy_reg;
        bvalid_cnt_inc <= '0';              
        
        wrdata_reg_ld <= '0';
        reset_bram_we <= '0';
        set_bram_we_cmb <= '0';
        bram_en_cmb <= '0';
        bram_addr_inc <= '0';

        axi_wdata_full_cmb <= axi_wdata_full_reg;
        axi_wr_burst_cmb <= axi_wr_burst;   
        active_wr_cmb <= active_wr_reg;


        case wr_data_ecc_sm_cs is


                ---------------------------- IDLE State ---------------------------

                when IDLE =>


                    -- Prior to AWVALID assertion, WVALID may be asserted
                    -- and data accepted into WDATA register.
                    -- Catch this condition and ensure the register full flag is set.
                    -- Check that data pipeline is not already full.
                    
                    if (AXI_WVALID = '1') and (axi_wdata_full_reg = '0') then
                        
                        wrdata_reg_ld <= '1';               -- Load write data register
                        axi_wdata_full_cmb <= '1';          -- Hold off accepting any new write data
                        
                        -- w/ CR # 609695
                        --
                        --   -- Set flag to check if single or not
                        --   if (AXI_WLAST = '1') then
                        --       axi_wr_burst_cmb <= '0';
                        --   else
                        --       axi_wr_burst_cmb <= '1';
                        --   end if;
                        
                        axi_wr_burst_cmb <= not (AXI_WLAST);    -- Set flag to check if single or not
                   
                    end if;



                    -- Check if AWVALID is asserted & wins arbitration
                    if (aw_active = '1') then
                    
                        active_wr_cmb <= '1';           -- Set flag that RMW SM is active
                                                        -- Controls mux select for BRAM and ECC register module 
                                                        -- (Set to '1' wr_chnl or '0' for rd_chnl control)
                        
                        bram_en_cmb <= '1';             -- Initiate BRAM read transfer
                        reset_bram_we <= '1';           -- Disable Port A write enables

                        -- Will proceed to read-modify-write if we get a
                        -- valid write address early (before WVALID)

                        wr_data_ecc_sm_ns <= RMW_RD_DATA;


                    end if; -- WVALID


                ------------------------- RMW_RD_DATA State -------------------------

                when RMW_RD_DATA =>


                    -- Check if data to write is available in data pipeline
                    if (axi_wdata_full_reg = '1') then
                        wr_data_ecc_sm_ns <= RMW_CHK_DATA;   
                        
                    
                    -- Else may have address, but not yet data from W channel
                    elsif (AXI_WVALID = '1') then
                        
                        -- Ensure that WDATA pipeline is marked as full, so WREADY negates
                        axi_wdata_full_cmb <= '1';          -- Hold off accepting any new write data
                        
                        wrdata_reg_ld <= '1';               -- Load write data register
                    
                        -- w/ CR # 609695
                        --
                        --   -- Set flag to check if single or not
                        --   if (AXI_WLAST = '1') then
                        --       axi_wr_burst_cmb <= '0';
                        --   else
                        --       axi_wr_burst_cmb <= '1';
                        --   end if;
                        
                        axi_wr_burst_cmb <= not (AXI_WLAST);    -- Set flag to check if single or not
                        
                        wr_data_ecc_sm_ns <= RMW_CHK_DATA;   

                    else
                        -- Hold here and wait for write data
                        wr_data_ecc_sm_ns <= RMW_RD_DATA;

                    end if;



                ------------------------- RMW_CHK_DATA State -------------------------

                when RMW_CHK_DATA =>
                
                
                    -- New state here to add register stage on calculating
                    -- checkbits for read data and then muxing/creating new
                    -- checkbits for write cycle.
                    
                    
                    -- Go immediately to MODIFY stage in RMW sequence
                    wr_data_ecc_sm_ns <= RMW_MOD_DATA;

                    set_bram_we_cmb <= '1';             -- Enable all WEs to BRAM



                ------------------------- RMW_MOD_DATA State -------------------------

                when RMW_MOD_DATA =>


                    -- Modify clock cycle in RMW sequence
                    -- Only reach this state after a read AND we have data
                    -- in the write data pipeline to modify and subsequently write to BRAM.

                    bram_en_cmb <= '1';             -- Initiate BRAM write transfer
                    
                    -- Can clear WDATA pipeline full condition flag                   
                    if (axi_wr_burst = '1') then
                        axi_wdata_full_cmb <= '0';
                    end if;
                    
                    
                    wr_data_ecc_sm_ns <= RMW_WR_DATA;     -- Go to write data to BRAM
                    
                    
                    
                ------------------------- RMW_WR_DATA State -------------------------

                when RMW_WR_DATA =>


                    -- Check if last data beat in a burst (or the write is a single)
                    
                    if (axi_wr_burst = '0') then

                        -- Can clear WDATA pipeline full condition flag now that
                        -- write data has gone out to BRAM (for single data transfers)
                        axi_wdata_full_cmb <= '0';  
                        
                        bvalid_cnt_inc <= '1';              -- Set flag to assert BVALID and increment counter
                        wr_data_ecc_sm_ns <= IDLE;          -- Go back to IDLE, BVALID assertion is seperate
                        wr_busy_cmb <= '0';                 -- Clear flag to arbiter
                        active_wr_cmb <= '0';               -- Clear flag (wr_chnl is done accessing BRAM)
                                                            -- Used for single port arbitration SM
                        axi_wr_burst_cmb <= '0';
                        
                        
                        aw_active_clr <= '1';               -- Clear aw_active flag
                        reset_bram_we <= '1';               -- Disable Port A write enables   
                        
                    else
                    
                        -- Continue with read-modify-write sequence for write burst
                                                
                        -- If next data beat is available on AXI, capture the data
                        if (AXI_WVALID = '1') then
                            
                            wrdata_reg_ld <= '1';               -- Load write data register
                            axi_wdata_full_cmb <= '1';          -- Hold off accepting any new write data
                            
                            
                            -- w/ CR # 609695
                            --
                            --   -- Set flag to check if single or not
                            --   if (AXI_WLAST = '1') then
                            --       axi_wr_burst_cmb <= '0';
                            --   else
                            --       axi_wr_burst_cmb <= '1';
                            --   end if;
                            
                            axi_wr_burst_cmb <= not (AXI_WLAST);    -- Set flag to check if single or not
                            
                        end if;

                        
                        -- After write cycle (in RMW) => Increment BRAM address counter
                        bram_addr_inc <= '1';

                        bram_en_cmb <= '1';             -- Initiate BRAM read transfer
                        reset_bram_we <= '1';           -- Disable Port A write enables

                        -- Will proceed to read-modify-write if we get a
                        -- valid write address early (before WVALID)
                        wr_data_ecc_sm_ns <= RMW_RD_DATA;


                    end if;
                    

        --coverage off

                ------------------------------ Default ----------------------------

                when others =>
                    wr_data_ecc_sm_ns <= IDLE;

        --coverage on

            end case;

        end process WR_DATA_ECC_SM_CMB_PROCESS;


        ---------------------------------------------------------------------------


        WR_DATA_ECC_SM_REG_PROCESS: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    wr_data_ecc_sm_cs <= IDLE;
                    bram_en_int <= '0';
                    axi_wdata_full_reg <= '0';
                    wr_busy_reg <= '0';
                    active_wr_reg <= '0';
                    set_bram_we <= '0';

                else
                    wr_data_ecc_sm_cs <= wr_data_ecc_sm_ns;
                    bram_en_int <= bram_en_cmb;
                    axi_wdata_full_reg <= axi_wdata_full_cmb;
                    wr_busy_reg <= wr_busy_cmb;
                    active_wr_reg <= active_wr_cmb;
                    
                    set_bram_we <= set_bram_we_cmb;

                end if;
            end if;

        end process WR_DATA_ECC_SM_REG_PROCESS;



        ---------------------------------------------------------------------------


    end generate GEN_WDATA_SM_ECC;
    

    
    
    
    -- v1.03a
    
    

    ----------------------------------------------------------------------------
    --
    -- Generate:    GEN_WDATA_SM_NO_ECC_SNG_REG_WREADY
    -- Purpose:     Create seperate SM use case of no ECC (no read-modify-write)
    --              and single port BRAM configuration (no back to back operations
    --              are supported).  Must wait for aw_active from arbiter to indicate
    --              control on BRAM interface.
    --
    ----------------------------------------------------------------------------

    GEN_WDATA_SM_NO_ECC_SNG_REG_WREADY: if C_ECC = 0 and 
                                           C_SINGLE_PORT_BRAM = 1  
                                           generate
    begin


        -- Unused in this SM configuration
        wr_busy_cmb <= '0';             -- Unused
        wr_busy_reg <= '0';             -- Unused
        active_wr_cmb <= '0';           -- Unused
        active_wr_reg <= '0';           -- Unused
        Active_Wr <= '0';               -- Unused
        
        

        ---------------------------------------------------------------------------
        --
        -- WR DATA State Machine
        --
        -- Description:     Central processing unit for AXI write data
        --                  channel interface handling and AXI write data response
        --                  handshaking.
        --
        -- Outputs:         Name                    Type
        --                  aw_active_clr           Not Registered
        --                  bvalid_cnt_inc          Not Registered  
        --                  wrdata_reg_ld           Not Registered
        --                  bram_we_ld              Not Registered
        --                  bram_en_int             Registered
        --                  clr_bram_we             Registered
        --                  bram_addr_inc           Not Registered
        --                  wrdata_reg_ld           Not Registered
        --
        --                  Note:
        --
        --                  On "narrow burst transfers" BRAM address only 
        --                  gets incremented at BRAM data width.
        --                  On WRAP bursts, the BRAM address must wrap when 
        --                  the max is reached
        --
        --
        --
        -- WR_DATA_SNG_SM_CMB_PROCESS:      Combinational process to determine next state.
        -- WR_DATA_SNG_SM_REG_PROCESS:      Registered process of the state machine.
        --
        ---------------------------------------------------------------------------

        WR_DATA_SNG_SM_CMB_PROCESS: process (   AXI_WVALID,
                                                AXI_WLAST,
                                                aw_active,
                                                
                                                axi_wr_burst,                                                
                                                axi_wdata_full_reg,

                                                wr_data_sng_sm_cs )

        begin

        -- assign default values for state machine outputs
        wr_data_sng_sm_ns <= wr_data_sng_sm_cs;
        aw_active_clr <= '0';
        
        bvalid_cnt_inc <= '0';         
        axi_wr_burst_cmb <= axi_wr_burst;    

        wrdata_reg_ld <= '0';
        bram_we_ld <= '0';

        bram_en_cmb <= '0';
        clr_bram_we_cmb <= '0';

        bram_addr_inc <= '0';
        bram_addr_rst_cmb <= '0';

        axi_wdata_full_cmb <= axi_wdata_full_reg;


        case wr_data_sng_sm_cs is


                ---------------------------- IDLE State ---------------------------

                when IDLE =>


                    -- Prior to AWVALID assertion, WVALID may be asserted
                    -- and data accepted into WDATA register.
                    -- Catch this condition and ensure the register full flag is set.
                    -- Check that data pipeline is not already full.
                    --
                    -- Modify WE pipeline and mux to BRAM
                    -- as well.  Since WE may be asserted early (when pipeline is loaded),
                    -- but not yet ready to go out to BRAM.
                    --
                    -- Only first data beat will be accepted early into data pipeline.
                    -- All remaining beats in a burst will only be accepted upon WVALID.
                    
                    if (AXI_WVALID = '1') and (axi_wdata_full_reg = '0') then
                        
                        wrdata_reg_ld <= '1';                   -- Load write data register
                        bram_we_ld <= '1';                      -- Load WE register
                        axi_wdata_full_cmb <= '1';              -- Hold off accepting any new write data
                        axi_wr_burst_cmb <= not (AXI_WLAST);    -- Set flag to check if single or not

                    end if;

                   
                    -- Wait for WVALID and aw_active to initiate write transfer
                    if (aw_active = '1' and 
                        (AXI_WVALID = '1' or axi_wdata_full_reg = '1')) then

                        
                        -- If operation is a single, then it goes directly out to BRAM
                        -- WDATA register is never marked as FULL in this case.

                        -- If data pipeline is not previously loaded, do so now.
                        if (axi_wdata_full_reg = '0') then
                            wrdata_reg_ld <= '1';           -- Load write data register
                            bram_we_ld <= '1';              -- Load WE register
                        end if;
                        
                        -- Initiate BRAM write transfer
                        bram_en_cmb <= '1';
                        
                        -- If data goes out to BRAM, mark data register as EMPTY
                        axi_wdata_full_cmb <= '0';

                        axi_wr_burst_cmb <= not (AXI_WLAST);    -- Set flag to check if single or not
                    
                        -- Check for singles, by checking WLAST assertion w/ WVALID
                        -- Only if write data pipeline is not yet filled, check WLAST
                        -- Otherwise, if pipeline is already full, use registered value of WLAST
                        -- to check for single vs. burst write operation.
                        if (AXI_WLAST = '1' and axi_wdata_full_reg = '0') or
                           (axi_wdata_full_reg = '1' and axi_wr_burst = '0') then

                            -- Single data write
                            wr_data_sng_sm_ns <= SNG_WR_DATA;

                            -- Set flag to assert BVALID and increment counter
                            bvalid_cnt_inc <= '1';

                            -- BRAM WE only asserted for single clock cycle
                            clr_bram_we_cmb <= '1';

                        else
                            -- Burst data write
                            wr_data_sng_sm_ns <= BRST_WR_DATA;

                        end if; -- WLAST             
                    
                    end if;


                ------------------------- SNG_WR_DATA State -------------------------

                when SNG_WR_DATA =>

                    
                    -- If WREADY is registered, then BVALID generation is seperate
                    -- from write data flow.
                                    
                    -- Go back to IDLE automatically
                    -- BVALID will get asserted seperately from W channel
                    wr_data_sng_sm_ns <= IDLE;
                    bram_addr_rst_cmb <= '1';
                    aw_active_clr <= '1';
                    

                    -- Check for capture of next data beat (WREADY will be asserted)
                    if (AXI_WVALID = '1') then
                    
                        wrdata_reg_ld <= '1';                   -- Load write data register
                        bram_we_ld <= '1';                      -- Load WE register
                        axi_wdata_full_cmb <= '1';              -- Hold off accepting any new write data
                        axi_wr_burst_cmb <= not (AXI_WLAST);    -- Set flag to check if single or not

                    else
                        axi_wdata_full_cmb <= '0';              -- If no next data, ensure data register is flagged EMPTY.

                    end if;                                        
                    
                    
                ------------------------- BRST_WR_DATA State -------------------------

                when BRST_WR_DATA =>


                    -- Reach this state at the 2nd data beat of a burst
                    -- AWADDR is already accepted
                    -- Continue to accept data from AXI write channel
                    -- and wait for assertion of WLAST

                    -- Check that WVALID remains asserted for burst
                    -- If negated, indicates throttling from AXI master
                    if (AXI_WVALID = '1') then

                        -- If WVALID is asserted for the 2nd and remaining 
                        -- data beats of the transfer
                        -- Continue w/ BRAM write enable assertion & advance
                        -- write data register
                        
                        -- Write data goes directly out to BRAM.
                        -- WDATA register is never marked as FULL in this case.
                        
                        wrdata_reg_ld <= '1';           -- Load write data register
                        bram_we_ld <= '1';              -- Load WE register

                        -- Initiate BRAM write transfer
                        bram_en_cmb <= '1';

                        -- Increment BRAM address counter
                        bram_addr_inc <= '1';


                        -- Check for last data beat in burst transfer
                        if (AXI_WLAST = '1') then

                            -- Last/single data write
                            wr_data_sng_sm_ns <= SNG_WR_DATA;

                            -- Set flag to assert BVALID and increment counter
                            bvalid_cnt_inc <= '1';

                            -- BRAM WE only asserted for single clock cycle
                            clr_bram_we_cmb <= '1';

                        end if; -- WLAST


                    -- Throttling
                    -- Suspend BRAM write & halt write data & WE register load
                    else

                        -- Negate write data register load
                        wrdata_reg_ld <= '0';

                        -- Negate WE register load
                        bram_we_ld <= '0';

                        -- Negate write to BRAM
                        bram_en_cmb <= '0';

                        -- Do not increment BRAM address counter
                        bram_addr_inc <= '0';

                    end if; -- WVALID



        --coverage off

                ------------------------------ Default ----------------------------

                when others =>
                    wr_data_sng_sm_ns <= IDLE;

        --coverage on

            end case;

        end process WR_DATA_SNG_SM_CMB_PROCESS;


        ---------------------------------------------------------------------------


        WR_DATA_SNG_SM_REG_PROCESS: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    wr_data_sng_sm_cs <= IDLE;
                    bram_en_int <= '0';
                    clr_bram_we <= '0';
                    axi_wdata_full_reg <= '0';
                    
                else
                    wr_data_sng_sm_cs <= wr_data_sng_sm_ns;
                    bram_en_int <= bram_en_cmb;
                    clr_bram_we <= clr_bram_we_cmb;
                    axi_wdata_full_reg <= axi_wdata_full_cmb;

                end if;
            end if;

        end process WR_DATA_SNG_SM_REG_PROCESS;


        ---------------------------------------------------------------------------



    end generate GEN_WDATA_SM_NO_ECC_SNG_REG_WREADY;
    





    ----------------------------------------------------------------------------
    --
    -- Generate:    GEN_WDATA_SM_NO_ECC_DUAL_REG_WREADY
    --
    -- Purpose:     Create seperate SM for new logic to register out WREADY
    --              signal.  Behavior for back-to-back operations is different
    --              than with combinatorial genearted WREADY output to AXI.
    --          
    --              New SM design supports seperate WREADY and BVALID responses.
    --
    --              New logic here for axi_bvalid_int output register based
    --              on counter design of BVALID.
    --
    ----------------------------------------------------------------------------

    GEN_WDATA_SM_NO_ECC_DUAL_REG_WREADY: if C_ECC = 0 and 
                                            C_SINGLE_PORT_BRAM = 0 
                                            generate

    begin

        
        -- Unused in this SM configuration               
        active_wr_cmb <= '0';           -- Unused
        active_wr_reg <= '0';           -- Unused
        Active_Wr <= '0';               -- Unused
        
        wr_busy_cmb <= '0';             -- Unused
        wr_busy_reg <= '0';             -- Unused


        ---------------------------------------------------------------------------
        --
        -- WR DATA State Machine
        --
        -- Description:     Central processing unit for AXI write data
        --                  channel interface handling and AXI write data response
        --                  handshaking.
        --
        -- Outputs:         Name                    Type
        --                  bvalid_cnt_inc          Not Registered  
        --                  aw_active_clr           Not Registered
        --                  delay_aw_active_clr     Registered
        --                  axi_wdata_full_reg      Registered
        --                  bram_en_int             Registered
        --                  wrdata_reg_ld           Not Registered
        --                  bram_we_ld              Not Registered
        --                  clr_bram_we             Registered
        --                  bram_addr_inc
        --
        --                  Note:
        --
        --                  On "narrow burst transfers" BRAM address only 
        --                  gets incremented at BRAM data width.
        --                  On WRAP bursts, the BRAM address must wrap when 
        --                  the max is reached
        --
        --                  Add check on BVALID counter max.  Check with
        --                  AWVALID assertions (since AWID is connected to AWVALID).
        --
        --
        -- WR_DATA_SM_CMB_PROCESS:      Combinational process to determine next state.
        -- WR_DATA_SM_REG_PROCESS:      Registered process of the state machine.
        --
        ---------------------------------------------------------------------------

        WR_DATA_SM_CMB_PROCESS: process ( AXI_WVALID,
                                          AXI_WLAST,
                                          bvalid_cnt_max,
                                          bvalid_cnt_amax,
                                          
                                          aw_active,
                                          delay_aw_active_clr,
                                          AXI_AWVALID,
                                          axi_awready_int,

                                          bram_addr_ld_en,          
                                          axi_awaddr_full,          
                                          awaddr_pipe_sel,          

                                          axi_wr_burst,
                                          axi_wdata_full_reg,

                                          wr_b2b_elgible,

                                          wr_data_sm_cs )

        begin

        -- assign default values for state machine outputs
        wr_data_sm_ns <= wr_data_sm_cs;
        aw_active_clr <= '0';
        delay_aw_active_clr_cmb <= delay_aw_active_clr;
        bvalid_cnt_inc <= '0';
        
        axi_wr_burst_cmb <= axi_wr_burst;    

        wrdata_reg_ld <= '0';
        bram_we_ld <= '0';

        bram_en_cmb <= '0';
        clr_bram_we_cmb <= '0';

        bram_addr_inc <= '0';      
        bram_addr_rst_cmb <= '0';
        axi_wdata_full_cmb <= axi_wdata_full_reg;
        

        case wr_data_sm_cs is


                ---------------------------- IDLE State ---------------------------

                when IDLE =>

                    -- Check valid write data on AXI write data channel
                    if (AXI_WVALID = '1') then

                        wrdata_reg_ld <= '1';       -- Load write data register
                        bram_we_ld <= '1';          -- Load WE register

                        -- Add condition to check for simultaneous assertion
                        -- of AWVALID and AWREADY                    
                        if ((aw_active = '1') or (AXI_AWVALID = '1' and axi_awready_int = '1')) and 
                           
                           -- Ensure the BVALID counter does not roll over (max = 8 ID values)
                           (bvalid_cnt_max = '0') then

                            -- Initiate BRAM write transfer
                            bram_en_cmb <= '1';

                            -- Check for singles, by checking WLAST assertion w/ WVALID
                            if (AXI_WLAST = '1') then

                                -- Single data write
                                wr_data_sm_ns <= SNG_WR_DATA;

                                -- Set flag to assert BVALID and increment counter
                                bvalid_cnt_inc <= '1';

                                -- Set flag to delay clear of AW active flag
                                delay_aw_active_clr_cmb <= '1'; 

                                -- BRAM WE only asserted for single clock cycle
                                clr_bram_we_cmb <= '1';

                                axi_wr_burst_cmb <= '0';

                            else
                                -- Burst data write
                                wr_data_sm_ns <= BRST_WR_DATA;
                                axi_wr_burst_cmb <= '1';

                            end if; -- WLAST

                        else

                            -- AWADDR not yet received
                            -- Go to wait for write address
                            wr_data_sm_ns <= W8_AWADDR;

                            -- Set flag that AXI write data pipe is full
                            -- and can not accept any more data beats
                            -- WREADY on AXI will negate in this condition.
                            axi_wdata_full_cmb <= '1';

                            -- Set flag for single/burst write operation
                            -- when AWADDR is not yet received
                            if (AXI_WLAST = '1') then
                                axi_wr_burst_cmb <= '0';
                            else
                                axi_wr_burst_cmb <= '1';

                            end if; -- WLAST

                        end if; -- aw_active

                    end if; -- WVALID


                ------------------------- W8_AWADDR State -------------------------

                when W8_AWADDR =>


                    -- As we transition into this state, the write data pipeline
                    -- is already filled.  axi_wdata_full_reg should be = '1'.


                    -- Disable any additional loads into write data register
                    -- Default value in SM is applied.
                    

                    -- Wait for write address to be acknowledged
                    if (((aw_active = '1') or (AXI_AWVALID = '1' and axi_awready_int = '1')) or

                        -- Detect load of BRAM address counter from value stored in pipeline.
                        -- No need to wait until aw_active is asserted or address is captured from AXI bus.
                        -- As BRAM address is loaded from pipe and ready to be presented to BRAM. 
                        -- Assert BRAM WE.

                        (bram_addr_ld_en = '1' and axi_awaddr_full = '1' and awaddr_pipe_sel = '1')) and
                        
                        
                        -- Ensure the BVALID counter does not roll over (max = 8 ID values)
                        (bvalid_cnt_max = '0') then


                        -- Initiate BRAM write transfer
                        bram_en_cmb <= '1';

                        -- Negate write data full condition
                        axi_wdata_full_cmb <= '0';
                        

                        -- Check if single or burst operation
                        if (axi_wr_burst = '1') then
                            wr_data_sm_ns <= BRST_WR_DATA;
                        else

                            wr_data_sm_ns <= SNG_WR_DATA;

                            -- BRAM WE only asserted for single clock cycle
                            clr_bram_we_cmb <= '1';

                            -- Set flag to assert BVALID and increment counter
                            bvalid_cnt_inc <= '1';

                            delay_aw_active_clr_cmb <= '1'; 


                        end if;

                    else

                        -- Set flag that AXI write data pipe is full
                        -- and can not accept any more data beats
                        -- WREADY on AXI will negate in this condition.
                        axi_wdata_full_cmb <= '1';

                    end if;


                ------------------------- SNG_WR_DATA State -------------------------

                when SNG_WR_DATA =>


                    
                    -- No need to check for BVALID assertion here.

                    -- Move here under if clause on write response channel
                    -- acknowledging completion of write data.
                    -- If aw_active was not cleared prior to this state, then
                    -- clear the flag now.

                    if (delay_aw_active_clr = '1') then
                        delay_aw_active_clr_cmb <= '0';
                        aw_active_clr <= '1';
                    end if;



                    -- Add check here if while writing single data beat to BRAM,
                    -- a new AXI data beat is received (prior to the AWVALID assertion).
                    -- Ensure here that full flag is asserted for data pipeline state.

                    -- Check valid write data on AXI write data channel
                    if (AXI_WVALID = '1') then

                        -- Load write data register
                        wrdata_reg_ld <= '1';

                        -- Must also load WE register
                        bram_we_ld <= '1';


                        -- Set flag that AXI write data pipe is full
                        -- and can not accept any more data beats
                        -- WREADY on AXI will negate in this condition.

                        -- Ensure that axi_wdata_full_reg is asserted
                        -- to prevent early captures on next data burst (or single data
                        -- transfer)
                        -- This ensures that the data beats do not get skipped.
                        axi_wdata_full_cmb <= '1';


                        -- AWADDR not yet received
                        -- Go to wait for write address
                        wr_data_sm_ns <= W8_AWADDR;

                        -- Accept no more new write data after this first data beat
                        -- Pipeline is already full in this state. No need to assert
                        -- no_wdata_accept flag to '1'.

                        -- Set flag for single/burst write operation
                        -- when AWADDR is not yet received
                        if (AXI_WLAST = '1') then
                            axi_wr_burst_cmb <= '0';
                        else
                            axi_wr_burst_cmb <= '1';
                        end if; -- WLAST


                    else

                        -- No subsequent pending operation
                        -- Return to IDLE
                        wr_data_sm_ns <= IDLE;

                        bram_addr_rst_cmb <= '1';

                    end if;






                ------------------------- BRST_WR_DATA State -------------------------

                when BRST_WR_DATA =>


                    -- Reach this state at the 2nd data beat of a burst
                    -- AWADDR is already accepted
                    -- Continue to accept data from AXI write channel
                    -- and wait for assertion of WLAST

                    -- Check that WVALID remains asserted for burst
                    -- If negated, indicates throttling from AXI master
                    if (AXI_WVALID = '1') then

                        -- If WVALID is asserted for the 2nd and remaining 
                        -- data beats of the transfer
                        -- Continue w/ BRAM write enable assertion & advance
                        -- write data register
                        
                        wrdata_reg_ld <= '1';           -- Load write data register
                        bram_we_ld <= '1';              -- Load WE register
                        bram_en_cmb <= '1';             -- Initiate BRAM write transfer
                        bram_addr_inc <= '1';           -- Increment BRAM address counter


                        -- Check for last data beat in burst transfer
                        if (AXI_WLAST = '1') then

                            -- Set flag to assert BVALID and increment counter
                            bvalid_cnt_inc <= '1';
                                
                            -- The elgible signal will not be asserted for a subsequent
                            -- single data beat operation. Next operation is a burst.
                            -- And the AWADDR is loaded in the address pipeline.

                            -- Only if BVALID counter can handle next transfer,
                            -- proceed with back-to-back.  Otherwise, go to IDLE
                            -- (after last data write).
                            
                            if (wr_b2b_elgible = '1' and bvalid_cnt_amax = '0') then


                                -- Go to next operation and handle as a 
                                -- back-to-back burst.  No empty clock cycles.

                                -- Go to handle new burst for back to back condition
                                wr_data_sm_ns <= B2B_W8_WR_DATA;

                                axi_wr_burst_cmb <= '1';
                                

                            -- No pending subsequent transfer (burst > 2 data beats) 
                            -- to process                        
                            else

                                -- Last/single data write
                                wr_data_sm_ns <= SNG_WR_DATA;
                                
                                -- Be sure to clear aw_active flag at end of write burst
                                -- But delay when the flag is cleared
                                delay_aw_active_clr_cmb <= '1'; 
                                
                            end if;


                        end if; -- WLAST


                    -- Throttling
                    -- Suspend BRAM write & halt write data & WE register load
                    else
                        
                        wrdata_reg_ld <= '0';               -- Negate write data register load
                        bram_we_ld <= '0';                  -- Negate WE register load
                        bram_en_cmb <= '0';                 -- Negate write to BRAM
                        bram_addr_inc <= '0';               -- Do not increment BRAM address counter



                    end if;     -- WVALID



                ------------------------- B2B_W8_WR_DATA --------------------------

                when B2B_W8_WR_DATA =>


                    -- Reach this state upon a back-to-back condition
                    -- when BVALID/BREADY handshake is received,
                    -- but WVALID is not yet asserted for subsequent transfer.


                    -- Check valid write data on AXI write data channel
                    if (AXI_WVALID = '1') then

                        -- Load write data register
                        wrdata_reg_ld <= '1';

                        -- Load WE register
                        bram_we_ld <= '1';

                        -- Initiate BRAM write transfer
                        bram_en_cmb <= '1';

                        -- Burst data write
                        wr_data_sm_ns <= BRST_WR_DATA;
                        axi_wr_burst_cmb <= '1';
            
                        -- Make modification to last_data_ack_mod signal
                        -- so that it is asserted when this state is reached
                        -- and the BRAM address counter gets loaded.


                    -- WVALID not yet asserted
                    else 

                        wrdata_reg_ld <= '0';           -- Negate write data register load
                        bram_we_ld <= '0';              -- Negate WE register load
                        bram_en_cmb <= '0';             -- Negate write to BRAM
                        bram_addr_inc <= '0';           -- Do not increment BRAM address counter

                    end if;


        --coverage off

                ------------------------------ Default ----------------------------

                when others =>
                    wr_data_sm_ns <= IDLE;

        --coverage on

            end case;

        end process WR_DATA_SM_CMB_PROCESS;


        ---------------------------------------------------------------------------


        WR_DATA_SM_REG_PROCESS: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    wr_data_sm_cs <= IDLE;
                    bram_en_int <= '0';
                    clr_bram_we <= '0';
                    delay_aw_active_clr <= '0';
                    axi_wdata_full_reg <= '0';

                else
                    wr_data_sm_cs <= wr_data_sm_ns;
                    bram_en_int <= bram_en_cmb;
                    clr_bram_we <= clr_bram_we_cmb;
                    delay_aw_active_clr <= delay_aw_active_clr_cmb;
                    axi_wdata_full_reg <= axi_wdata_full_cmb;

                end if;
            end if;

        end process WR_DATA_SM_REG_PROCESS;


        ---------------------------------------------------------------------------




    end generate GEN_WDATA_SM_NO_ECC_DUAL_REG_WREADY;





    ---------------------------------------------------------------------------

    WR_BURST_REG_PROCESS: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                axi_wr_burst <= '0';
            else
                axi_wr_burst <= axi_wr_burst_cmb;
            end if;
        end if;

    end process WR_BURST_REG_PROCESS;

    
    ---------------------------------------------------------------------------







    ---------------------------------------------------------------------------
    -- *** AXI Write Response Channel Interface ***
    ---------------------------------------------------------------------------


    -- v1.03a


    ---------------------------------------------------------------------------
    --
    -- 
    -- New FIFO storage for BID, so AWID can be stored in 
    -- a FIFO and B response is seperated from W response.
    --
    -- Use registered WREADY & BID FIFO in single port configuration.
    --
    ---------------------------------------------------------------------------
    
    
    -- Instantiate FIFO to store BID values to be asserted back on B channel.
    -- Only 8 entries deep, BVALID counter only allows W channel to be 8 ahead of
    -- B channel.
    -- 
    -- If AWID is a single bit wide, sythesis optimizes the module, srl_fifo, 
    -- to a single SRL16E library module.
    
    BID_FIFO: entity work.srl_fifo
    generic map (
        C_DATA_BITS  => C_AXI_ID_WIDTH,
        C_DEPTH      => 8
    )
    port map (
        Clk          => S_AXI_AClk,
        Reset        => bid_fifo_rst,
        FIFO_Write   => bid_fifo_ld_en,
        Data_In      => bid_fifo_ld,
        FIFO_Read    => bid_fifo_rd_en,
        Data_Out     => bid_fifo_rd,
        FIFO_Full    => open,
        Data_Exists  => bid_fifo_not_empty,
        Addr         => open
    );
    
    
    bid_fifo_rst <= not (S_AXI_AResetn);
    
    bid_fifo_ld_en <= bram_addr_ld_en; 
    bid_fifo_ld <= AXI_AWID when (awaddr_pipe_sel = '0') else axi_awid_pipe;
    
    -- Read from FIFO when BVALID is to be asserted on bus, or in a back-to-back assertion 
    -- when a BID value is available in the FIFO.
    bid_fifo_rd_en <= bid_fifo_not_empty and                    -- Only read if data is available.
    
                      ((bid_gets_fifo_load_d1) or               -- a) Do the FIFO read in the clock cycle
                                                                --    following the BID value directly
                                                                --    aserted on the B channel (from AWID or pipeline).
                                                                
                       (first_fifo_bid) or                      -- b) Read from FIFO when BID is previously stored
                                                                --    but BVALID is not yet asserted on AXI.
                                                                
                       (bvalid_cnt_dec));                       -- c) Or read when next BID value is to be updated 
                                                                --    on B channel (and exists waiting in FIFO).
    
    
    -- 1)   Special case (1st load in FIFO) (and single clock cycle turnaround needed on BID, from AWID).
    --      If loading the FIFO and BVALID is to be asserted in the next clock cycle
    --      Then capture this condition to read from FIFO in the subsequent clock cycle 
    --      (and clear the BID value stored in the FIFO).
    bid_gets_fifo_load <= '1' when (bid_fifo_ld_en = '1') and 
                                   (first_fifo_bid = '1' or b2b_fifo_bid = '1') else '0';
    
    first_fifo_bid <= '1' when ((bvalid_cnt_inc = '1') and (bvalid_cnt_non_zero = '0')) else '0';  
                                                                    
    
    -- 2)   An additional special case.
    --      When write data register is loaded for single (bvalid_cnt = "001", due to WLAST/WVALID)
    --      But, AWID not yet received (FIFO is still empty).
    --      If BID FIFO is still empty with the BVALID counter decrement, but simultaneously 
    --      is increment (same condition as first_fifo_bid).
    b2b_fifo_bid <= '1' when (bvalid_cnt_inc = '1' and bvalid_cnt_dec = '1' and 
                          bvalid_cnt = "001" and bid_fifo_not_empty = '0') else '0';


    -- Output BID register to B AXI channel
    REG_BID: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                axi_bid_int <= (others => '0');
                
            -- If loading the FIFO and BVALID is to be asserted in the next clock cycle
            -- Then output the AWID or pipelined value (the same BID that gets loaded into FIFO).
            elsif (bid_gets_fifo_load = '1') then   
                axi_bid_int <= bid_fifo_ld;
                
            -- If new value read from FIFO then ensure that value is updated on AXI.    
            elsif (bid_fifo_rd_en = '1') then
                axi_bid_int <= bid_fifo_rd;
            else
                axi_bid_int <= axi_bid_int;            
            end if;

        end if;
    end process REG_BID;



    -- Capture condition of BID output updated while the FIFO is also
    -- getting updated.  Read FIFO in the subsequent clock cycle to
    -- clear the value stored in the FIFO.
    
    REG_BID_LD: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                bid_gets_fifo_load_d1 <= '0';
            else
                bid_gets_fifo_load_d1 <= bid_gets_fifo_load;            
            end if;

        end if;
    end process REG_BID_LD;



   
        
    ---------------------------------------------------------------------------
    -- AXI_BRESP Output Register
    ---------------------------------------------------------------------------
    

    ---------------------------------------------------------------------------
    -- Generate:    GEN_BRESP
    -- Purpose:     Generate BRESP output signal when ECC is disabled.
    --              Only allowable output is RESP_OKAY.
    ---------------------------------------------------------------------------
    GEN_BRESP: if C_ECC = 0 generate
    begin
    
        REG_BRESP: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    axi_bresp_int <= (others => '0');

                -- elsif (AXI_WLAST = '1') then
                -- CR # 609695
                elsif ((AXI_WLAST and AXI_WVALID and axi_wready_int_mod) = '1') then

                    -- AXI BRAM only supports OK response for normal operations
                    -- Exclusive operations not yet supported
                    axi_bresp_int <= RESP_OKAY;
                else
                    axi_bresp_int <= axi_bresp_int;

                end if;
            end if;

        end process REG_BRESP;

    end generate GEN_BRESP;



    ---------------------------------------------------------------------------
    -- Generate:    GEN_BRESP_ECC
    -- Purpose:     Generate BRESP output signal when ECC is enabled
    --              If no ECC error condition is detected during the RMW
    --              sequence, then output will be RESP_OKAY.  When an
    --              uncorrectable error is detected, the output will RESP_SLVERR.
    ---------------------------------------------------------------------------
    
    GEN_BRESP_ECC: if C_ECC = 1 generate    
    
    signal UE_Q_reg   : std_logic := '0';    
    
    begin
    
        REG_BRESP: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then
                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    axi_bresp_int <= (others => '0');

                elsif (bvalid_cnt_inc_d1 = '1') then

                --coverage off
                
                    -- Exclusive operations not yet supported
                    -- If no ECC errors occur, respond with OK
                    if (UE_Q = '1') or (UE_Q_reg = '1') then
                        axi_bresp_int <= RESP_SLVERR;
                        
                --coverage on
                
                    else
                        axi_bresp_int <= RESP_OKAY;
                    end if;
                else
                    axi_bresp_int <= axi_bresp_int;
                end if;
            end if;

        end process REG_BRESP;
        
        
        -- Check if any error conditions occured during the write operation.
        -- Capture condition for each write transfer.
        
        REG_UE: process (S_AXI_AClk)
        begin

            if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

                -- Clear at end of current write (and ensure the flag is cleared
                -- at the beginning of a write transfer)
                if (S_AXI_AResetn = C_RESET_ACTIVE) or (aw_active_re = '1') or 
                   (AXI_BREADY = '1' and axi_bvalid_int = '1') then
                    UE_Q_reg <= '0';
                
                --coverage off

                elsif (UE_Q = '1') then
                    UE_Q_reg <= '1';

                --coverage on

                else
                    UE_Q_reg <= UE_Q_reg;
                end if;
            end if;

        end process REG_UE;

    end generate GEN_BRESP_ECC;





    -- v1.03a

    ---------------------------------------------------------------------------
    -- Instantiate BVALID counter outside of specific SM generate block.
    ---------------------------------------------------------------------------


    ---------------------------------------------------------------------------

    -- BVALID counter to track the # of required BVALID/BREADY handshakes
    -- needed to occur on the AXI interface.  Based on early and seperate
    -- AWVALID/AWREADY and WVALID/WREADY handshake exchanges.

    REG_BVALID_CNT: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) then
                bvalid_cnt <= (others => '0');

            -- Ensure we only increment counter wyhen BREADY is not asserted
            elsif (bvalid_cnt_inc = '1') and (bvalid_cnt_dec = '0') then
                bvalid_cnt <= std_logic_vector (unsigned (bvalid_cnt (2 downto 0)) + 1);
        
            -- Ensure that we only decrement when SM is not incrementing
            elsif (bvalid_cnt_dec = '1') and (bvalid_cnt_inc = '0') then
                bvalid_cnt <= std_logic_vector (unsigned (bvalid_cnt (2 downto 0)) - 1);

            else
                bvalid_cnt <= bvalid_cnt;
            end if;

        end if;

    end process REG_BVALID_CNT;
    
    
    bvalid_cnt_dec <= '1' when (AXI_BREADY = '1' and 
                                axi_bvalid_int = '1' and 
                                bvalid_cnt_non_zero = '1') else '0';

    bvalid_cnt_non_zero <= '1' when (bvalid_cnt /= "000") else '0';  
    bvalid_cnt_amax <= '1' when (bvalid_cnt = "110") else '0';
    bvalid_cnt_max <= '1' when (bvalid_cnt = "111") else '0';
    


    -- Replace BVALID output register
    -- Assert BVALID as long as BVALID counter /= zero

    REG_BVALID: process (S_AXI_AClk)
    begin

        if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then

            if (S_AXI_AResetn = C_RESET_ACTIVE) or 
                -- Ensure that if we are also incrementing BVALID counter, the BVALID stays asserted.
               (bvalid_cnt = "001" and bvalid_cnt_dec = '1' and bvalid_cnt_inc = '0') then
                axi_bvalid_int <= '0';

            elsif (bvalid_cnt_non_zero = '1') or (bvalid_cnt_inc = '1') then
                axi_bvalid_int <= '1';
            else
                axi_bvalid_int <= '0';
            end if;

        end if;

    end process REG_BVALID;
    
    






    ---------------------------------------------------------------------------
    -- *** ECC Logic ***
    ---------------------------------------------------------------------------



    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_ECC
    -- Purpose:     Generate BRAM ECC write data and check ECC on read operations.
    --              Create signals to update ECC registers (lite_ecc_reg module interface).
    --
    ---------------------------------------------------------------------------

    GEN_ECC: if C_ECC = 1 generate
    
    constant null7      : std_logic_vector(0 to 6) := "0000000"; -- Specific to 32-bit data width (AXI-Lite)
    constant null8      : std_logic_vector(0 to 7) := "00000000";    -- Specific to 64-bit data width 
    
    -- constant C_USE_LUT6 : boolean := Family_To_LUT_Size (String_To_Family (C_FAMILY,false)) = 6;
    -- Remove usage of C_FAMILY.
    -- All architectures supporting AXI will support a LUT6. 
    -- Hard code this internal constant used in ECC algorithm.
    constant C_USE_LUT6 : boolean := TRUE;
    
    
    signal RdECC            : std_logic_vector(C_INT_ECC_WIDTH-1 downto 0) := (others => '0'); -- Temp 
    
    signal WrECC            : std_logic_vector(C_INT_ECC_WIDTH-1 downto 0) := (others => '0'); -- Specific to BRAM data width
    signal WrECC_i          : std_logic_vector(C_ECC_WIDTH-1 downto 0) := (others => '0');
    
    signal AXI_WSTRB_Q      : std_logic_vector((C_AXI_DATA_WIDTH/8 - 1) downto 0) := (others => '0');

    signal Syndrome         : std_logic_vector(0 to C_INT_ECC_WIDTH-1) := (others => '0'); -- Specific to BRAM data width
    signal Syndrome_4       : std_logic_vector (0 to 1) := (others => '0');         -- Specific to 32-bit ECC
    signal Syndrome_6       : std_logic_vector (0 to 5) := (others => '0');         -- Specific to 32-bit ECC
    signal Syndrome_7       : std_logic_vector (0 to 11) := (others => '0');        -- Specific to 64-bit ECC

    signal syndrome_reg_i       : std_logic_vector(0 to C_INT_ECC_WIDTH-1) := (others => '0');     -- Specific to BRAM data width
    signal syndrome_reg         : std_logic_vector(0 to C_INT_ECC_WIDTH-1) := (others => '0');     -- Specific to BRAM data width

    signal RdModifyWr_Read      : std_logic := '0';  -- Read cycle in read modify write sequence 
    signal RdModifyWr_Read_i    : std_logic := '0'; 
    signal RdModifyWr_Check     : std_logic := '0'; 
 
    signal bram_din_a_i         : std_logic_vector(0 to C_AXI_DATA_WIDTH+C_ECC_WIDTH-1) := (others => '0'); -- Set for port data width
    signal UnCorrectedRdData    : std_logic_vector(0 to C_AXI_DATA_WIDTH-1) := (others => '0');
 
    signal CE_Q             : std_logic := '0';
    signal Sl_CE_i          : std_logic := '0';
    signal Sl_UE_i          : std_logic := '0';
 
    subtype syndrome_bits is std_logic_vector(0 to C_INT_ECC_WIDTH-1);
    -- 0:6 for 32-bit ECC
    -- 0:7 for 64-bit ECC

    type correct_data_table_type is array (natural range 0 to C_AXI_DATA_WIDTH-1) of syndrome_bits;
 
    type bool_array is array (natural range 0 to 6) of boolean;
    constant inverted_bit : bool_array := (false,false,true,false,true,false,false);

        
    -- v1.03a
    
    constant CODE_WIDTH : integer := C_AXI_DATA_WIDTH + C_INT_ECC_WIDTH;
    constant ECC_WIDTH  : integer := C_INT_ECC_WIDTH;
    
    signal h_rows        : std_logic_vector (CODE_WIDTH * ECC_WIDTH - 1 downto 0);

  
    begin
     
        -- Generate signal to advance BRAM read address pipeline to
        -- capture address for ECC error conditions (in lite_ecc_reg module).
        BRAM_Addr_En <= RdModifyWr_Read;
         
         
        
        -- v1.03a

        RdModifyWr_Read <= '1' when (wr_data_ecc_sm_cs = RMW_RD_DATA) else '0';
        RdModifyWr_Modify <= '1' when (wr_data_ecc_sm_cs = RMW_MOD_DATA) else '0';
        RdModifyWr_Write <= '1' when (wr_data_ecc_sm_cs = RMW_WR_DATA) else '0';

        
        -----------------------------------------------------------------------


       -- Remember write data one cycle to be available after read has been completed in a
       -- read/modify write operation.
       -- Save WSTRBs here in this register
       
       REG_WSTRB : process (S_AXI_AClk) is
       begin
           if (S_AXI_AClk'event and S_AXI_AClk = '1') then
               if (S_AXI_AResetn = C_RESET_ACTIVE) then
                   AXI_WSTRB_Q <= (others => '0');

               elsif (wrdata_reg_ld = '1') then
                   AXI_WSTRB_Q <= AXI_WSTRB;    
               end if;
           end if;
       end process REG_WSTRB;



       -- v1.03a

       ------------------------------------------------------------------------
       -- Generate:     GEN_WRDATA_CMB
       -- Purpose:      Replace manual signal assignment for WrData_cmb with 
       --               generate funtion.
       --
       --               Ensure correct byte swapping occurs with 
       --               CorrectedRdData (0 to C_AXI_DATA_WIDTH-1) assignment
       --               to WrData_cmb (C_AXI_DATA_WIDTH-1 downto 0).
       --
       --               AXI_WSTRB_Q (C_AXI_DATA_WIDTH_BYTES-1 downto 0) matches
       --               to WrData_cmb (C_AXI_DATA_WIDTH-1 downto 0).
       --
       ------------------------------------------------------------------------

       GEN_WRDATA_CMB: for i in C_AXI_DATA_WIDTH_BYTES-1 downto 0 generate
       begin

           WrData_cmb ( (((i+1)*8)-1) downto i*8 ) <= bram_wrdata_int ((((i+1)*8)-1) downto i*8) when 
                                           (RdModifyWr_Modify = '1' and AXI_WSTRB_Q(i) = '1') 
                                        else CorrectedRdData ( (C_AXI_DATA_WIDTH - ((i+1)*8)) to 
                                                               (C_AXI_DATA_WIDTH - (i*8) - 1) );
       end generate GEN_WRDATA_CMB;


       REG_WRDATA : process (S_AXI_AClk) is
       begin
            -- Remove reset value to minimize resources & improve timing
            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                WrData <= WrData_cmb;   
            end if;
       end process REG_WRDATA;
       


       ------------------------------------------------------------------------

        -- New assignment of ECC bits to BRAM write data outside generate
        -- blocks.  Same signal assignment regardless of ECC type.
        
        BRAM_WrData ((C_AXI_DATA_WIDTH + C_ECC_WIDTH - 1) downto C_AXI_DATA_WIDTH)
                    <= WrECC_i xor FaultInjectECC;  



       ------------------------------------------------------------------------


           
        -- v1.03a

        ------------------------------------------------------------------------
        -- Generate:     GEN_HSIAO_ECC
        -- Purpose:      Determine type of ECC encoding.  Hsiao or Hamming.  
        --               Add parameter/generate level.
        --               Derived from MIG v3.7 Hsiao HDL.
        ------------------------------------------------------------------------
        
        GEN_HSIAO_ECC: if C_ECC_TYPE = 1 generate

        constant ECC_WIDTH  : integer := C_INT_ECC_WIDTH;

        type type_int0 is array (C_AXI_DATA_WIDTH - 1 downto 0) of std_logic_vector (ECC_WIDTH - 1 downto 0);

        signal syndrome_ns  : std_logic_vector(ECC_WIDTH - 1 downto 0);
        signal syndrome_r   : std_logic_vector(ECC_WIDTH - 1 downto 0);

        signal ecc_rddata_r : std_logic_vector(C_AXI_DATA_WIDTH - 1 downto 0);
        signal h_matrix     : type_int0;

        signal flip_bits    : std_logic_vector(C_AXI_DATA_WIDTH - 1 downto 0);

        begin

            ---------------------- Hsiao ECC Write Logic ----------------------

            -- Instantiate ecc_gen_hsiao module, generated from MIG

            ECC_GEN_HSIAO: entity work.ecc_gen
               generic map (
                  code_width  => CODE_WIDTH,
                  ecc_width   => ECC_WIDTH,
                  data_width  => C_AXI_DATA_WIDTH
               )
               port map (
                  -- Output
                  h_rows  => h_rows (CODE_WIDTH * ECC_WIDTH - 1 downto 0)
               );
        

            -- Merge muxed rd/write data to gen               
            HSIAO_ECC: process (h_rows, WrData)
            constant DQ_WIDTH : integer := CODE_WIDTH;
            
            variable ecc_wrdata_tmp : std_logic_vector(DQ_WIDTH-1 downto C_AXI_DATA_WIDTH);
            
            begin
                                
                -- Loop to generate all ECC bits
                for k in 0 to  ECC_WIDTH - 1 loop                        
                    ecc_wrdata_tmp (CODE_WIDTH - k - 1) := REDUCTION_XOR ( (WrData (C_AXI_DATA_WIDTH - 1 downto 0) 
                                                                            and h_rows (k * CODE_WIDTH + C_AXI_DATA_WIDTH - 1 downto k * CODE_WIDTH)));
                end loop;

                WrECC (C_INT_ECC_WIDTH-1 downto 0) <= ecc_wrdata_tmp (DQ_WIDTH-1 downto C_AXI_DATA_WIDTH);
                 
            end process HSIAO_ECC;




            -----------------------------------------------------------------------
            -- Generate:     GEN_ECC_32
            -- Purpose:      For 32-bit ECC implementations, assign unused
            --               MSB of ECC output to BRAM with '0'.
            -----------------------------------------------------------------------
            GEN_ECC_32: if C_AXI_DATA_WIDTH = 32 generate
            begin
                -- Account for 32-bit and MSB '0' of ECC bits
                WrECC_i <= '0' & WrECC;
            end generate GEN_ECC_32;


            -----------------------------------------------------------------------
            -- Generate:     GEN_ECC_N
            -- Purpose:      For all non 32-bit ECC implementations, assign ECC
            --               bits for BRAM output.
            -----------------------------------------------------------------------
            GEN_ECC_N: if C_AXI_DATA_WIDTH /= 32 generate
            begin
                WrECC_i <= WrECC;
            end generate GEN_ECC_N;



            ---------------------- Hsiao ECC Read Logic -----------------------

            GEN_RD_ECC: for m in 0 to ECC_WIDTH - 1 generate
            begin
                syndrome_ns (m) <= REDUCTION_XOR ( BRAM_RdData (CODE_WIDTH-1 downto 0)
                                                   and h_rows ((m*CODE_WIDTH)+CODE_WIDTH-1 downto (m*CODE_WIDTH)));
            end generate GEN_RD_ECC;

            -- Insert register stage for syndrome 
            REG_SYNDROME: process (S_AXI_AClk)
            begin        
                if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then            
                    syndrome_r <= syndrome_ns;                    
                end if;
            end process REG_SYNDROME;

            ecc_rddata_r <= UnCorrectedRdData;

            -- Reconstruct H-matrix
            H_COL: for n in 0 to C_AXI_DATA_WIDTH - 1 generate
            begin
                H_BIT: for p in 0 to ECC_WIDTH - 1 generate
                begin
                    h_matrix (n)(p) <= h_rows (p * CODE_WIDTH + n);
                end generate H_BIT;
            end generate H_COL;


            GEN_FLIP_BIT: for r in 0 to C_AXI_DATA_WIDTH - 1 generate
            begin
               flip_bits (r) <= BOOLEAN_TO_STD_LOGIC (h_matrix (r) = syndrome_r);
            end generate GEN_FLIP_BIT;


            CorrectedRdData (0 to C_AXI_DATA_WIDTH-1) <= ecc_rddata_r (C_AXI_DATA_WIDTH-1 downto 0) xor
                                                             flip_bits (C_AXI_DATA_WIDTH-1 downto 0);

            Sl_CE_i <= not (REDUCTION_NOR (syndrome_r (ECC_WIDTH-1 downto 0))) and (REDUCTION_XOR (syndrome_r (ECC_WIDTH-1 downto 0)));
            Sl_UE_i <= not (REDUCTION_NOR (syndrome_r (ECC_WIDTH-1 downto 0))) and not (REDUCTION_XOR (syndrome_r (ECC_WIDTH-1 downto 0)));


        end generate GEN_HSIAO_ECC;
 
        
        
        
        



        ------------------------------------------------------------------------
        -- Generate:     GEN_HAMMING_ECC
        -- Purpose:      Determine type of ECC encoding.  Hsiao or Hamming.  
        --               Add parameter/generate level.
        ------------------------------------------------------------------------
        GEN_HAMMING_ECC: if C_ECC_TYPE = 0 generate
        begin
        
       
       
            -----------------------------------------------------------------
            -- Generate:  GEN_ECC_32
            -- Purpose:   Assign ECC out data vector (N:0) unique for 32-bit BRAM.
            --            Add extra '0' at MSB of ECC vector for data2mem alignment
            --            w/ 32-bit BRAM data widths.
            --            ECC bits are in upper order bits.
            -----------------------------------------------------------------

            GEN_ECC_32: if C_AXI_DATA_WIDTH = 32 generate

            constant correct_data_table_32 : correct_data_table_type := (
              0 => "1100001",  1 => "1010001",  2 => "0110001",  3 => "1110001",
              4 => "1001001",  5 => "0101001",  6 => "1101001",  7 => "0011001",
              8 => "1011001",  9 => "0111001",  10 => "1111001",  11 => "1000101",
              12 => "0100101",  13 => "1100101",  14 => "0010101",  15 => "1010101",
              16 => "0110101",  17 => "1110101",  18 => "0001101",  19 => "1001101",
              20 => "0101101",  21 => "1101101",  22 => "0011101",  23 => "1011101",
              24 => "0111101",  25 => "1111101",  26 => "1000011",  27 => "0100011",
              28 => "1100011",  29 => "0010011",  30 => "1010011",  31 => "0110011"
              );

            signal syndrome_4_reg       : std_logic_vector (0 to 1) := (others => '0');            -- Specific for 32-bit ECC
            signal syndrome_6_reg       : std_logic_vector (0 to 5)  := (others => '0');            -- Specific for 32-bit ECC

            begin


                --------------------- Hamming 32-bit ECC Write Logic ------------------



                -------------------------------------------------------------------------
                -- Instance:        CHK_HANDLER_WR_32
                -- Description:     Generate ECC bits for writing into BRAM.
                --                  WrData (N:0)
                -------------------------------------------------------------------------



                CHK_HANDLER_WR_32: entity work.checkbit_handler
                generic map (
                    C_ENCODE         => true,                -- [boolean]
                    C_USE_LUT6       => C_USE_LUT6)          -- [boolean]
                port map (
                    DataIn           => WrData,              -- [in  std_logic_vector(0 to 31)]
                    CheckIn          => null7,               -- [in  std_logic_vector(0 to 6)]
                    CheckOut         => WrECC,               -- [out std_logic_vector(0 to 6)]
                    Syndrome         => open,                -- [out std_logic_vector(0 to 6)]
                    Syndrome_4       => open,                -- [out std_logic_vector(0 to 1)]
                    Syndrome_6       => open,                -- [out std_logic_vector(0 to 5)]
                    Syndrome_Chk     => null7,               -- [in  std_logic_vector(0 to 6)]
                    Enable_ECC       => '1',                 -- [in  std_logic]
                    UE_Q             => '0',                 -- [in  std_logic]
                    CE_Q             => '0',                 -- [in  std_logic]
                    UE               => open,                -- [out std_logic]
                    CE               => open );              -- [out std_logic]
               

                -- v1.03a            
                -- Account for 32-bit and MSB '0' of ECC bits
                WrECC_i <= '0' & WrECC;




                --------------------- Hamming 32-bit ECC Read Logic -------------------



                --------------------------------------------------------------------------
                -- Instance:        CHK_HANDLER_RD_32
                -- Description:     Generate ECC bits for checking data read from BRAM.
                --                  All vectors oriented (0:N)
                --------------------------------------------------------------------------

                CHK_HANDLER_RD_32: entity work.checkbit_handler
                generic map (
                        C_ENCODE   => false,                 -- [boolean]
                        C_USE_LUT6 => C_USE_LUT6)            -- [boolean]
                port map (

                        -- DataIn (8:39)
                        -- CheckIn (1:7)
                        DataIn          =>  bram_din_a_i(C_INT_ECC_WIDTH+1 to C_INT_ECC_WIDTH+C_AXI_DATA_WIDTH),    -- [in  std_logic_vector(0 to 31)]
                        CheckIn         =>  bram_din_a_i(1 to C_INT_ECC_WIDTH),                                     -- [in  std_logic_vector(0 to 6)]

                        CheckOut        =>  open,                                                                   -- [out std_logic_vector(0 to 6)]
                        Syndrome        =>  Syndrome,                                                               -- [out std_logic_vector(0 to 6)]
                        Syndrome_4      =>  Syndrome_4,                                                             -- [out std_logic_vector(0 to 1)]
                        Syndrome_6      =>  Syndrome_6,                                                             -- [out std_logic_vector(0 to 5)]
                        Syndrome_Chk    =>  syndrome_reg_i,                                                         -- [in  std_logic_vector(0 to 6)]
                        Enable_ECC      =>  Enable_ECC,                                                             -- [in  std_logic]
                        UE_Q            =>  UE_Q,                                                                   -- [in  std_logic]
                        CE_Q            =>  CE_Q,                                                                   -- [in  std_logic]
                        UE              =>  Sl_UE_i,                                                                -- [out std_logic]
                        CE              =>  Sl_CE_i );                                                              -- [out std_logic]


                ---------------------------------------------------------------------------

                -- Insert register stage for syndrome 
                REG_SYNDROME: process (S_AXI_AClk)
                begin        
                    if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then            
                        syndrome_reg <= Syndrome;                    
                        syndrome_4_reg <= Syndrome_4;
                        syndrome_6_reg <= Syndrome_6;                  
                    end if;

                end process REG_SYNDROME;


               ---------------------------------------------------------------------------

                -- Do last XOR on select syndrome bits outside of checkbit_handler (to match rd_chnl 
                -- w/ balanced pipeline stage) before correct_one_bit module.
                syndrome_reg_i (0 to 3) <= syndrome_reg (0 to 3);

                PARITY_CHK4: entity work.parity
                generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 2)
                port map (
                  InA   =>  syndrome_4_reg (0 to 1),                        -- [in  std_logic_vector(0 to C_SIZE - 1)]
                  Res   =>  syndrome_reg_i (4) );                           -- [out std_logic]

                syndrome_reg_i (5) <= syndrome_reg (5);

                PARITY_CHK6: entity work.parity
                generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
                port map (
                  InA   =>  syndrome_6_reg (0 to 5),                        -- [in  std_logic_vector(0 to C_SIZE - 1)]
                  Res   =>  syndrome_reg_i (6) );                           -- [out std_logic]



               ---------------------------------------------------------------------------
               -- Generate: GEN_CORR_32
               -- Purpose:  Generate corrected read data based on syndrome value.
               --           All vectors oriented (0:N)
               ---------------------------------------------------------------------------
               GEN_CORR_32: for i in 0 to C_AXI_DATA_WIDTH-1 generate
               begin

                    ---------------------------------------------------------------------------
                    -- Instance:        CORR_ONE_BIT_32
                    -- Description:     Generate ECC bits for checking data read from BRAM.
                    ---------------------------------------------------------------------------
                    CORR_ONE_BIT_32: entity work.correct_one_bit
                    generic map (
                        C_USE_LUT6    => C_USE_LUT6,
                        Correct_Value => correct_data_table_32 (i))
                    port map (
                        DIn           => UnCorrectedRdData (i),
                        Syndrome      => syndrome_reg_i,
                        DCorr         => CorrectedRdData (i));

                end generate GEN_CORR_32;
        
        


            end generate GEN_ECC_32;
        
        
        

            -----------------------------------------------------------------
            -- Generate:  GEN_ECC_64
            -- Purpose:   Assign ECC out data vector (N:0) unique for 64-bit BRAM.
            --            No extra '0' at MSB of ECC vector for data2mem alignment
            --            w/ 64-bit BRAM data widths.
            --            ECC bits are in upper order bits.
            -----------------------------------------------------------------
        
            GEN_ECC_64: if C_AXI_DATA_WIDTH = 64 generate

             constant correct_data_table_64 : correct_data_table_type := (
               0 => "11000001",  1 => "10100001",  2 => "01100001",  3 => "11100001",
               4 => "10010001",  5 => "01010001",  6 => "11010001",  7 => "00110001",
               8 => "10110001",  9 => "01110001",  10 => "11110001",  11 => "10001001",
               12 => "01001001",  13 => "11001001",  14 => "00101001",  15 => "10101001",
               16 => "01101001",  17 => "11101001",  18 => "00011001",  19 => "10011001",
               20 => "01011001",  21 => "11011001",  22 => "00111001",  23 => "10111001",
               24 => "01111001",  25 => "11111001",  26 => "10000101",  27 => "01000101",
               28 => "11000101",  29 => "00100101",  30 => "10100101",  31 => "01100101",
               32 => "11100101",  33 => "00010101",  34 => "10010101",  35 => "01010101",
               36 => "11010101",  37 => "00110101",  38 => "10110101",  39 => "01110101",
               40 => "11110101",  41 => "00001101",  42 => "10001101",  43 => "01001101",
               44 => "11001101",  45 => "00101101",  46 => "10101101",  47 => "01101101",      
               48 => "11101101",  49 => "00011101",  50 => "10011101",  51 => "01011101",
               52 => "11011101",  53 => "00111101",  54 => "10111101",  55 => "01111101",
               56 => "11111101",  57 => "10000011",  58 => "01000011",  59 => "11000011",
               60 => "00100011",  61 => "10100011",  62 => "01100011",  63 => "11100011"
               );

            signal syndrome_7_reg       : std_logic_vector (0 to 11) := (others => '0');
            signal syndrome7_a          : std_logic := '0';
            signal syndrome7_b          : std_logic := '0';

            begin


                --------------------- Hamming 64-bit ECC Write Logic ------------------

          

                ---------------------------------------------------------------------------
                -- Instance:        CHK_HANDLER_WR_64
                -- Description:     Generate ECC bits for writing into BRAM when configured
                --                  as 64-bit wide BRAM.
                --                  WrData (N:0)
                --                   Enable C_REG on encode path.
                ---------------------------------------------------------------------------

                CHK_HANDLER_WR_64: entity work.checkbit_handler_64
                generic map (
                       C_ENCODE         =>  true,           -- [boolean]
                       C_REG            =>  true,           -- [boolean]
                       C_USE_LUT6       =>  C_USE_LUT6)     -- [boolean]
                port map (
                       Clk              =>  S_AXI_AClk,     -- [in std_logic]
                       DataIn           =>  WrData_cmb,     -- [in  std_logic_vector(0 to 63)]
                       CheckIn          =>  null8,          -- [in  std_logic_vector(0 to 7)]
                       CheckOut         =>  WrECC,          -- [out std_logic_vector(0 to 7)]
                       Syndrome         =>  open,           -- [out std_logic_vector(0 to 7)]
                       Syndrome_7       =>  open,           -- [out std_logic_vector(0 to 11)]
                       Syndrome_Chk     =>  null8,          -- [in  std_logic_vector(0 to 7)]
                       Enable_ECC       =>  '1',            -- [in  std_logic]
                       UE_Q             =>  '0',            -- [in  std_logic]
                       CE_Q             =>  '0',            -- [in  std_logic]
                       UE               =>  open,           -- [out std_logic]
                       CE               =>  open );         -- [out std_logic]


                -- Note: (7:0) Old bit lane assignment
                -- BRAM_WrData ((C_ECC_WIDTH - 1) downto 0) 

                -- v1.02a
                -- WrECC is assigned to BRAM_WrData (71:64)
                
                -- v1.03a
                -- BRAM_WrData (71:64) assignment done outside of this
                -- ECC type generate block.

                WrECC_i <= WrECC;
                

            
                --------------------- Hamming 64-bit ECC Read Logic -------------------
            


                ---------------------------------------------------------------------------
                -- Instance:        CHK_HANDLER_RD_64
                -- Description:     Generate ECC bits for checking data read from BRAM.
                --                  All vectors oriented (0:N)
                ---------------------------------------------------------------------------

                CHK_HANDLER_RD_64: entity work.checkbit_handler_64
                     generic map (
                       C_ENCODE         =>  false,                 -- [boolean]
                       C_REG            =>  false,                 -- [boolean]
                       C_USE_LUT6       =>  C_USE_LUT6)            -- [boolean]
                     port map (
                       Clk              =>  S_AXI_AClk,                                                                  -- [in  std_logic]
                       -- DataIn (8:71)
                       -- CheckIn (0:7)
                       DataIn           =>  bram_din_a_i (C_INT_ECC_WIDTH to C_INT_ECC_WIDTH+C_AXI_DATA_WIDTH-1),        -- [in  std_logic_vector(0 to 63)]
                       CheckIn          =>  bram_din_a_i (0 to C_INT_ECC_WIDTH-1),                                       -- [in  std_logic_vector(0 to 7)]

                       CheckOut         =>  open,                                                                        -- [out std_logic_vector(0 to 7)]
                       Syndrome         =>  Syndrome,                                                                    -- [out std_logic_vector(0 to 7)]
                       Syndrome_7       =>  Syndrome_7,                                                                  -- [out std_logic_vector(0 to 11)]
                       Syndrome_Chk     =>  syndrome_reg_i,                                                              -- [in  std_logic_vector(0 to 7)]
                       Enable_ECC       =>  Enable_ECC,                                                                  -- [in  std_logic]
                       UE_Q             =>  UE_Q,                                                                        -- [in  std_logic]
                       CE_Q             =>  CE_Q,                                                                        -- [in  std_logic]
                       UE               =>  Sl_UE_i,                                                                     -- [out std_logic]
                       CE               =>  Sl_CE_i );                                                                   -- [out std_logic]



                ---------------------------------------------------------------------------

                -- Insert register stage for syndrome 
                REG_SYNDROME: process (S_AXI_AClk)
                begin        
                    if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then            
                        syndrome_reg <= Syndrome;                    
                        syndrome_7_reg <= Syndrome_7;                  
                    end if;

                end process REG_SYNDROME;


                ---------------------------------------------------------------------------

                -- Move final XOR to registered side of syndrome bits.
                -- Do last XOR on select syndrome bits after pipeline stage 
                -- before correct_one_bit_64 module.

                syndrome_reg_i (0 to 6) <= syndrome_reg (0 to 6);

                PARITY_CHK7_A: entity work.parity
                generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
                port map (
                  InA     =>  syndrome_7_reg (0 to 5),                      -- [in  std_logic_vector(0 to C_SIZE - 1)]
                  Res     =>  syndrome7_a );                                -- [out std_logic]

                PARITY_CHK7_B: entity work.parity
                generic map (C_USE_LUT6 => C_USE_LUT6, C_SIZE => 6)
                port map (
                  InA     =>  syndrome_7_reg (6 to 11),                     -- [in  std_logic_vector(0 to C_SIZE - 1)]
                  Res     =>  syndrome7_b );                                -- [out std_logic]


                syndrome_reg_i (7) <= syndrome7_a xor syndrome7_b;    



               ---------------------------------------------------------------------------
               -- Generate: GEN_CORRECT_DATA
               -- Purpose:  Generate corrected read data based on syndrome value.
               --           All vectors oriented (0:N)
               ---------------------------------------------------------------------------
               GEN_CORR_64: for i in 0 to C_AXI_DATA_WIDTH-1 generate
               begin

                   ---------------------------------------------------------------------------
                   -- Instance:        CORR_ONE_BIT_64
                   -- Description:     Generate ECC bits for checking data read from BRAM.
                   ---------------------------------------------------------------------------
                   CORR_ONE_BIT_64: entity work.correct_one_bit_64
                   generic map (
                       C_USE_LUT6    => C_USE_LUT6,
                       Correct_Value => correct_data_table_64 (i))
                   port map (
                       DIn           => UnCorrectedRdData (i),
                       Syndrome      => syndrome_reg_i,
                       DCorr         => CorrectedRdData (i));

               end generate GEN_CORR_64;


            end generate GEN_ECC_64;


        end generate GEN_HAMMING_ECC;


        -- Remember correctable/uncorrectable error from BRAM read
        CORR_REG: process(S_AXI_AClk) is
        begin
            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                if RdModifyWr_Modify = '1' then     -- Capture error signals 
                    CE_Q <= Sl_CE_i;
                    UE_Q <= Sl_UE_i;

                else              
                    CE_Q <= '0';
                    UE_Q <= '0';
                end if;          
            end if;
        end process CORR_REG;

       
        -- ECC register block gets registered UE or CE conditions to update
        -- ECC registers/interrupt/flag outputs.
        Sl_CE <= CE_Q;
        Sl_UE <= UE_Q;

        CE_Failing_We <= CE_Q;

        FaultInjectClr <= '1' when (bvalid_cnt_inc_d1 = '1') else '0';


        -----------------------------------------------------------------------

        -- Add register delay on BVALID counter increment
        -- Used to clear fault inject register.
        
        REG_BVALID_CNT: process (S_AXI_AClk)
        begin
        
            if (S_AXI_AClk'event and S_AXI_AClk = '1') then
                if (S_AXI_AResetn = C_RESET_ACTIVE) then
                    bvalid_cnt_inc_d1 <= '0';
                else
                    bvalid_cnt_inc_d1 <= bvalid_cnt_inc;
                end if;
            end if;
        
        end process REG_BVALID_CNT;


                           
        -----------------------------------------------------------------------

        -- Map BRAM_RdData (N:0) to bram_din_a_i (0:N)
        -- Including read back ECC bits.
        bram_din_a_i (0 to C_AXI_DATA_WIDTH+C_ECC_WIDTH-1) <= 
                    BRAM_RdData (C_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0);
    

        -----------------------------------------------------------------------



        -----------------------------------------------------------------------
        -- Generate:     GEN_ECC_32
        -- Purpose:      For 32-bit ECC implementations, account for 
        --               extra bit in read data mapping on registered value.
        -----------------------------------------------------------------------
        GEN_ECC_32: if C_AXI_DATA_WIDTH = 32 generate
        begin

            -- Insert register stage for read data to correct
            REG_CHK_DATA: process (S_AXI_AClk)
            begin        
                if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then            
                    UnCorrectedRdData <= bram_din_a_i(C_INT_ECC_WIDTH+1 to C_INT_ECC_WIDTH+C_AXI_DATA_WIDTH);
                end if;
            end process REG_CHK_DATA;

        end generate GEN_ECC_32;


        -----------------------------------------------------------------------
        -- Generate:     GEN_ECC_N
        -- Purpose:      For all non 32-bit ECC implementations, assign ECC
        --               bits for BRAM output.
        -----------------------------------------------------------------------
        GEN_ECC_N: if C_AXI_DATA_WIDTH /= 32 generate
        begin

            -- Insert register stage for read data to correct
            REG_CHK_DATA: process (S_AXI_AClk)
            begin        
                if (S_AXI_AClk'event and S_AXI_AClk = '1' ) then            
                    UnCorrectedRdData <= bram_din_a_i(C_INT_ECC_WIDTH to C_INT_ECC_WIDTH+C_AXI_DATA_WIDTH-1);
                end if;
            end process REG_CHK_DATA;

        end generate GEN_ECC_N;


                        
    end generate GEN_ECC;


    ---------------------------------------------------------------------------



    ---------------------------------------------------------------------------
    -- Generate:    GEN_NO_ECC
    -- Purpose:     Drive default output signals when ECC is diabled.
    ---------------------------------------------------------------------------

    GEN_NO_ECC: if C_ECC = 0 generate
    begin
    
        BRAM_Addr_En <= '0';
        FaultInjectClr <= '0'; 
        CE_Failing_We <= '0'; 
        Sl_CE <= '0';
        Sl_UE <= '0'; 

    end generate GEN_NO_ECC;







    ---------------------------------------------------------------------------
    -- *** BRAM Interface Signals ***
    ---------------------------------------------------------------------------


    ---------------------------------------------------------------------------
    -- Generate:    GEN_BRAM_WE
    -- Purpose:     BRAM WE generate process
    --              One WE per 8-bits of BRAM data.
    ---------------------------------------------------------------------------
    
    GEN_BRAM_WE: for i in C_AXI_DATA_WIDTH/8 + (C_ECC*(1+(C_AXI_DATA_WIDTH/128))) - 1 downto 0 generate
    begin
        BRAM_WE (i) <= bram_we_int (i);
    end generate GEN_BRAM_WE;
            

    ---------------------------------------------------------------------------

    BRAM_En <= bram_en_int;   




    ---------------------------------------------------------------------------
    -- BRAM Address Generate
    ---------------------------------------------------------------------------


    ---------------------------------------------------------------------------
    -- Generate:    GEN_L_BRAM_ADDR
    -- Purpose:     Generate zeros on lower order address bits adjustable
    --              based on BRAM data width.
    ---------------------------------------------------------------------------

    GEN_L_BRAM_ADDR: for i in C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0 generate
    begin    
        BRAM_Addr (i) <= '0';        
    end generate GEN_L_BRAM_ADDR;
 
  
    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_BRAM_ADDR
    -- Purpose:     Assign BRAM address output from address counter.
    --
    ---------------------------------------------------------------------------
 
    GEN_BRAM_ADDR: for i in C_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR generate
    begin    
 
        BRAM_Addr (i) <= bram_addr_int (i);        
    end generate GEN_BRAM_ADDR;
    

    ---------------------------------------------------------------------------
    -- Generate:    GEN_BRAM_WRDATA
    -- Purpose:     Generate BRAM Write Data.
    ---------------------------------------------------------------------------

    GEN_BRAM_WRDATA: for i in C_AXI_DATA_WIDTH-1 downto 0 generate
    begin        
            
            
        -- Check if ECC is enabled
        -- If so, XOR the fault injection vector with the data
        -- (post-pipeline) to avoid any timing issues on the data vector
        -- from AXI.
        
        
        -----------------------------------------------------------------------
        -- Generate:    GEN_NO_ECC
        -- Purpose:     Generate output write data when ECC is disabled.
        -----------------------------------------------------------------------
        GEN_NO_ECC : if C_ECC = 0 generate
        begin
            BRAM_WrData (i) <= bram_wrdata_int (i);  
        end generate GEN_NO_ECC;
        
        -----------------------------------------------------------------------
        -- Generate:    GEN_NO_ECC
        -- Purpose:     Generate output write data when ECC is enable 
        --              (use fault vector)
        --              (N:0)
        --              for 32-bit (31:0) WrData while (ECC = [39:32])
        -----------------------------------------------------------------------
        GEN_W_ECC : if C_ECC = 1 generate
        begin
            BRAM_WrData (i) <= WrData (i) xor FaultInjectData (i);
        end generate GEN_W_ECC;

                
        
    end generate GEN_BRAM_WRDATA;


    ---------------------------------------------------------------------------





end architecture implementation;










-------------------------------------------------------------------------------
-- full_axi.vhd
-------------------------------------------------------------------------------
--
--  
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
--
--
-------------------------------------------------------------------------------
-- Filename:        full_axi.vhd
--
-- Description:     This file is the top level module for the AXI BRAM
--                  controller when configured in a full AXI4 mode.
--                  The rd_chnl and wr_chnl modules are instantiated.
--                  The ECC AXI-Lite register module is instantiated, if enabled.
--                  When single port BRAM mode is selected, the arbitration logic
--                  is instantiated (and connected to each wr_chnl & rd_chnl).
--
-- VHDL-Standard:   VHDL'93
--
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v1_03_a)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen_hsiao.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen_hsiao.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- correct_one_bit.vhd
--
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/2/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
--  Remove library version # dependency.  Replace with work library.
-- ^^^^^^
-- JLJ      2/15/2011      v1.03a
-- ~~~~~~
--  Initial integration of Hsiao ECC algorithm.
--  Add C_ECC_TYPE top level parameter and mappings on instantiated modules.
-- ^^^^^^
-- JLJ      2/18/2011      v1.03a
-- ~~~~~~
--  Update WE & BRAM data sizes based on 128-bit ECC configuration.
--  Plus XST clean-up.
-- ^^^^^^
-- JLJ      3/31/2011      v1.03a
-- ~~~~~~
--  Add coverage tags.
-- ^^^^^^
-- JLJ      4/11/2011      v1.03a
-- ~~~~~~
--  Add signal, AW2Arb_BVALID_Cnt, between wr_chnl and sng_port_arb modules.
-- ^^^^^^
-- JLJ      4/20/2011      v1.03a
-- ~~~~~~
--  Add default values for Arb2AW_Active & Arb2AR_Active when dual port mode.
-- ^^^^^^
-- JLJ      5/6/2011      v1.03a
-- ~~~~~~
--  Remove usage of C_FAMILY.  
-- ^^^^^^
--
--
--
-------------------------------------------------------------------------------

-- Library declarations

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.axi_bram_ctrl_funcs.all;
use work.lite_ecc_reg;
use work.sng_port_arb;
use work.wr_chnl;
use work.rd_chnl;


 ------------------------------------------------------------------------------


entity full_axi is
generic (


    -- AXI Parameters
    
    C_S_AXI_ADDR_WIDTH  : integer := 32;
        -- Width of AXI address bus (in bits)

    C_S_AXI_DATA_WIDTH  : integer := 32;
        -- Width of AXI data bus (in bits)
            
    C_S_AXI_ID_WIDTH : INTEGER := 4;
        --  AXI ID vector width
        
    C_S_AXI_PROTOCOL : string := "AXI4";
        -- Set to AXI4LITE to optimize out burst transaction support

    C_S_AXI_SUPPORTS_NARROW_BURST : INTEGER := 1;
        -- Support for narrow burst operations
        
    C_SINGLE_PORT_BRAM : INTEGER := 0;
        -- Enable single port usage of BRAM

    -- C_FAMILY : string := "virtex6";
        -- Specify the target architecture type



    -- AXI-Lite Register Parameters
    
    C_S_AXI_CTRL_ADDR_WIDTH : integer := 32;
        -- Width of AXI-Lite address bus (in bits)

    C_S_AXI_CTRL_DATA_WIDTH  : integer := 32;
        -- Width of AXI-Lite data bus (in bits)
        
        
   
    -- ECC Parameters
    
    C_ECC : integer := 0;
        -- Enables or disables ECC functionality
        
    C_ECC_WIDTH : integer := 8;
        -- Width of ECC data vector
        
    C_ECC_TYPE : integer := 0;          -- v1.03a 
        -- ECC algorithm format, 0 = Hamming code, 1 = Hsiao code

    C_FAULT_INJECT : integer := 0;
        -- Enable fault injection registers
        
    C_ECC_ONOFF_RESET_VALUE : integer := 1;
        -- By default, ECC checking is on (can disable ECC @ reset by setting this to 0)


    -- Hard coded parameters at top level.
    -- Note: Kept in design for future enhancement.
    
    C_ENABLE_AXI_CTRL_REG_IF : integer := 0;
        -- By default the ECC AXI-Lite register interface is enabled    
    
    C_CE_FAILING_REGISTERS : integer := 0;
        -- Enable CE (correctable error) failing registers
        
    C_UE_FAILING_REGISTERS : integer := 0;
        -- Enable UE (uncorrectable error) failing registers
        
    C_ECC_STATUS_REGISTERS : integer := 0;
        -- Enable ECC status registers

    C_ECC_ONOFF_REGISTER : integer := 0;
        -- Enable ECC on/off control register

    C_CE_COUNTER_WIDTH : integer := 0
        -- Selects CE counter width/threshold to assert ECC_Interrupt
        

       );
  port (


    -- AXI Interface Signals
    
    -- AXI Clock and Reset
    S_AXI_ACLK              : in    std_logic;
    S_AXI_ARESETN           : in    std_logic;      

    ECC_Interrupt           : out   std_logic := '0';
    ECC_UE                  : out   std_logic := '0';

    -- AXI Write Address Channel Signals (AW)
    S_AXI_AWID              : in    std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_AWADDR            : in    std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_AWLEN             : in    std_logic_vector(7 downto 0);
    S_AXI_AWSIZE            : in    std_logic_vector(2 downto 0);
    S_AXI_AWBURST           : in    std_logic_vector(1 downto 0);
    S_AXI_AWLOCK            : in    std_logic;                              
    S_AXI_AWCACHE           : in    std_logic_vector(3 downto 0);
    S_AXI_AWPROT            : in    std_logic_vector(2 downto 0);
    S_AXI_AWVALID           : in    std_logic;
    S_AXI_AWREADY           : out   std_logic;


    -- AXI Write Data Channel Signals (W)
    S_AXI_WDATA             : in    std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_WSTRB             : in    std_logic_vector(C_S_AXI_DATA_WIDTH/8-1 downto 0);
    S_AXI_WLAST             : in    std_logic;

    S_AXI_WVALID            : in    std_logic;
    S_AXI_WREADY            : out   std_logic;


    -- AXI Write Data Response Channel Signals (B)
    S_AXI_BID               : out   std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_BRESP             : out   std_logic_vector(1 downto 0);

    S_AXI_BVALID            : out   std_logic;
    S_AXI_BREADY            : in    std_logic;



    -- AXI Read Address Channel Signals (AR)
    S_AXI_ARID              : in    std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_ARADDR            : in    std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_ARLEN             : in    std_logic_vector(7 downto 0);
    S_AXI_ARSIZE            : in    std_logic_vector(2 downto 0);
    S_AXI_ARBURST           : in    std_logic_vector(1 downto 0);
    S_AXI_ARLOCK            : in    std_logic;                              
    S_AXI_ARCACHE           : in    std_logic_vector(3 downto 0);
    S_AXI_ARPROT            : in    std_logic_vector(2 downto 0);

    S_AXI_ARVALID           : in    std_logic;
    S_AXI_ARREADY           : out   std_logic;
    

    -- AXI Read Data Channel Signals (R)
    S_AXI_RID               : out   std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_RDATA             : out   std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_RRESP             : out   std_logic_vector(1 downto 0);
    S_AXI_RLAST             : out   std_logic;

    S_AXI_RVALID            : out   std_logic;
    S_AXI_RREADY            : in    std_logic;
    
    
    
    
    -- AXI-Lite ECC Register Interface Signals    
    
    -- AXI-Lite Clock and Reset
    -- TBD
    -- S_AXI_CTRL_ACLK             : in    std_logic;
    -- S_AXI_CTRL_ARESETN          : in    std_logic;      
    
    -- AXI-Lite Write Address Channel Signals (AW)
    S_AXI_CTRL_AWVALID          : in    std_logic;
    S_AXI_CTRL_AWREADY          : out   std_logic;
    S_AXI_CTRL_AWADDR           : in    std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);

    
    -- AXI-Lite Write Data Channel Signals (W)
    S_AXI_CTRL_WDATA            : in    std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    S_AXI_CTRL_WVALID           : in    std_logic;
    S_AXI_CTRL_WREADY           : out   std_logic;
    

    -- AXI-Lite Write Data Response Channel Signals (B)
    S_AXI_CTRL_BRESP            : out   std_logic_vector(1 downto 0);
    S_AXI_CTRL_BVALID           : out   std_logic;
    S_AXI_CTRL_BREADY           : in    std_logic;
    

    -- AXI-Lite Read Address Channel Signals (AR)
    S_AXI_CTRL_ARADDR           : in    std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);
    S_AXI_CTRL_ARVALID          : in    std_logic;
    S_AXI_CTRL_ARREADY          : out   std_logic;


    -- AXI-Lite Read Data Channel Signals (R)
    S_AXI_CTRL_RDATA             : out   std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    S_AXI_CTRL_RRESP             : out   std_logic_vector(1 downto 0);
    S_AXI_CTRL_RVALID            : out   std_logic;
    S_AXI_CTRL_RREADY            : in    std_logic;

    
    
    -- BRAM Interface Signals (Port A)
    BRAM_En_A               : out   std_logic;
    BRAM_WE_A               : out   std_logic_vector (C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);
    BRAM_Addr_A             : out   std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0);
    BRAM_WrData_A           : out   std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*(8+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);   
    BRAM_RdData_A           : in    std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*(8+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);      
    
    -- BRAM Interface Signals (Port B)
    BRAM_En_B               : out   std_logic;
    BRAM_WE_B               : out   std_logic_vector (C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);
    BRAM_Addr_B             : out   std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0);
    BRAM_WrData_B           : out   std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*(8+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);   
    BRAM_RdData_B           : in    std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*(8+(C_S_AXI_DATA_WIDTH/128))-1 downto 0)    



    );



end entity full_axi;


-------------------------------------------------------------------------------

architecture implementation of full_axi is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";

-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------


constant C_INT_ECC_WIDTH : integer := Int_ECC_Size (C_S_AXI_DATA_WIDTH);

-- Modify C_BRAM_ADDR_SIZE to be adjusted for BRAM data width
-- When BRAM data width = 32 bits, BRAM_Addr (1:0) = "00"
-- When BRAM data width = 64 bits, BRAM_Addr (2:0) = "000"
-- When BRAM data width = 128 bits, BRAM_Addr (3:0) = "0000"
-- When BRAM data width = 256 bits, BRAM_Addr (4:0) = "00000"
constant C_BRAM_ADDR_ADJUST_FACTOR  : integer := log2 (C_S_AXI_DATA_WIDTH/8);


-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------


-- Internal AXI Signals
signal S_AXI_AWREADY_i  : std_logic := '0';
signal S_AXI_ARREADY_i  : std_logic := '0'; 


-- Internal BRAM Signals
signal BRAM_Addr_A_i    : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
signal BRAM_Addr_B_i    : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');

signal BRAM_En_A_i      : std_logic := '0';
signal BRAM_En_B_i      : std_logic := '0';

signal BRAM_WE_A_i      : std_logic_vector (C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0');

signal BRAM_RdData_i    : std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*(8+(C_S_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0');


-- Internal ECC Signals

signal Enable_ECC               : std_logic := '0';
signal FaultInjectClr           : std_logic := '0';      -- Clear for Fault Inject Registers      
signal CE_Failing_We            : std_logic := '0';      -- WE for CE Failing Registers        
signal Sl_CE                    : std_logic := '0';      -- Correctable Error Flag
signal Sl_UE                    : std_logic := '0';      -- Uncorrectable Error Flag


signal Wr_CE_Failing_We            : std_logic := '0';      -- WE for CE Failing Registers        
--signal UE_Failing_We             : std_logic := '0';      -- WE for CE Failing Registers
--signal CE_CounterReg_Inc         : std_logic := '0';      -- Increment CE Counter Register 
signal Wr_Sl_CE                    : std_logic := '0';      -- Correctable Error Flag
signal Wr_Sl_UE                    : std_logic := '0';      -- Uncorrectable Error Flag

signal Rd_CE_Failing_We            : std_logic := '0';      -- WE for CE Failing Registers        
signal Rd_Sl_CE                    : std_logic := '0';      -- Correctable Error Flag
signal Rd_Sl_UE                    : std_logic := '0';      -- Uncorrectable Error Flag


signal FaultInjectData          : std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
signal FaultInjectECC           : std_logic_vector (C_ECC_WIDTH-1 downto 0) := (others => '0');         -- Specific to BRAM data width
signal FaultInjectECC_i         : std_logic_vector (C_INT_ECC_WIDTH-1 downto 0) := (others => '0');     -- Specific to BRAM data width

signal Active_Wr                : std_logic := '0';
signal BRAM_Addr_En             : std_logic := '0';
signal Wr_BRAM_Addr_En          : std_logic := '0';
signal Rd_BRAM_Addr_En          : std_logic := '0';


-- Internal Arbitration Signals
signal Arb2AW_Active                :  std_logic := '0';
signal AW2Arb_Busy                  :  std_logic := '0';
signal AW2Arb_Active_Clr            :  std_logic := '0';
signal AW2Arb_BVALID_Cnt            :  std_logic_vector (2 downto 0) := (others => '0');

signal Arb2AR_Active                :  std_logic := '0';
signal AR2Arb_Active_Clr            :  std_logic := '0';

signal WrChnl_BRAM_Addr_Rst         :  std_logic := '0';
signal WrChnl_BRAM_Addr_Ld_En       :  std_logic := '0';
signal WrChnl_BRAM_Addr_Inc         :  std_logic := '0';
signal WrChnl_BRAM_Addr_Ld          :  std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) := (others => '0');

signal RdChnl_BRAM_Addr_Ld_En       :  std_logic := '0';
signal RdChnl_BRAM_Addr_Inc         :  std_logic := '0';
signal RdChnl_BRAM_Addr_Ld          :  std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) := (others => '0');

signal bram_addr_int                :  std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) := (others => '0');


-------------------------------------------------------------------------------
-- Architecture Body
-------------------------------------------------------------------------------


begin 



    ---------------------------------------------------------------------------
    -- *** BRAM Output Signals ***
    ---------------------------------------------------------------------------

    
    ---------------------------------------------------------------------------
    -- Generate:    ADDR_SNG_PORT
    -- Purpose:     OR the BRAM_Addr outputs from each wr_chnl & rd_chnl
    --              Only one write or read will be active at a time.
    --              Ensure that ecah channel address is driven to '0' when not in use.
    ---------------------------------------------------------------------------
    ADDR_SNG_PORT: if C_SINGLE_PORT_BRAM = 1 generate
    
    signal sng_bram_addr_rst    : std_logic := '0';
    signal sng_bram_addr_ld_en  : std_logic := '0';
    signal sng_bram_addr_ld     : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR) := (others => '0');
    signal sng_bram_addr_inc    : std_logic := '0';
    
    begin
--        BRAM_Addr_A <= BRAM_Addr_A_i or BRAM_Addr_B_i;
--        BRAM_Addr_A <= BRAM_Addr_A_i when (Arb2AW_Active = '1') else BRAM_Addr_B_i;
--        BRAM_Addr_A <= BRAM_Addr_A_i when (Active_Wr = '1') else BRAM_Addr_B_i;
        
        -- Insert mux on address counter control signals
        sng_bram_addr_rst <= WrChnl_BRAM_Addr_Rst;
        sng_bram_addr_ld_en <= WrChnl_BRAM_Addr_Ld_En or RdChnl_BRAM_Addr_Ld_En;
        sng_bram_addr_ld <= RdChnl_BRAM_Addr_Ld when (Arb2AR_Active = '1') else WrChnl_BRAM_Addr_Ld;
        sng_bram_addr_inc <= RdChnl_BRAM_Addr_Inc when (Arb2AR_Active = '1') else WrChnl_BRAM_Addr_Inc;
        

        I_ADDR_CNT: process (S_AXI_AClk)
        begin
        
            if (S_AXI_AClk'event and S_AXI_AClk = '1') then        
                if (sng_bram_addr_rst = '1') then
                    bram_addr_int <= (others => '0');
        
                elsif (sng_bram_addr_ld_en = '1') then
                    bram_addr_int <= sng_bram_addr_ld;
        
                elsif (sng_bram_addr_inc = '1') then
                    bram_addr_int (C_S_AXI_ADDR_WIDTH-1 downto 12) <= 
                            bram_addr_int (C_S_AXI_ADDR_WIDTH-1 downto 12);
                    bram_addr_int (11 downto C_BRAM_ADDR_ADJUST_FACTOR) <= 
                            std_logic_vector (unsigned (bram_addr_int (11 downto C_BRAM_ADDR_ADJUST_FACTOR)) + 1);        
                end if;        
            end if;        
            
        end process I_ADDR_CNT;
                
        
        BRAM_Addr_B <= (others => '0');
        BRAM_En_A <= BRAM_En_A_i or BRAM_En_B_i;
--        BRAM_En_A <= BRAM_En_A_i when (Arb2AW_Active = '1') else BRAM_En_B_i;
        BRAM_En_B <= '0';
        
        BRAM_RdData_i <= BRAM_RdData_A;     -- Assign read data port A
        
        BRAM_WE_A <= BRAM_WE_A_i when (Arb2AW_Active = '1') else (others => '0');
        
        -- v1.03a
        -- Early register on WrData and WSTRB in wr_chnl.  (Previous value was always cleared).
        

        ---------------------------------------------------------------------------
        -- Generate:    GEN_L_BRAM_ADDR
        -- Purpose:     Generate zeros on lower order address bits adjustable
        --              based on BRAM data width.
        ---------------------------------------------------------------------------
        GEN_L_BRAM_ADDR: for i in C_BRAM_ADDR_ADJUST_FACTOR-1 downto 0 generate
        begin    
            BRAM_Addr_A (i) <= '0';        
        end generate GEN_L_BRAM_ADDR;
 
        ---------------------------------------------------------------------------
        -- Generate:    GEN_BRAM_ADDR
        -- Purpose:     Assign BRAM address output from address counter.
        ---------------------------------------------------------------------------
        GEN_BRAM_ADDR: for i in C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR generate
        begin    
            BRAM_Addr_A (i) <= bram_addr_int (i);        
        end generate GEN_BRAM_ADDR;

    end generate ADDR_SNG_PORT;


    ---------------------------------------------------------------------------
    -- Generate:    ADDR_DUAL_PORT
    -- Purpose:     Assign each BRAM address when in a dual port controller 
    --              configuration.
    ---------------------------------------------------------------------------
    ADDR_DUAL_PORT: if C_SINGLE_PORT_BRAM = 0 generate
    begin
        BRAM_Addr_A <= BRAM_Addr_A_i;
        BRAM_Addr_B <= BRAM_Addr_B_i;
        BRAM_En_A <= BRAM_En_A_i;
        BRAM_En_B <= BRAM_En_B_i;
        
        BRAM_WE_A <= BRAM_WE_A_i;
        
        BRAM_RdData_i <= BRAM_RdData_B;     -- Assign read data port B
    end generate ADDR_DUAL_PORT;


    BRAM_WrData_B <= (others => '0');
    BRAM_WE_B <= (others => '0');




    ---------------------------------------------------------------------------
    -- *** AXI-Lite ECC Register Output Signals ***
    ---------------------------------------------------------------------------



    ---------------------------------------------------------------------------
    -- Generate:    GEN_NO_REGS
    -- Purpose:     Generate default values if ECC registers are disabled (or when
    --              ECC is disabled).
    --              Include both AXI-Lite default signal values & internal
    --              core signal values.
    ---------------------------------------------------------------------------

    GEN_NO_REGS: if (C_ECC = 0) generate
    begin
    
        S_AXI_CTRL_AWREADY <= '0';
        S_AXI_CTRL_WREADY <= '0';
        S_AXI_CTRL_BRESP <= (others => '0');
        S_AXI_CTRL_BVALID <= '0';
        S_AXI_CTRL_ARREADY <= '0';
        S_AXI_CTRL_RDATA <= (others => '0');
        S_AXI_CTRL_RRESP <= (others => '0');
        S_AXI_CTRL_RVALID <= '0';
                
        -- No fault injection
        FaultInjectData <= (others => '0');
        FaultInjectECC <= (others => '0');
                
        -- Interrupt only enabled when ECC status/interrupt registers enabled
        ECC_Interrupt <= '0';
        ECC_UE <= '0';
        
        Enable_ECC <= '0';

    end generate GEN_NO_REGS;




    ---------------------------------------------------------------------------
    -- Generate:    GEN_REGS
    -- Purpose:     Generate ECC register module when ECC is enabled and
    --              ECC registers are enabled.
    ---------------------------------------------------------------------------

    -- GEN_REGS: if (C_ECC = 1 and C_ENABLE_AXI_CTRL_REG_IF = 1) generate
    -- For future implementation.

    GEN_REGS: if (C_ECC = 1) generate
    begin

        ---------------------------------------------------------------------------
        -- Instance:        I_LITE_ECC_REG
        -- Description:     This module is for the AXI-Lite ECC registers. 
        --
        --              Responsible for all AXI-Lite communication to the 
        --              ECC register bank.  Provides user interface signals
        --              to rest of AXI BRAM controller IP core for ECC functionality
        --              and control.
        --              Manages AXI-Lite write address (AW) and read address (AR),
        --              write data (W), write response (B), and read data (R) channels.
        ---------------------------------------------------------------------------
        
        I_LITE_ECC_REG : entity work.lite_ecc_reg
        generic map (
        
            C_S_AXI_PROTOCOL                =>  C_S_AXI_PROTOCOL                ,
            C_S_AXI_DATA_WIDTH              =>  C_S_AXI_DATA_WIDTH              ,
            C_S_AXI_ADDR_WIDTH              =>  C_S_AXI_ADDR_WIDTH              ,             
            C_SINGLE_PORT_BRAM              =>  C_SINGLE_PORT_BRAM              ,                  

            C_BRAM_ADDR_ADJUST_FACTOR       =>  C_BRAM_ADDR_ADJUST_FACTOR       ,
        
            C_S_AXI_CTRL_ADDR_WIDTH         =>  C_S_AXI_CTRL_ADDR_WIDTH         ,
            C_S_AXI_CTRL_DATA_WIDTH         =>  C_S_AXI_CTRL_DATA_WIDTH         ,    
            
            C_ECC_WIDTH                     =>  C_INT_ECC_WIDTH                 ,       -- ECC width specific to data width
            C_FAULT_INJECT                  =>  C_FAULT_INJECT                  ,
            C_CE_FAILING_REGISTERS          =>  C_CE_FAILING_REGISTERS          ,
            C_UE_FAILING_REGISTERS          =>  C_UE_FAILING_REGISTERS          ,
            C_ECC_STATUS_REGISTERS          =>  C_ECC_STATUS_REGISTERS          ,
            C_ECC_ONOFF_REGISTER            =>  C_ECC_ONOFF_REGISTER            ,
            C_ECC_ONOFF_RESET_VALUE         =>  C_ECC_ONOFF_RESET_VALUE         ,
            C_CE_COUNTER_WIDTH              =>  C_CE_COUNTER_WIDTH                      
        )
        port map (
        
            S_AXI_AClk              =>  S_AXI_AClk          ,       -- AXI clock 
            S_AXI_AResetn           =>  S_AXI_AResetn       ,  

            -- TBD
            -- S_AXI_CTRL_AClk         =>  S_AXI_CTRL_AClk     ,       -- AXI-Lite clock
            -- S_AXI_CTRL_AResetn      =>  S_AXI_CTRL_AResetn  ,  

            Interrupt               =>  ECC_Interrupt           ,
            ECC_UE                  =>  ECC_UE                  ,

            -- Add AXI-Lite ECC Register Ports
            AXI_CTRL_AWVALID        =>  S_AXI_CTRL_AWVALID     ,  
            AXI_CTRL_AWREADY        =>  S_AXI_CTRL_AWREADY     ,  
            AXI_CTRL_AWADDR         =>  S_AXI_CTRL_AWADDR      ,  

            AXI_CTRL_WDATA          =>  S_AXI_CTRL_WDATA       ,  
            AXI_CTRL_WVALID         =>  S_AXI_CTRL_WVALID      ,  
            AXI_CTRL_WREADY         =>  S_AXI_CTRL_WREADY      ,  

            AXI_CTRL_BRESP          =>  S_AXI_CTRL_BRESP       ,  
            AXI_CTRL_BVALID         =>  S_AXI_CTRL_BVALID      ,  
            AXI_CTRL_BREADY         =>  S_AXI_CTRL_BREADY      ,  

            AXI_CTRL_ARADDR         =>  S_AXI_CTRL_ARADDR      ,  
            AXI_CTRL_ARVALID        =>  S_AXI_CTRL_ARVALID     ,  
            AXI_CTRL_ARREADY        =>  S_AXI_CTRL_ARREADY     ,  

            AXI_CTRL_RDATA          =>  S_AXI_CTRL_RDATA       ,  
            AXI_CTRL_RRESP          =>  S_AXI_CTRL_RRESP       ,  
            AXI_CTRL_RVALID         =>  S_AXI_CTRL_RVALID      ,  
            AXI_CTRL_RREADY         =>  S_AXI_CTRL_RREADY      ,  


            Enable_ECC              =>  Enable_ECC          ,
            FaultInjectClr          =>  FaultInjectClr      ,    
            CE_Failing_We           =>  CE_Failing_We       ,
            CE_CounterReg_Inc       =>  CE_Failing_We       ,
            Sl_CE                   =>  Sl_CE               ,
            Sl_UE                   =>  Sl_UE               ,

            BRAM_Addr_A             =>  BRAM_Addr_A_i (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)   ,       -- v1.03a
            BRAM_Addr_B             =>  BRAM_Addr_B_i (C_S_AXI_ADDR_WIDTH-1 downto C_BRAM_ADDR_ADJUST_FACTOR)   ,       -- v1.03a
            BRAM_Addr_En            =>  BRAM_Addr_En        ,
            Active_Wr               =>  Active_Wr           ,
            -- BRAM_RdData_A           =>  BRAM_RdData_A (C_S_AXI_DATA_WIDTH-1 downto 0)       ,
            -- BRAM_RdData_B           =>  BRAM_RdData_B (C_S_AXI_DATA_WIDTH-1 downto 0)       ,   

            FaultInjectData         =>  FaultInjectData     ,
            FaultInjectECC          =>  FaultInjectECC_i      
            
            );
            
            
            BRAM_Addr_En <= Wr_BRAM_Addr_En or Rd_BRAM_Addr_En;
            
            -- v1.03a
            -- Add coverage tags for Wr_CE_Failing_We.
            -- No testing on forcing errors with RMW and AXI write transfers.
            
--coverage off
            CE_Failing_We <= Wr_CE_Failing_We or Rd_CE_Failing_We;          
            Sl_CE <= Wr_Sl_CE or Rd_Sl_CE;
            Sl_UE <= Wr_Sl_UE or Rd_Sl_UE;    
--coverage on
            
            
            -------------------------------------------------------------------
            -- Generate:    GEN_32
            -- Purpose:     Add MSB '0' on ECC vector as only 7-bits wide in 32-bit.
            -------------------------------------------------------------------
            GEN_32: if C_S_AXI_DATA_WIDTH = 32 generate
            begin
                FaultInjectECC <= '0' & FaultInjectECC_i;
            end generate GEN_32;

            -------------------------------------------------------------------
            -- Generate:    GEN_NON_32
            -- Purpose:     Data widths match at 8-bits for ECC on 64-bit data.
            --              And 9-bits for 128-bit data.
            -------------------------------------------------------------------
            GEN_NON_32: if C_S_AXI_DATA_WIDTH /= 32 generate
            begin
                FaultInjectECC <= FaultInjectECC_i;
            end generate GEN_NON_32;
                       


        
    end generate GEN_REGS;
        







    ---------------------------------------------------------------------------
    -- Generate:    GEN_ARB
    -- Purpose:     Generate arbitration module when AXI4 is configured in 
    --              single port mode.
    ---------------------------------------------------------------------------

    GEN_ARB: if (C_SINGLE_PORT_BRAM = 1) generate
    begin

        ---------------------------------------------------------------------------
        -- Instance:        I_LITE_ECC_REG
        -- Description:     This module is for the AXI-Lite ECC registers. 
        --
        --              Responsible for all AXI-Lite communication to the 
        --              ECC register bank.  Provides user interface signals
        --              to rest of AXI BRAM controller IP core for ECC functionality
        --              and control.
        --              Manages AXI-Lite write address (AW) and read address (AR),
        --              write data (W), write response (B), and read data (R) channels.
        ---------------------------------------------------------------------------
        
        I_SNG_PORT : entity work.sng_port_arb
        generic map (
            C_S_AXI_ADDR_WIDTH          =>  C_S_AXI_ADDR_WIDTH                  
        )
        port map (

            S_AXI_AClk                  =>  S_AXI_AClk              ,       -- AXI clock 
            S_AXI_AResetn               =>  S_AXI_AResetn           ,  

            AXI_AWADDR                  =>  S_AXI_AWADDR (C_S_AXI_ADDR_WIDTH-1 downto 0),
            AXI_AWVALID                 =>  S_AXI_AWVALID           ,
            AXI_AWREADY                 =>  S_AXI_AWREADY           ,           

            AXI_ARADDR                  =>  S_AXI_ARADDR (C_S_AXI_ADDR_WIDTH-1 downto 0),
            AXI_ARVALID                 =>  S_AXI_ARVALID               , 
            AXI_ARREADY                 =>  S_AXI_ARREADY               ,

            Arb2AW_Active               =>  Arb2AW_Active               ,
            AW2Arb_Busy                 =>  AW2Arb_Busy                 ,
            AW2Arb_Active_Clr           =>  AW2Arb_Active_Clr           ,
            AW2Arb_BVALID_Cnt           =>  AW2Arb_BVALID_Cnt           ,

            Arb2AR_Active               =>  Arb2AR_Active               ,
            AR2Arb_Active_Clr           =>  AR2Arb_Active_Clr           

        );    


    end generate GEN_ARB;




    ---------------------------------------------------------------------------
    -- Generate:    GEN_DUAL
    -- Purpose:     Dual mode. AWREADY and ARREADY are generated from each
    --              wr_chnl and rd_chnl module.
    ---------------------------------------------------------------------------

    GEN_DUAL: if (C_SINGLE_PORT_BRAM = 0) generate
    begin
    
        S_AXI_AWREADY <= S_AXI_AWREADY_i;
        S_AXI_ARREADY <= S_AXI_ARREADY_i;
        
        Arb2AW_Active <= '0';
        Arb2AR_Active <= '0';
        
    end generate GEN_DUAL;




    ---------------------------------------------------------------------------
    -- Instance: I_WR_CHNL
    --
    -- Description:
    --  BRAM controller write channel logic.  Controls AXI bus handshaking and
    --  data flow on the write address (AW), write data (W) and 
    --  write response (B) channels.
    --
    --  BRAM signals are marked as output from Wr Chnl for future implementation
    --  of merging Wr/Rd channel outputs to a single port of the BRAM module.
    --
    ---------------------------------------------------------------------------

    I_WR_CHNL : entity work.wr_chnl
    generic map (

        -- C_FAMILY                    =>  C_FAMILY                            ,
        C_AXI_ID_WIDTH              =>  C_S_AXI_ID_WIDTH                    ,
        C_AXI_DATA_WIDTH            =>  C_S_AXI_DATA_WIDTH                  ,
        C_AXI_ADDR_WIDTH            =>  C_S_AXI_ADDR_WIDTH                  ,  
        C_BRAM_ADDR_ADJUST_FACTOR   =>  C_BRAM_ADDR_ADJUST_FACTOR           ,
        C_S_AXI_PROTOCOL            =>  C_S_AXI_PROTOCOL                    ,
        C_S_AXI_SUPPORTS_NARROW     =>  C_S_AXI_SUPPORTS_NARROW_BURST       ,       
        C_SINGLE_PORT_BRAM          =>  C_SINGLE_PORT_BRAM                  ,
        C_ECC                       =>  C_ECC                               ,
        C_ECC_WIDTH                 =>  C_ECC_WIDTH                         ,
        C_ECC_TYPE                  =>  C_ECC_TYPE                                  -- v1.03a 

    )
    port map (

        S_AXI_AClk              =>  S_AXI_ACLK          ,
        S_AXI_AResetn           =>  S_AXI_ARESETN       ,  

        AXI_AWID                =>  S_AXI_AWID            ,
        AXI_AWADDR              =>  S_AXI_AWADDR (C_S_AXI_ADDR_WIDTH-1 downto 0),

        AXI_AWLEN               =>  S_AXI_AWLEN           ,        
        AXI_AWSIZE              =>  S_AXI_AWSIZE          ,        
        AXI_AWBURST             =>  S_AXI_AWBURST         ,        
        AXI_AWLOCK              =>  S_AXI_AWLOCK          ,        
        AXI_AWCACHE             =>  S_AXI_AWCACHE         ,        
        AXI_AWPROT              =>  S_AXI_AWPROT          ,        
        AXI_AWVALID             =>  S_AXI_AWVALID         ,
        AXI_AWREADY             =>  S_AXI_AWREADY_i       ,           

        AXI_WDATA               =>  S_AXI_WDATA           ,
        AXI_WSTRB               =>  S_AXI_WSTRB           ,
        AXI_WLAST               =>  S_AXI_WLAST           ,
        AXI_WVALID              =>  S_AXI_WVALID          ,
        AXI_WREADY              =>  S_AXI_WREADY          ,

        AXI_BID                 =>  S_AXI_BID             ,
        AXI_BRESP               =>  S_AXI_BRESP           ,
        AXI_BVALID              =>  S_AXI_BVALID          ,
        AXI_BREADY              =>  S_AXI_BREADY          ,

        -- Arb Ports
        Arb2AW_Active           =>  Arb2AW_Active           ,
        AW2Arb_Busy             =>  AW2Arb_Busy             ,
        AW2Arb_Active_Clr       =>  AW2Arb_Active_Clr       ,
        AW2Arb_BVALID_Cnt       =>  AW2Arb_BVALID_Cnt       ,
        Sng_BRAM_Addr_Rst       =>  WrChnl_BRAM_Addr_Rst        ,
        Sng_BRAM_Addr_Ld_En     =>  WrChnl_BRAM_Addr_Ld_En      ,
        Sng_BRAM_Addr_Ld        =>  WrChnl_BRAM_Addr_Ld         ,
        Sng_BRAM_Addr_Inc       =>  WrChnl_BRAM_Addr_Inc        ,
        Sng_BRAM_Addr           =>  bram_addr_int               ,
        
        -- ECC Ports
        Enable_ECC              =>  Enable_ECC              ,
        BRAM_Addr_En            =>  Wr_BRAM_Addr_En         ,
        FaultInjectClr          =>  FaultInjectClr          ,    
        CE_Failing_We           =>  Wr_CE_Failing_We        ,
        Sl_CE                   =>  Wr_Sl_CE                ,
        Sl_UE                   =>  Wr_Sl_UE                ,
        Active_Wr               =>  Active_Wr               ,

        FaultInjectData         =>  FaultInjectData         ,
        FaultInjectECC          =>  FaultInjectECC          ,  

        BRAM_En                 =>  BRAM_En_A_i             ,
--        BRAM_WE                 =>  BRAM_WE_A               ,
-- 4/13
        BRAM_WE                 =>  BRAM_WE_A_i             ,
        BRAM_WrData             =>  BRAM_WrData_A           ,
        BRAM_RdData             =>  BRAM_RdData_A           ,
        BRAM_Addr               =>  BRAM_Addr_A_i   


    );    




    ---------------------------------------------------------------------------
    -- Instance: I_RD_CHNL
    --
    -- Description:
    --  BRAM controller read channel logic.  Controls all handshaking and data
    --  flow on read address (AR) and read data (R) AXI channels.
    --
    --  BRAM signals are marked as Rd Chnl signals for future implementation
    --  of merging Rd/Wr BRAM signals to a single BRAM port.
    --
    ---------------------------------------------------------------------------

    I_RD_CHNL : entity work.rd_chnl
    generic map (

        -- C_FAMILY                    =>  C_FAMILY                            ,
        C_AXI_ID_WIDTH              =>  C_S_AXI_ID_WIDTH                    ,
        C_AXI_DATA_WIDTH            =>  C_S_AXI_DATA_WIDTH                  ,
        C_AXI_ADDR_WIDTH            =>  C_S_AXI_ADDR_WIDTH                  ,
        C_BRAM_ADDR_ADJUST_FACTOR   =>  C_BRAM_ADDR_ADJUST_FACTOR           ,
        C_S_AXI_PROTOCOL            =>  C_S_AXI_PROTOCOL                    ,
        C_S_AXI_SUPPORTS_NARROW     =>  C_S_AXI_SUPPORTS_NARROW_BURST       ,        
        C_SINGLE_PORT_BRAM          =>  C_SINGLE_PORT_BRAM                  ,
        C_ECC                       =>  C_ECC                               ,
        C_ECC_WIDTH                 =>  C_ECC_WIDTH                         ,
        C_ECC_TYPE                  =>  C_ECC_TYPE                                  -- v1.03a 

    )   
    port map (

          S_AXI_AClk              =>  S_AXI_ACLK              ,
          S_AXI_AResetn           =>  S_AXI_ARESETN           ,     
          AXI_ARID                =>  S_AXI_ARID              ,
          AXI_ARADDR              =>  S_AXI_ARADDR (C_S_AXI_ADDR_WIDTH-1 downto 0),

          AXI_ARLEN               =>  S_AXI_ARLEN             , 
          AXI_ARSIZE              =>  S_AXI_ARSIZE            , 
          AXI_ARBURST             =>  S_AXI_ARBURST           , 
          AXI_ARLOCK              =>  S_AXI_ARLOCK            , 
          AXI_ARCACHE             =>  S_AXI_ARCACHE           , 
          AXI_ARPROT              =>  S_AXI_ARPROT            , 
          AXI_ARVALID             =>  S_AXI_ARVALID           , 
          AXI_ARREADY             =>  S_AXI_ARREADY_i         , 

          AXI_RID                 =>  S_AXI_RID               ,          
          AXI_RDATA               =>  S_AXI_RDATA             ,          
          AXI_RRESP               =>  S_AXI_RRESP             ,          
          AXI_RLAST               =>  S_AXI_RLAST             ,        
          AXI_RVALID              =>  S_AXI_RVALID            ,       
          AXI_RREADY              =>  S_AXI_RREADY            ,       

          -- Arb Ports
          Arb2AR_Active           =>  Arb2AR_Active           ,
          AR2Arb_Active_Clr       =>  AR2Arb_Active_Clr       ,      
        
          Sng_BRAM_Addr_Ld_En     =>  RdChnl_BRAM_Addr_Ld_En      ,
          Sng_BRAM_Addr_Ld        =>  RdChnl_BRAM_Addr_Ld         ,
          Sng_BRAM_Addr_Inc       =>  RdChnl_BRAM_Addr_Inc        ,
          Sng_BRAM_Addr           =>  bram_addr_int               ,

          -- ECC Ports
          Enable_ECC              =>  Enable_ECC              ,
          BRAM_Addr_En            =>  Rd_BRAM_Addr_En         ,
          CE_Failing_We           =>  Rd_CE_Failing_We        ,
          Sl_CE                   =>  Rd_Sl_CE                ,
          Sl_UE                   =>  Rd_Sl_UE                ,

          BRAM_En                 =>  BRAM_En_B_i             ,
          BRAM_Addr               =>  BRAM_Addr_B_i           ,   
          BRAM_RdData             =>  BRAM_RdData_i


    );






end architecture implementation;










-------------------------------------------------------------------------------
-- axi_bram_ctrl_top.vhd
-------------------------------------------------------------------------------
--
--
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
--
--
-------------------------------------------------------------------------------
-- Filename:        axi_bram_ctrl_top.vhd
--
-- Description:     This file is the top level module for the AXI BRAM
--                  controller IP core.
--
-- VHDL-Standard:   VHDL'93
--
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl_top.vhd (v4_0)
--                      |
--                      |-- full_axi.vhd
--                      |   -- sng_port_arb.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- wr_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |   -- rd_chnl.vhd
--                      |       -- wrap_brst.vhd
--                      |       -- ua_narrow.vhd
--                      |       -- checkbit_handler.vhd
--                      |           -- xor18.vhd
--                      |           -- parity.vhd
--                      |       -- checkbit_handler_64.vhd
--                      |           -- (same helper components as checkbit_handler)
--                      |       -- parity.vhd
--                      |       -- correct_one_bit.vhd
--                      |       -- correct_one_bit_64.vhd
--                      |       -- ecc_gen.vhd
--                      |
--                      |-- axi_lite.vhd
--                      |   -- lite_ecc_reg.vhd
--                      |       -- axi_lite_if.vhd
--                      |   -- checkbit_handler.vhd
--                      |       -- xor18.vhd
--                      |       -- parity.vhd
--                      |   -- correct_one_bit.vhd
--                      |   -- ecc_gen.vhd
--
--
--
-------------------------------------------------------------------------------
--
-- History:
--
-- ^^^^^^
-- JLJ      2/1/2011         v1.03a
-- ~~~~~~
--  Migrate to v1.03a.
--  Plus minor code cleanup.
-- ^^^^^^
-- JLJ      2/2/2011         v1.03a
-- ~~~~~~
--  Remove library version # dependency.  Replace with work library.
-- ^^^^^^
-- JLJ      2/9/2011         v1.03a
-- ~~~~~~
--  Update Create_Size_Default function to support 512 & 1024-bit BRAM.
--  Replace usage of Create_Size_Default function.
-- ^^^^^^
-- JLJ      2/15/2011        v1.03a
-- ~~~~~~
--  Initial integration of Hsiao ECC algorithm.
--  Add C_ECC_TYPE top level parameter on full_axi module.
--  Update ECC signal sizes for 128-bit support.
-- ^^^^^^
-- JLJ      2/16/2011      v1.03a
-- ~~~~~~
--  Update WE size based on 128-bit ECC configuration.
-- ^^^^^^
-- JLJ      2/22/2011      v1.03a
-- ~~~~~~
--  Add C_ECC_TYPE top level parameter on axi_lite module.
-- ^^^^^^
-- JLJ      2/23/2011      v1.03a
-- ~~~~~~
--  Set C_ECC_TYPE = 1 for Hsiao DV regressions.
-- ^^^^^^
-- JLJ      2/24/2011      v1.03a
-- ~~~~~~
--  Move Find_ECC_Size function to package.
-- ^^^^^^
-- JLJ      3/17/2011      v1.03a
-- ~~~~~~
--  Add comments as noted in Spyglass runs.
-- ^^^^^^
-- JLJ      5/6/2011      v1.03a
-- ~~~~~~
--  Remove C_FAMILY from top level.
--  Remove C_FAMILY in axi_lite sub module.
-- ^^^^^^
-- JLJ      6/23/2011      v1.03a
-- ~~~~~~
--  Migrate 9-bit ECC to 16-bit ECC for 128-bit BRAM data width.
-- ^^^^^^
--
--
--
-------------------------------------------------------------------------------

-- Library declarations

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.numeric_std.all;

library work;
use work.axi_lite;
use work.full_axi;
use work.axi_bram_ctrl_funcs.all;

------------------------------------------------------------------------------


entity axi_bram_ctrl_top is
generic (


    -- AXI Parameters

    C_BRAM_ADDR_WIDTH  : integer := 12;
        -- Width of AXI address bus (in bits)

    C_S_AXI_ADDR_WIDTH  : integer := 32;
        -- Width of AXI address bus (in bits)

    C_S_AXI_DATA_WIDTH  : integer := 32;
        -- Width of AXI data bus (in bits)

    C_S_AXI_ID_WIDTH : INTEGER := 4;
        --  AXI ID vector width

    C_S_AXI_PROTOCOL : string := "AXI4";
        -- Set to AXI4LITE to optimize out burst transaction support

    C_S_AXI_SUPPORTS_NARROW_BURST : INTEGER := 1;
        -- Support for narrow burst operations

    C_SINGLE_PORT_BRAM : INTEGER := 0;
        -- Enable single port usage of BRAM

    -- C_FAMILY : string := "virtex6";
        -- Specify the target architecture type



    -- AXI-Lite Register Parameters

    C_S_AXI_CTRL_ADDR_WIDTH : integer := 32;
        -- Width of AXI-Lite address bus (in bits)

    C_S_AXI_CTRL_DATA_WIDTH  : integer := 32;
        -- Width of AXI-Lite data bus (in bits)



    -- ECC Parameters

    C_ECC : integer := 0;
        -- Enables or disables ECC functionality
    C_ECC_TYPE  : integer := 1;           

    C_FAULT_INJECT : integer := 0;
        -- Enable fault injection registers
        -- (default = disabled)

    C_ECC_ONOFF_RESET_VALUE : integer := 1
        -- By default, ECC checking is on
        -- (can disable ECC @ reset by setting this to 0)


    -- Reserved parameters for future implementations.

        -- C_ENABLE_AXI_CTRL_REG_IF : integer := 1;
            -- By default the ECC AXI-Lite register interface is enabled

        -- C_CE_FAILING_REGISTERS : integer := 1;
            -- Enable CE (correctable error) failing registers

        -- C_UE_FAILING_REGISTERS : integer := 1;
            -- Enable UE (uncorrectable error) failing registers

        -- C_ECC_STATUS_REGISTERS : integer := 1;
            -- Enable ECC status registers

        -- C_ECC_ONOFF_REGISTER : integer := 1;
            -- Enable ECC on/off control register

        -- C_CE_COUNTER_WIDTH : integer := 0
            -- Selects CE counter width/threshold to assert ECC_Interrupt


       );
  port (


    -- AXI Interface Signals

    -- AXI Clock and Reset
    S_AXI_ACLK              : in    std_logic;
    S_AXI_ARESETN           : in    std_logic;

    ECC_Interrupt           : out   std_logic := '0';
    ECC_UE                  : out   std_logic := '0';

    -- AXI Write Address Channel Signals (AW)
    S_AXI_AWID              : in    std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_AWADDR            : in    std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_AWLEN             : in    std_logic_vector(7 downto 0);
    S_AXI_AWSIZE            : in    std_logic_vector(2 downto 0);
    S_AXI_AWBURST           : in    std_logic_vector(1 downto 0);
    S_AXI_AWLOCK            : in    std_logic;
    S_AXI_AWCACHE           : in    std_logic_vector(3 downto 0);
    S_AXI_AWPROT            : in    std_logic_vector(2 downto 0);
    S_AXI_AWVALID           : in    std_logic;
    S_AXI_AWREADY           : out   std_logic;


    -- AXI Write Data Channel Signals (W)
    S_AXI_WDATA             : in    std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_WSTRB             : in    std_logic_vector(C_S_AXI_DATA_WIDTH/8-1 downto 0);
    S_AXI_WLAST             : in    std_logic;

    S_AXI_WVALID            : in    std_logic;
    S_AXI_WREADY            : out   std_logic;


    -- AXI Write Data Response Channel Signals (B)
    S_AXI_BID               : out   std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_BRESP             : out   std_logic_vector(1 downto 0);

    S_AXI_BVALID            : out   std_logic;
    S_AXI_BREADY            : in    std_logic;



    -- AXI Read Address Channel Signals (AR)
    S_AXI_ARID              : in    std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_ARADDR            : in    std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    S_AXI_ARLEN             : in    std_logic_vector(7 downto 0);
    S_AXI_ARSIZE            : in    std_logic_vector(2 downto 0);
    S_AXI_ARBURST           : in    std_logic_vector(1 downto 0);
    S_AXI_ARLOCK            : in    std_logic;
    S_AXI_ARCACHE           : in    std_logic_vector(3 downto 0);
    S_AXI_ARPROT            : in    std_logic_vector(2 downto 0);

    S_AXI_ARVALID           : in    std_logic;
    S_AXI_ARREADY           : out   std_logic;


    -- AXI Read Data Channel Signals (R)
    S_AXI_RID               : out   std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    S_AXI_RDATA             : out   std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    S_AXI_RRESP             : out   std_logic_vector(1 downto 0);
    S_AXI_RLAST             : out   std_logic;

    S_AXI_RVALID            : out   std_logic;
    S_AXI_RREADY            : in    std_logic;




    -- AXI-Lite ECC Register Interface Signals

    -- AXI-Lite Clock and Reset
    -- Note: AXI-Lite Control IF and AXI IF share the same clock.
    -- S_AXI_CTRL_ACLK             : in    std_logic;
    -- S_AXI_CTRL_ARESETN          : in    std_logic;

    -- AXI-Lite Write Address Channel Signals (AW)
    S_AXI_CTRL_AWVALID          : in    std_logic;
    S_AXI_CTRL_AWREADY          : out   std_logic;
    S_AXI_CTRL_AWADDR           : in    std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);


    -- AXI-Lite Write Data Channel Signals (W)
    S_AXI_CTRL_WDATA            : in    std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    S_AXI_CTRL_WVALID           : in    std_logic;
    S_AXI_CTRL_WREADY           : out   std_logic;


    -- AXI-Lite Write Data Response Channel Signals (B)
    S_AXI_CTRL_BRESP            : out   std_logic_vector(1 downto 0);
    S_AXI_CTRL_BVALID           : out   std_logic;
    S_AXI_CTRL_BREADY           : in    std_logic;


    -- AXI-Lite Read Address Channel Signals (AR)
    S_AXI_CTRL_ARADDR           : in    std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);
    S_AXI_CTRL_ARVALID          : in    std_logic;
    S_AXI_CTRL_ARREADY          : out   std_logic;


    -- AXI-Lite Read Data Channel Signals (R)
    S_AXI_CTRL_RDATA             : out   std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    S_AXI_CTRL_RRESP             : out   std_logic_vector(1 downto 0);
    S_AXI_CTRL_RVALID            : out   std_logic;
    S_AXI_CTRL_RREADY            : in    std_logic;



    -- BRAM Interface Signals (Port A)
    BRAM_Rst_A              : out   std_logic;
    BRAM_Clk_A              : out   std_logic;
    BRAM_En_A               : out   std_logic;
    BRAM_WE_A               : out   std_logic_vector (C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);
    BRAM_Addr_A             : out   std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0);
    BRAM_WrData_A           : out   std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);
    BRAM_RdData_A           : in    std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);


    -- BRAM Interface Signals (Port B)
    BRAM_Rst_B              : out   std_logic;
    BRAM_Clk_B              : out   std_logic;
    BRAM_En_B               : out   std_logic;
    BRAM_WE_B               : out   std_logic_vector (C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);
    BRAM_Addr_B             : out   std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0);
    BRAM_WrData_B           : out   std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);
    BRAM_RdData_B           : in    std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0)



    );



end entity axi_bram_ctrl_top;


-------------------------------------------------------------------------------

architecture implementation of axi_bram_ctrl_top is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";

-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------

-- All functions defined in axi_bram_ctrl_funcs package.


-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

-- Model behavior of AXI Interconnect in simulation for wrapping of ID values.
constant C_SIM_ONLY         : std_logic := '1';

-- Reset active level (common through core)
constant C_RESET_ACTIVE     : std_logic := '0';


-- Create top level constant to assign fixed value to ARSIZE and AWSIZE
-- when narrow bursting is parameterized out of the IP core instantiation.

-- constant AXI_FIXED_SIZE_WO_NARROW   : std_logic_vector (2 downto 0) := Create_Size_Default;

-- v1.03a
constant AXI_FIXED_SIZE_WO_NARROW   : integer := log2 (C_S_AXI_DATA_WIDTH/8);


-- Only instantiate logic based on C_S_AXI_PROTOCOL.
constant IF_IS_AXI4      : boolean := (Equal_String (C_S_AXI_PROTOCOL, "AXI4"));
constant IF_IS_AXI4LITE  : boolean := (Equal_String (C_S_AXI_PROTOCOL, "AXI4LITE"));


-- Determine external ECC width.
-- Use function defined in axi_bram_ctrl_funcs package.
constant C_ECC_WIDTH : integer := Find_ECC_Size (C_ECC, C_S_AXI_DATA_WIDTH);
constant C_ECC_FULL_BIT_WIDTH : integer := Find_ECC_Full_Bit_Size (C_ECC, C_S_AXI_DATA_WIDTH);


-- Set internal parameters for ECC register enabling when C_ECC = 1
constant C_ENABLE_AXI_CTRL_REG_IF_I : integer := C_ECC;
constant C_CE_FAILING_REGISTERS_I   : integer := C_ECC;
constant C_UE_FAILING_REGISTERS_I   : integer := 0;         -- Remove all UE registers
                                                            -- Catastrophic error indicated with ECC_UE & Interrupt flags.
constant C_ECC_STATUS_REGISTERS_I   : integer := C_ECC;
constant C_ECC_ONOFF_REGISTER_I     : integer := C_ECC;

constant C_CE_COUNTER_WIDTH         : integer := 8 * C_ECC;
-- Counter only sized when C_ECC = 1.
-- Selects CE counter width/threshold to assert ECC_Interrupt
-- Hard coded at 8-bits to capture and count up to 256 correctable errors.


--constant C_ECC_TYPE                 : integer := 1;             -- v1.03a
-- ECC algorithm format, 0 = Hamming code, 1 = Hsiao code


-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------


-- Internal BRAM Signals

-- Port A
signal bram_en_a_int            : std_logic := '0';
signal bram_we_a_int            : std_logic_vector (((C_S_AXI_DATA_WIDTH+C_ECC_FULL_BIT_WIDTH)/8)-1 downto 0) := (others => '0');
signal bram_addr_a_int          : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
signal bram_wrdata_a_int        : std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0) := (others => '0');
signal bram_rddata_a_int        : std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0) := (others => '0');

-- Port B
signal bram_addr_b_int          : std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
signal bram_en_b_int            : std_logic := '0';
signal bram_we_b_int            : std_logic_vector (((C_S_AXI_DATA_WIDTH+C_ECC_FULL_BIT_WIDTH)/8)-1 downto 0) := (others => '0');
signal bram_wrdata_b_int        : std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0) := (others => '0');
signal bram_rddata_b_int        : std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0) := (others => '0');

signal axi_awsize_int           : std_logic_vector(2 downto 0) := (others => '0');
signal axi_arsize_int           : std_logic_vector(2 downto 0) := (others => '0');

signal S_AXI_ARREADY_int    : std_logic := '0';
signal S_AXI_AWREADY_int    : std_logic := '0';

signal S_AXI_RID_int        : std_logic_vector (C_S_AXI_ID_WIDTH-1 downto 0) := (others => '0');
signal S_AXI_BID_int        : std_logic_vector (C_S_AXI_ID_WIDTH-1 downto 0) := (others => '0');




-------------------------------------------------------------------------------
-- Architecture Body
-------------------------------------------------------------------------------


begin



    -- *** BRAM Port A Output Signals ***

    BRAM_Rst_A <= not (S_AXI_ARESETN);
    BRAM_Clk_A <= S_AXI_ACLK;
    BRAM_En_A <= bram_en_a_int;
    BRAM_WE_A ((((C_S_AXI_DATA_WIDTH + C_ECC_FULL_BIT_WIDTH)/8) - 1) downto (C_ECC_FULL_BIT_WIDTH/8)) <= bram_we_a_int((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    BRAM_Addr_A <= bram_addr_a_int;
    bram_rddata_a_int (C_S_AXI_DATA_WIDTH-1 downto 0) <= BRAM_RdData_A ((C_S_AXI_DATA_WIDTH + C_ECC_FULL_BIT_WIDTH - 1) downto (C_ECC_FULL_BIT_WIDTH));

    BRAM_WrData_A ((C_S_AXI_DATA_WIDTH + C_ECC_FULL_BIT_WIDTH - 1) downto (C_ECC_FULL_BIT_WIDTH)) <= bram_wrdata_a_int(C_S_AXI_DATA_WIDTH-1 downto 0);

    -- Added for 13.3
    -- Drive unused upper ECC bits to '0'
    -- For bram_block compatibility, must drive unused upper bits to '0' for ECC 128-bit use case.
    GEN_128_ECC_WR: if (C_S_AXI_DATA_WIDTH = 128) and (C_ECC = 1) generate
    begin
        BRAM_WrData_A ((C_ECC_FULL_BIT_WIDTH - 1) downto (C_ECC_WIDTH)) <= (others => '0');
        BRAM_WrData_A ((C_ECC_WIDTH-1) downto 0) <= bram_wrdata_a_int(C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto C_S_AXI_DATA_WIDTH);
        
        BRAM_WE_A ((C_ECC_FULL_BIT_WIDTH/8) - 1  downto 0) <= bram_we_a_int(((C_S_AXI_DATA_WIDTH+C_ECC_FULL_BIT_WIDTH)/8)-1 downto (C_S_AXI_DATA_WIDTH/8));
        
        bram_rddata_a_int (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto C_S_AXI_DATA_WIDTH) <= BRAM_RdData_A ((C_ECC_WIDTH-1) downto 0);
    end generate GEN_128_ECC_WR;

    GEN_ECC_WR: if ( not (C_S_AXI_DATA_WIDTH = 128) and (C_ECC = 1)) generate
    begin
        BRAM_WrData_A ((C_ECC_WIDTH - 1) downto 0) <= bram_wrdata_a_int(C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto C_S_AXI_DATA_WIDTH);

        BRAM_WE_A ((C_ECC_FULL_BIT_WIDTH/8) - 1 downto 0) <= bram_we_a_int(((C_S_AXI_DATA_WIDTH+C_ECC_FULL_BIT_WIDTH)/8)-1 downto (C_S_AXI_DATA_WIDTH/8));

        bram_rddata_a_int (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto C_S_AXI_DATA_WIDTH) <= BRAM_RdData_A ((C_ECC_WIDTH-1) downto 0);
    end generate GEN_ECC_WR;

    -- *** BRAM Port B Output Signals ***

    GEN_PORT_B: if (C_SINGLE_PORT_BRAM = 0) generate
    begin

        BRAM_Rst_B <= not (S_AXI_ARESETN);
        BRAM_WE_B ((((C_S_AXI_DATA_WIDTH + C_ECC_FULL_BIT_WIDTH)/8) - 1) downto (C_ECC_FULL_BIT_WIDTH/8)) <= bram_we_b_int((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        BRAM_Addr_B <= bram_addr_b_int;
        BRAM_En_B <= bram_en_b_int;
        bram_rddata_b_int (C_S_AXI_DATA_WIDTH-1 downto 0) <= BRAM_RdData_B ((C_S_AXI_DATA_WIDTH + C_ECC_FULL_BIT_WIDTH - 1) downto (C_ECC_FULL_BIT_WIDTH));
        BRAM_WrData_B ((C_S_AXI_DATA_WIDTH + C_ECC_FULL_BIT_WIDTH - 1) downto (C_ECC_FULL_BIT_WIDTH)) <= bram_wrdata_b_int(C_S_AXI_DATA_WIDTH-1 downto 0);


        -- 13.3
        --  BRAM_WrData_B <= bram_wrdata_b_int;


        -- Added for 13.3
        -- Drive unused upper ECC bits to '0'
        -- For bram_block compatibility, must drive unused upper bits to '0' for ECC 128-bit use case.
        GEN_128_ECC_WR: if (C_S_AXI_DATA_WIDTH = 128) and (C_ECC = 1) generate
        begin
          BRAM_WrData_B ((C_ECC_FULL_BIT_WIDTH - 1) downto (C_ECC_WIDTH)) <= (others => '0');
          BRAM_WrData_B ((C_ECC_WIDTH-1) downto 0) <= bram_wrdata_b_int(C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto C_S_AXI_DATA_WIDTH);

          BRAM_WE_B ((C_ECC_FULL_BIT_WIDTH/8) - 1 downto 0) <= bram_we_b_int(((C_S_AXI_DATA_WIDTH+C_ECC_FULL_BIT_WIDTH)/8)-1 downto (C_S_AXI_DATA_WIDTH/8));

          bram_rddata_b_int (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto C_S_AXI_DATA_WIDTH) <= BRAM_RdData_B ((C_ECC_WIDTH-1) downto 0); 
        end generate GEN_128_ECC_WR;


        GEN_ECC_WR: if ( not (C_S_AXI_DATA_WIDTH = 128) and (C_ECC = 1)) generate
        begin
          BRAM_WrData_B ((C_ECC_WIDTH - 1) downto 0) <= bram_wrdata_b_int(C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto C_S_AXI_DATA_WIDTH);
  
          BRAM_WE_B ((C_ECC_FULL_BIT_WIDTH/8) - 1 downto 0) <= bram_we_b_int(((C_S_AXI_DATA_WIDTH+C_ECC_FULL_BIT_WIDTH)/8)-1 downto (C_S_AXI_DATA_WIDTH/8));

          bram_rddata_b_int (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto C_S_AXI_DATA_WIDTH) <= BRAM_RdData_B ((C_ECC_WIDTH-1) downto 0); 
        end generate GEN_ECC_WR;

    end generate GEN_PORT_B;


    GEN_NO_PORT_B: if (C_SINGLE_PORT_BRAM = 1) generate
    begin

        BRAM_Rst_B <= '0';
        BRAM_WE_B <= (others => '0');
        BRAM_WrData_B <= (others => '0');
        BRAM_Addr_B <= (others => '0');
        BRAM_En_B <= '0';

    end generate GEN_NO_PORT_B;



    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_BRAM_CLK_B
    -- Purpose:     Only drive BRAM_Clk_B when dual port BRAM is enabled.
    --
    ---------------------------------------------------------------------------

    GEN_BRAM_CLK_B: if (C_SINGLE_PORT_BRAM = 0) generate
    begin
        BRAM_Clk_B <= S_AXI_ACLK;
    end generate GEN_BRAM_CLK_B;


    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_NO_BRAM_CLK_B
    -- Purpose:     Drive default value for BRAM_Clk_B when single port
    --              BRAM is enabled and no clock is necessary on the inactive
    --              BRAM port.
    --
    ---------------------------------------------------------------------------

    GEN_NO_BRAM_CLK_B: if (C_SINGLE_PORT_BRAM = 1) generate
    begin
        BRAM_Clk_B <= '0';
    end generate GEN_NO_BRAM_CLK_B;





    ---------------------------------------------------------------------------



    -- Generate top level ARSIZE and AWSIZE signals for rd_chnl and wr_chnl
    -- respectively, based on design parameter setting of generic,
    -- C_S_AXI_SUPPORTS_NARROW_BURST.


    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_W_NARROW
    -- Purpose:     Create internal AWSIZE and ARSIZE signal for write and
    --              read channel modules based on top level AXI signal inputs.
    --
    ---------------------------------------------------------------------------

    GEN_W_NARROW: if (C_S_AXI_SUPPORTS_NARROW_BURST = 1) and (IF_IS_AXI4) generate
    begin

        axi_awsize_int <= S_AXI_AWSIZE;
        axi_arsize_int <= S_AXI_ARSIZE;


    end generate GEN_W_NARROW;


    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_WO_NARROW
    -- Purpose:     Create internal AWSIZE and ARSIZE signal for write and
    --              read channel modules based on hard coded
    --              value that indicates all AXI transfers will be equal in
    --              size to the AXI data bus.
    --
    ---------------------------------------------------------------------------

    GEN_WO_NARROW: if (C_S_AXI_SUPPORTS_NARROW_BURST = 0) or (IF_IS_AXI4LITE) generate
    begin

        -- axi_awsize_int <= AXI_FIXED_SIZE_WO_NARROW;     -- When AXI-LITE (no narrow transfers supported)
        -- axi_arsize_int <= AXI_FIXED_SIZE_WO_NARROW;

        -- v1.03a
        axi_awsize_int <= std_logic_vector (to_unsigned (AXI_FIXED_SIZE_WO_NARROW, 3));
        axi_arsize_int <= std_logic_vector (to_unsigned (AXI_FIXED_SIZE_WO_NARROW, 3));


    end generate GEN_WO_NARROW;






    S_AXI_ARREADY <= S_AXI_ARREADY_int;
    S_AXI_AWREADY <= S_AXI_AWREADY_int;




    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_AXI_LITE
    -- Purpose:     Create internal signals for lower level write and read
    --              channel modules to discard unused AXI signals when the
    --              AXI protocol is set up for AXI-LITE.
    --
    ---------------------------------------------------------------------------

    GEN_AXI4LITE: if (IF_IS_AXI4LITE) generate
    begin




        -- For simulation purposes ONLY
        -- AXI Interconnect handles this in real system topologies.
        S_AXI_BID <= S_AXI_BID_int;
        S_AXI_RID <= S_AXI_RID_int;


        -----------------------------------------------------------------------
        --
        -- Generate:    GEN_SIM_ONLY
        -- Purpose:     Mimic behavior of AXI Interconnect in simulation.
        --              In real hardware system, AXI Interconnect stores and
        --              wraps value of ARID to RID and AWID to BID.
        --
        -----------------------------------------------------------------------

        GEN_SIM_ONLY: if (C_SIM_ONLY = '1') generate
        begin


            -------------------------------------------------------------------

            -- Must register and wrap the AWID signal
            REG_BID: process (S_AXI_ACLK)
            begin

                if (S_AXI_ACLK'event and S_AXI_ACLK = '1') then

                    if (S_AXI_ARESETN = C_RESET_ACTIVE) then
                        S_AXI_BID_int <= (others => '0');

                    elsif (S_AXI_AWVALID = '1') and (S_AXI_AWREADY_int = '1') then
                        S_AXI_BID_int <= S_AXI_AWID;

                    else
                        S_AXI_BID_int <= S_AXI_BID_int;

                    end if;

                end if;

            end process REG_BID;


            -------------------------------------------------------------------

            -- Must register and wrap the ARID signal
            REG_RID: process (S_AXI_ACLK)
            begin

                if (S_AXI_ACLK'event and S_AXI_ACLK = '1') then

                    if (S_AXI_ARESETN = C_RESET_ACTIVE) then
                        S_AXI_RID_int <= (others => '0');

                    elsif (S_AXI_ARVALID = '1') and (S_AXI_ARREADY_int = '1') then
                        S_AXI_RID_int <= S_AXI_ARID;

                    else
                        S_AXI_RID_int <= S_AXI_RID_int;

                    end if;

                end if;

            end process REG_RID;


            -------------------------------------------------------------------



        end generate GEN_SIM_ONLY;




        ---------------------------------------------------------------------------
        --
        -- Generate:    GEN_HW
        -- Purpose:     Drive default values of RID and BID.  In real system
        --              these are left unconnected and AXI Interconnect is
        --              responsible for values.
        --
        ---------------------------------------------------------------------------

        GEN_HW: if (C_SIM_ONLY = '0') generate
        begin

            S_AXI_BID_int <= (others => '0');
            S_AXI_RID_int <= (others => '0');


        end generate GEN_HW;




        ---------------------------------------------------------------------------
        -- Instance:    I_AXI_LITE
        --
        -- Description:
        --              This module is for the AXI-Lite
        --              instantiation of the BRAM controller interface.
        --
        --              Responsible for shared address pipelining between the
        --              write address (AW) and read address (AR) channels.
        --              Controls (seperately) the data flows for the write data
        --              (W), write response (B), and read data (R) channels.
        --
        --              Creates a shared port to BRAM (for all read and write
        --              transactions) or dual BRAM port utilization based on a
        --              generic parameter setting.
        --
        --              Instantiates ECC register block if enabled and
        --              generates ECC logic, when enabled.
        --
        --
        ---------------------------------------------------------------------------

        I_AXI_LITE : entity work.axi_lite
        generic map (

            C_S_AXI_PROTOCOL                =>  C_S_AXI_PROTOCOL                ,
            C_S_AXI_DATA_WIDTH              =>  C_S_AXI_DATA_WIDTH              ,
            C_S_AXI_ADDR_WIDTH              =>  C_S_AXI_ADDR_WIDTH              ,
            C_SINGLE_PORT_BRAM              =>  C_SINGLE_PORT_BRAM              ,
            --  C_FAMILY                        =>  C_FAMILY                        ,

            C_S_AXI_CTRL_ADDR_WIDTH         =>  C_S_AXI_CTRL_ADDR_WIDTH         ,
            C_S_AXI_CTRL_DATA_WIDTH         =>  C_S_AXI_CTRL_DATA_WIDTH         ,

            C_ECC                           =>  C_ECC                           ,
            C_ECC_TYPE                      =>  C_ECC_TYPE                      ,   -- v1.03a
            C_ECC_WIDTH                     =>  C_ECC_WIDTH                     ,   -- 8-bits for ECC (32 & 64-bit data widths)
            C_ENABLE_AXI_CTRL_REG_IF        =>  C_ENABLE_AXI_CTRL_REG_IF_I      ,   -- Use internal constants determined by C_ECC
            C_FAULT_INJECT                  =>  C_FAULT_INJECT                ,
            C_CE_FAILING_REGISTERS          =>  C_CE_FAILING_REGISTERS_I        ,
            C_UE_FAILING_REGISTERS          =>  C_UE_FAILING_REGISTERS_I        ,
            C_ECC_STATUS_REGISTERS          =>  C_ECC_STATUS_REGISTERS_I        ,
            C_ECC_ONOFF_REGISTER            =>  C_ECC_ONOFF_REGISTER_I          ,
            C_ECC_ONOFF_RESET_VALUE         =>  C_ECC_ONOFF_RESET_VALUE         ,
            C_CE_COUNTER_WIDTH              =>  C_CE_COUNTER_WIDTH

        )
        port map (

            S_AXI_AClk              =>  S_AXI_ACLK          ,
            S_AXI_AResetn           =>  S_AXI_ARESETN       ,
            ECC_Interrupt           =>  ECC_Interrupt       ,
            ECC_UE                  =>  ECC_UE              ,

            AXI_AWADDR              =>  S_AXI_AWADDR        ,
            AXI_AWVALID             =>  S_AXI_AWVALID       ,
            AXI_AWREADY             =>  S_AXI_AWREADY_int   ,

            AXI_WDATA               =>  S_AXI_WDATA         ,
            AXI_WSTRB               =>  S_AXI_WSTRB         ,
            AXI_WVALID              =>  S_AXI_WVALID        ,
            AXI_WREADY              =>  S_AXI_WREADY        ,

            AXI_BRESP               =>  S_AXI_BRESP         ,
            AXI_BVALID              =>  S_AXI_BVALID        ,
            AXI_BREADY              =>  S_AXI_BREADY        ,

            AXI_ARADDR              =>  S_AXI_ARADDR        ,
            AXI_ARVALID             =>  S_AXI_ARVALID       ,
            AXI_ARREADY             =>  S_AXI_ARREADY_int   ,

            AXI_RDATA               =>  S_AXI_RDATA         ,
            AXI_RRESP               =>  S_AXI_RRESP         ,
            AXI_RLAST               =>  S_AXI_RLAST         ,
            AXI_RVALID              =>  S_AXI_RVALID        ,
            AXI_RREADY              =>  S_AXI_RREADY        ,


            -- Add AXI-Lite ECC Register Ports
            -- Note: AXI-Lite Control IF and AXI IF share the same clock.
            -- S_AXI_CTRL_ACLK         =>  S_AXI_CTRL_ACLK        ,
            -- S_AXI_CTRL_ARESETN      =>  S_AXI_CTRL_ARESETN     ,

            AXI_CTRL_AWVALID        =>  S_AXI_CTRL_AWVALID     ,
            AXI_CTRL_AWREADY        =>  S_AXI_CTRL_AWREADY     ,
            AXI_CTRL_AWADDR         =>  S_AXI_CTRL_AWADDR      ,

            AXI_CTRL_WDATA          =>  S_AXI_CTRL_WDATA       ,
            AXI_CTRL_WVALID         =>  S_AXI_CTRL_WVALID      ,
            AXI_CTRL_WREADY         =>  S_AXI_CTRL_WREADY      ,

            AXI_CTRL_BRESP          =>  S_AXI_CTRL_BRESP       ,
            AXI_CTRL_BVALID         =>  S_AXI_CTRL_BVALID      ,
            AXI_CTRL_BREADY         =>  S_AXI_CTRL_BREADY      ,

            AXI_CTRL_ARADDR         =>  S_AXI_CTRL_ARADDR      ,
            AXI_CTRL_ARVALID        =>  S_AXI_CTRL_ARVALID     ,
            AXI_CTRL_ARREADY        =>  S_AXI_CTRL_ARREADY     ,

            AXI_CTRL_RDATA          =>  S_AXI_CTRL_RDATA       ,
            AXI_CTRL_RRESP          =>  S_AXI_CTRL_RRESP       ,
            AXI_CTRL_RVALID         =>  S_AXI_CTRL_RVALID      ,
            AXI_CTRL_RREADY         =>  S_AXI_CTRL_RREADY      ,


            BRAM_En_A               =>  bram_en_a_int          ,
            BRAM_WE_A               =>  bram_we_a_int          ,
            BRAM_Addr_A             =>  bram_addr_a_int        ,
            BRAM_WrData_A           =>  bram_wrdata_a_int      ,
            BRAM_RdData_A           =>  bram_rddata_a_int      ,

            BRAM_En_B               =>  bram_en_b_int          ,
            BRAM_WE_B               =>  bram_we_b_int          ,
            BRAM_Addr_B             =>  bram_addr_b_int        ,
            BRAM_WrData_B           =>  bram_wrdata_b_int      ,
            BRAM_RdData_B           =>  bram_rddata_b_int


        );




    end generate GEN_AXI4LITE;








    ---------------------------------------------------------------------------
    --
    -- Generate:    GEN_AXI
    -- Purpose:     Only create internal signals for lower level write and read
    --              channel modules to assign AXI signals when the
    --              AXI protocol is set up for non AXI-LITE IF connections.
    --              For AXI4, all AXI signals are assigned to lower level modules.
    --
    --              For AXI-Lite connections, generate statement above will
    --              create default values on these signals (assigned here).
    --
    ---------------------------------------------------------------------------

    GEN_AXI4: if (IF_IS_AXI4) generate
    begin





        ---------------------------------------------------------------------------
        -- Instance: I_FULL_AXI
        --
        -- Description:
        --  Full AXI BRAM controller logic.
        --  Instantiates wr_chnl and rd_chnl modules.
        --  If enabled, ECC register interface is included.
        --
        ---------------------------------------------------------------------------

        I_FULL_AXI : entity work.full_axi
        generic map (

            C_S_AXI_ID_WIDTH                =>  C_S_AXI_ID_WIDTH                ,
            C_S_AXI_DATA_WIDTH              =>  C_S_AXI_DATA_WIDTH              ,
            C_S_AXI_ADDR_WIDTH              =>  C_S_AXI_ADDR_WIDTH              ,
            C_S_AXI_PROTOCOL                =>  C_S_AXI_PROTOCOL                ,
            C_SINGLE_PORT_BRAM              =>  C_SINGLE_PORT_BRAM              ,
            C_S_AXI_SUPPORTS_NARROW_BURST   =>  C_S_AXI_SUPPORTS_NARROW_BURST   ,

            C_S_AXI_CTRL_ADDR_WIDTH         =>  C_S_AXI_CTRL_ADDR_WIDTH         ,
            C_S_AXI_CTRL_DATA_WIDTH         =>  C_S_AXI_CTRL_DATA_WIDTH         ,

            C_ECC                           =>  C_ECC                           ,
            C_ECC_WIDTH                     =>  C_ECC_WIDTH                     ,   -- 8-bits for ECC (32 & 64-bit data widths)
            C_ECC_TYPE                      =>  C_ECC_TYPE                      ,   -- v1.03a
            C_FAULT_INJECT                  =>  C_FAULT_INJECT                  ,
            C_ECC_ONOFF_RESET_VALUE         =>  C_ECC_ONOFF_RESET_VALUE         ,

            C_ENABLE_AXI_CTRL_REG_IF        =>  C_ENABLE_AXI_CTRL_REG_IF_I      ,   -- Use internal constants determined by C_ECC
            C_CE_FAILING_REGISTERS          =>  C_CE_FAILING_REGISTERS_I        ,
            C_UE_FAILING_REGISTERS          =>  C_UE_FAILING_REGISTERS_I        ,
            C_ECC_STATUS_REGISTERS          =>  C_ECC_STATUS_REGISTERS_I        ,
            C_ECC_ONOFF_REGISTER            =>  C_ECC_ONOFF_REGISTER_I          ,
            C_CE_COUNTER_WIDTH              =>  C_CE_COUNTER_WIDTH

        )
        port map (

            S_AXI_AClk                  =>  S_AXI_ACLK          ,
            S_AXI_AResetn               =>  S_AXI_ARESETN       ,

            ECC_Interrupt               =>  ECC_Interrupt       ,
            ECC_UE                      =>  ECC_UE              ,

            S_AXI_AWID                  =>  S_AXI_AWID          ,
            S_AXI_AWADDR                =>  S_AXI_AWADDR(C_S_AXI_ADDR_WIDTH-1 downto 0),

            S_AXI_AWLEN                 =>  S_AXI_AWLEN         ,
            S_AXI_AWSIZE                =>  axi_awsize_int      ,
            S_AXI_AWBURST               =>  S_AXI_AWBURST       ,
            S_AXI_AWLOCK                =>  S_AXI_AWLOCK        ,
            S_AXI_AWCACHE               =>  S_AXI_AWCACHE       ,
            S_AXI_AWPROT                =>  S_AXI_AWPROT        ,
            S_AXI_AWVALID               =>  S_AXI_AWVALID       ,
            S_AXI_AWREADY               =>  S_AXI_AWREADY_int   ,

            S_AXI_WDATA                 =>  S_AXI_WDATA         ,
            S_AXI_WSTRB                 =>  S_AXI_WSTRB         ,
            S_AXI_WLAST                 =>  S_AXI_WLAST         ,
            S_AXI_WVALID                =>  S_AXI_WVALID        ,
            S_AXI_WREADY                =>  S_AXI_WREADY        ,

            S_AXI_BID                   =>  S_AXI_BID           ,
            S_AXI_BRESP                 =>  S_AXI_BRESP         ,
            S_AXI_BVALID                =>  S_AXI_BVALID        ,
            S_AXI_BREADY                =>  S_AXI_BREADY        ,


            S_AXI_ARID                  =>  S_AXI_ARID            ,
            S_AXI_ARADDR                =>  S_AXI_ARADDR(C_S_AXI_ADDR_WIDTH-1 downto 0),

            S_AXI_ARLEN                 =>  S_AXI_ARLEN           ,
            S_AXI_ARSIZE                =>  axi_arsize_int        ,
            S_AXI_ARBURST               =>  S_AXI_ARBURST         ,
            S_AXI_ARLOCK                =>  S_AXI_ARLOCK          ,
            S_AXI_ARCACHE               =>  S_AXI_ARCACHE         ,
            S_AXI_ARPROT                =>  S_AXI_ARPROT          ,
            S_AXI_ARVALID               =>  S_AXI_ARVALID         ,
            S_AXI_ARREADY               =>  S_AXI_ARREADY_int     ,

            S_AXI_RID                   =>  S_AXI_RID             ,
            S_AXI_RDATA                 =>  S_AXI_RDATA           ,
            S_AXI_RRESP                 =>  S_AXI_RRESP           ,
            S_AXI_RLAST                 =>  S_AXI_RLAST           ,
            S_AXI_RVALID                =>  S_AXI_RVALID          ,
            S_AXI_RREADY                =>  S_AXI_RREADY          ,


            -- Add AXI-Lite ECC Register Ports
            -- Note: AXI-Lite Control IF and AXI IF share the same clock.
            -- S_AXI_CTRL_ACLK             =>  S_AXI_CTRL_ACLK        ,
            -- S_AXI_CTRL_ARESETN          =>  S_AXI_CTRL_ARESETN     ,

            S_AXI_CTRL_AWVALID          =>  S_AXI_CTRL_AWVALID     ,
            S_AXI_CTRL_AWREADY          =>  S_AXI_CTRL_AWREADY     ,
            S_AXI_CTRL_AWADDR           =>  S_AXI_CTRL_AWADDR      ,

            S_AXI_CTRL_WDATA            =>  S_AXI_CTRL_WDATA       ,
            S_AXI_CTRL_WVALID           =>  S_AXI_CTRL_WVALID      ,
            S_AXI_CTRL_WREADY           =>  S_AXI_CTRL_WREADY      ,

            S_AXI_CTRL_BRESP            =>  S_AXI_CTRL_BRESP       ,
            S_AXI_CTRL_BVALID           =>  S_AXI_CTRL_BVALID      ,
            S_AXI_CTRL_BREADY           =>  S_AXI_CTRL_BREADY      ,

            S_AXI_CTRL_ARADDR           =>  S_AXI_CTRL_ARADDR      ,
            S_AXI_CTRL_ARVALID          =>  S_AXI_CTRL_ARVALID     ,
            S_AXI_CTRL_ARREADY          =>  S_AXI_CTRL_ARREADY     ,

            S_AXI_CTRL_RDATA            =>  S_AXI_CTRL_RDATA       ,
            S_AXI_CTRL_RRESP            =>  S_AXI_CTRL_RRESP       ,
            S_AXI_CTRL_RVALID           =>  S_AXI_CTRL_RVALID      ,
            S_AXI_CTRL_RREADY           =>  S_AXI_CTRL_RREADY      ,


            BRAM_En_A                   =>  bram_en_a_int          ,
            BRAM_WE_A                   =>  bram_we_a_int          ,
            BRAM_WrData_A               =>  bram_wrdata_a_int      ,
            BRAM_Addr_A                 =>  bram_addr_a_int        ,
            BRAM_RdData_A               =>  bram_rddata_a_int (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0) ,

            BRAM_En_B                   =>  bram_en_b_int          ,
            BRAM_WE_B                   =>  bram_we_b_int          ,
            BRAM_Addr_B                 =>  bram_addr_b_int        ,
            BRAM_WrData_B               =>  bram_wrdata_b_int      ,
            BRAM_RdData_B               =>  bram_rddata_b_int (C_S_AXI_DATA_WIDTH+C_ECC_WIDTH-1 downto 0)

        );




    -- v1.02a
    -- Seperate instantiations for wr_chnl and rd_chnl moved to
    -- full_axi module.



    end generate GEN_AXI4;





end architecture implementation;










-------------------------------------------------------------------------------
-- axi_bram_ctrl.vhd
-------------------------------------------------------------------------------
--
--
-- (c) Copyright [2010 - 2013] Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
--
--
-------------------------------------------------------------------------------
-- Filename:        axi_bram_ctrl_wrapper.vhd
--
-- Description:     This file is the top level module for the AXI BRAM
--                  controller IP core.
--
-- VHDL-Standard:   VHDL'93
--
-------------------------------------------------------------------------------
-- Structure:
--              axi_bram_ctrl.vhd (v4_0)
--                  |
--                  |--axi_bram_ctrl_top.vhd
--                         |
--                         |-- full_axi.vhd
--                         |   -- sng_port_arb.vhd
--                         |   -- lite_ecc_reg.vhd
--                         |       -- axi_lite_if.vhd
--                         |   -- wr_chnl.vhd
--                         |       -- wrap_brst.vhd
--                         |       -- ua_narrow.vhd
--                         |       -- checkbit_handler.vhd
--                         |           -- xor18.vhd
--                         |           -- parity.vhd
--                         |       -- checkbit_handler_64.vhd
--                         |           -- (same helper components as checkbit_handler)
--                         |       -- parity.vhd
--                         |       -- correct_one_bit.vhd
--                         |       -- correct_one_bit_64.vhd
--                         |       -- ecc_gen.vhd
--                         |
--                         |   -- rd_chnl.vhd
--                         |       -- wrap_brst.vhd
--                         |       -- ua_narrow.vhd
--                         |       -- checkbit_handler.vhd
--                         |           -- xor18.vhd
--                         |           -- parity.vhd
--                         |       -- checkbit_handler_64.vhd
--                         |           -- (same helper components as checkbit_handler)
--                         |       -- parity.vhd
--                         |       -- correct_one_bit.vhd
--                         |       -- correct_one_bit_64.vhd
--                         |       -- ecc_gen.vhd
--                         |
--                         |-- axi_lite.vhd
--                         |   -- lite_ecc_reg.vhd
--                         |       -- axi_lite_if.vhd
--                         |   -- checkbit_handler.vhd
--                         |       -- xor18.vhd
--                         |       -- parity.vhd
--                         |   -- correct_one_bit.vhd
--                         |   -- ecc_gen.vhd
--
-------------------------------------------------------------------------------
-- Library declarations

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.numeric_std.all;

library work;
use work.axi_bram_ctrl_top;
use work.axi_bram_ctrl_funcs.all;
--use work.coregen_comp_defs.all;
library blk_mem_gen_v8_3_4;
use blk_mem_gen_v8_3_4.all;

------------------------------------------------------------------------------

entity axi_bram_ctrl is
generic (

    C_BRAM_INST_MODE  : string := "EXTERNAL"; -- external ; internal
        --determines whether the bmg is external or internal to axi bram ctrl wrapper

    C_MEMORY_DEPTH  : integer := 4096;
        --Memory depth specified by the user

    C_BRAM_ADDR_WIDTH  : integer := 12;
        -- Width of AXI address bus (in bits)

    C_S_AXI_ADDR_WIDTH  : integer := 32;
        -- Width of AXI address bus (in bits)

    C_S_AXI_DATA_WIDTH  : integer := 32;
        -- Width of AXI data bus (in bits)

    C_S_AXI_ID_WIDTH : INTEGER := 4;
        --  AXI ID vector width

    C_S_AXI_PROTOCOL : string := "AXI4";
        -- Set to AXI4LITE to optimize out burst transaction support

    C_S_AXI_SUPPORTS_NARROW_BURST : INTEGER := 1;
        -- Support for narrow burst operations

    C_SINGLE_PORT_BRAM : INTEGER := 0;
        -- Enable single port usage of BRAM

     C_FAMILY : string := "virtex7";
        -- Specify the target architecture type
     C_SELECT_XPM : integer := 1;

    -- AXI-Lite Register Parameters

    C_S_AXI_CTRL_ADDR_WIDTH : integer := 32;
        -- Width of AXI-Lite address bus (in bits)

    C_S_AXI_CTRL_DATA_WIDTH  : integer := 32;
        -- Width of AXI-Lite data bus (in bits)

    -- ECC Parameters

    C_ECC : integer := 0;
        -- Enables or disables ECC functionality
    C_ECC_TYPE  : integer := 1;           

    C_FAULT_INJECT : integer := 0;
        -- Enable fault injection registers
        -- (default = disabled)

    C_ECC_ONOFF_RESET_VALUE : integer := 1
        -- By default, ECC checking is on
        -- (can disable ECC @ reset by setting this to 0)
       );
  port (
    -- AXI Interface Signals

    -- AXI Clock and Reset
    s_axi_aclk              : in    std_logic;
    s_axi_aresetn           : in    std_logic;

    ecc_interrupt           : out   std_logic := '0';
    ecc_ue                  : out   std_logic := '0';

    -- axi write address channel Signals (AW)
    s_axi_awid              : in    std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    s_axi_awaddr            : in    std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    s_axi_awlen             : in    std_logic_vector(7 downto 0);
    s_axi_awsize            : in    std_logic_vector(2 downto 0);
    s_axi_awburst           : in    std_logic_vector(1 downto 0);
    s_axi_awlock            : in    std_logic;
    s_axi_awcache           : in    std_logic_vector(3 downto 0);
    s_axi_awprot            : in    std_logic_vector(2 downto 0);
    s_axi_awvalid           : in    std_logic;
    s_axi_awready           : out   std_logic;

    -- axi write data channel Signals (W)
    s_axi_wdata             : in    std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    s_axi_wstrb             : in    std_logic_vector(C_S_AXI_DATA_WIDTH/8-1 downto 0);
    s_axi_wlast             : in    std_logic;

    s_axi_wvalid            : in    std_logic;
    s_axi_wready            : out   std_logic;

    -- axi write data response Channel Signals (B)
    s_axi_bid               : out   std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    s_axi_bresp             : out   std_logic_vector(1 downto 0);

    s_axi_bvalid            : out   std_logic;
    s_axi_bready            : in    std_logic;

    -- axi read address channel Signals (AR)
    s_axi_arid              : in    std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    s_axi_araddr            : in    std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    s_axi_arlen             : in    std_logic_vector(7 downto 0);
    s_axi_arsize            : in    std_logic_vector(2 downto 0);
    s_axi_arburst           : in    std_logic_vector(1 downto 0);
    s_axi_arlock            : in    std_logic;
    s_axi_arcache           : in    std_logic_vector(3 downto 0);
    s_axi_arprot            : in    std_logic_vector(2 downto 0);

    s_axi_arvalid           : in    std_logic;
    s_axi_arready           : out   std_logic;

    -- axi read data channel Signals (R)
    s_axi_rid               : out   std_logic_vector(C_S_AXI_ID_WIDTH-1 downto 0);
    s_axi_rdata             : out   std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    s_axi_rresp             : out   std_logic_vector(1 downto 0);
    s_axi_rlast             : out   std_logic;

    s_axi_rvalid            : out   std_logic;
    s_axi_rready            : in    std_logic;

    -- axi-lite ecc register Interface Signals

    -- axi-lite clock and Reset
    -- note: axi-lite control IF and AXI IF share the same clock.
    -- s_axi_ctrl_aclk             : in    std_logic;
    -- s_axi_ctrl_aresetn          : in    std_logic;

    -- axi-lite write address Channel Signals (AW)
    s_axi_ctrl_awvalid          : in    std_logic;
    s_axi_ctrl_awready          : out   std_logic;
    s_axi_ctrl_awaddr           : in    std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);

    -- axi-lite write data Channel Signals (W)
    s_axi_ctrl_wdata            : in    std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    s_axi_ctrl_wvalid           : in    std_logic;
    s_axi_ctrl_wready           : out   std_logic;

    -- axi-lite write data Response Channel Signals (B)
    s_axi_ctrl_bresp            : out   std_logic_vector(1 downto 0);
    s_axi_ctrl_bvalid           : out   std_logic;
    s_axi_ctrl_bready           : in    std_logic;

    -- axi-lite read address Channel Signals (AR)
    s_axi_ctrl_araddr           : in    std_logic_vector(C_S_AXI_CTRL_ADDR_WIDTH-1 downto 0);
    s_axi_ctrl_arvalid          : in    std_logic;
    s_axi_ctrl_arready          : out   std_logic;

    -- axi-lite read data Channel Signals (R)
    s_axi_ctrl_rdata             : out   std_logic_vector(C_S_AXI_CTRL_DATA_WIDTH-1 downto 0);
    s_axi_ctrl_rresp             : out   std_logic_vector(1 downto 0);
    s_axi_ctrl_rvalid            : out   std_logic;
    s_axi_ctrl_rready            : in    std_logic;

    -- bram interface signals (Port A)
    bram_rst_a              : out   std_logic;
    bram_clk_a              : out   std_logic;
    bram_en_a               : out   std_logic;
    bram_we_a               : out   std_logic_vector (C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);
    bram_addr_a             : out   std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0);
    bram_wrdata_a           : out   std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);
    bram_rddata_a           : in    std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);

    -- bram interface signals (Port B)
    bram_rst_b              : out   std_logic;
    bram_clk_b              : out   std_logic;
    bram_en_b               : out   std_logic;
    bram_we_b               : out   std_logic_vector (C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);
    bram_addr_b             : out   std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0);
    bram_wrdata_b           : out   std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);
    bram_rddata_b           : in    std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0)
    );

end entity axi_bram_ctrl;

-------------------------------------------------------------------------------
architecture implementation of axi_bram_ctrl is

attribute DowngradeIPIdentifiedWarnings: string;
attribute DowngradeIPIdentifiedWarnings of implementation : architecture is "yes";

component  xpm_memory_tdpram
  generic (
  MEMORY_SIZE         : integer := 4096*32;
  MEMORY_PRIMITIVE    : string  := "auto";
  CLOCKING_MODE       : string  := "common_clock";
  ECC_MODE            : string  := "no_ecc";
  MEMORY_INIT_FILE    : string  := "none";
  MEMORY_INIT_PARAM   : string  := "";
  WAKEUP_TIME         : string  := "disable_sleep";
  MESSAGE_CONTROL     : integer :=  0;

  WRITE_DATA_WIDTH_A  : integer := 32;
  READ_DATA_WIDTH_A   : integer := 32;
  BYTE_WRITE_WIDTH_A  : integer :=  8;
  ADDR_WIDTH_A        : integer := 12; 
  READ_RESET_VALUE_A  : string  := "0";
  READ_LATENCY_A      : integer :=  1;
  WRITE_MODE_A        : string  :=  "read_first";

  WRITE_DATA_WIDTH_B  : integer := 32;
  READ_DATA_WIDTH_B   : integer := 32;
  BYTE_WRITE_WIDTH_B  : integer :=  8;
  ADDR_WIDTH_B        : integer := 12;
  READ_RESET_VALUE_B  : string  := "0";
  READ_LATENCY_B      : integer :=  1;
  WRITE_MODE_B        : string  :=  "read_first"

); 
  port (

  -- Common module ports
   sleep              : in std_logic;

  -- Port A module ports
   clka               : in std_logic;
   rsta               : in std_logic;
   ena                : in std_logic;
   regcea             : in std_logic;
   wea                : in std_logic_vector (C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0');  -- (WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A)-1:0]
--   addra              : in std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
   addra              : in std_logic_vector (C_BRAM_ADDR_WIDTH-1 downto 0) := (others => '0');
   dina               : in std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0');  -- [WRITE_DATA_WIDTH_A-1:0] 
   injectsbiterra     : in std_logic;
   injectdbiterra     : in std_logic;
   douta              : out std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0); -- [READ_DATA_WIDTH_A-1:0]  
   sbiterra           : out std_logic;
   dbiterra           : out std_logic;

  -- Port B module ports
   clkb               : in std_logic;
   rstb               : in std_logic;
   enb                : in std_logic;
   regceb             : in std_logic;
   web                : in std_logic_vector (C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0');
--   addrb              : in std_logic_vector (C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');  -- [ADDR_WIDTH_B-1:0]   
   addrb              : in std_logic_vector (C_BRAM_ADDR_WIDTH-1 downto 0) := (others => '0');  -- [ADDR_WIDTH_B-1:0]   
   dinb               : in std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0'); 
   injectsbiterrb     : in std_logic;
   injectdbiterrb     : in std_logic;
   doutb              : out std_logic_vector (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0); -- [READ_DATA_WIDTH_B-1:0]  
   sbiterrb           : out std_logic;
   dbiterrb           : out std_logic
  );
end component;


  ------------------------------------------------------------------------------
  -- FUNCTION: if_then_else
  -- This function is used to implement an IF..THEN when such a statement is not
  --  allowed.
  ------------------------------------------------------------------------------
  FUNCTION if_then_else (
    condition : BOOLEAN;
    true_case : INTEGER;
    false_case : INTEGER)
  RETURN INTEGER IS
    VARIABLE retval : INTEGER := 0;
  BEGIN
    IF NOT condition THEN
      retval:=false_case;
    ELSE
      retval:=true_case;
    END IF;
    RETURN retval;
  END if_then_else;

  ---------------------------------------------------------------------------
  -- FUNCTION : log2roundup
  ---------------------------------------------------------------------------
  FUNCTION log2roundup (data_value : integer) RETURN integer IS
    VARIABLE width       : integer := 0;
    VARIABLE cnt         : integer := 1;
    CONSTANT lower_limit : integer := 1;
    CONSTANT upper_limit : integer := 8;
  BEGIN
    IF (data_value <= 1) THEN
      width   := 0;
    ELSE
      WHILE (cnt < data_value) LOOP
        width := width + 1;
        cnt   := cnt *2;
      END LOOP;
    END IF;
    RETURN width;
  END log2roundup;


-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

-- Only instantiate logic based on C_S_AXI_PROTOCOL.

-- Determine external ECC width.
-- Use function defined in axi_bram_ctrl_funcs package.

-- Set internal parameters for ECC register enabling when C_ECC = 1
                                                            -- Catastrophic error indicated with ECC_UE & Interrupt flags.

-- Counter only sized when C_ECC = 1.
-- Selects CE counter width/threshold to assert ECC_Interrupt
-- Hard coded at 8-bits to capture and count up to 256 correctable errors.

-- ECC algorithm format, 0 = Hamming code, 1 = Hsiao code

constant GND : std_logic := '0';
constant VCC : std_logic := '1';

constant ZERO1 : std_logic_vector(0 downto 0) := (others => '0');
constant ZERO2 : std_logic_vector(1 downto 0) := (others => '0');
constant ZERO3 : std_logic_vector(2 downto 0) := (others => '0');
constant ZERO4 : std_logic_vector(3 downto 0) := (others => '0');
constant ZERO8 : std_logic_vector(7 downto 0) := (others => '0');
constant WSTRB_ZERO : std_logic_vector(C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0');
constant ZERO16 : std_logic_vector(15 downto 0) := (others => '0');
constant ZERO32 : std_logic_vector(31 downto 0) := (others => '0');
constant ZERO64 : std_logic_vector(C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0');

CONSTANT MEM_TYPE : INTEGER := if_then_else((C_SINGLE_PORT_BRAM=1),0,2);
CONSTANT BWE_B : INTEGER := if_then_else((C_SINGLE_PORT_BRAM=1),0,1);
CONSTANT BMG_ADDR_WIDTH : INTEGER :=  log2roundup(C_MEMORY_DEPTH) + log2roundup(C_S_AXI_DATA_WIDTH/8) ;
-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------
signal clka_bram_clka_i      :  std_logic := '0';
signal rsta_bram_rsta_i      :  std_logic := '0';
signal ena_bram_ena_i        :  std_logic := '0';
signal REGCEA                :  std_logic := '0';
signal wea_bram_wea_i        :  std_logic_vector(C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0');
signal addra_bram_addra_i    :  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
signal dina_bram_dina_i      :  std_logic_vector(C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0');
signal douta_bram_douta_i    :  std_logic_vector(C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);

signal clkb_bram_clkb_i      :  std_logic := '0';
signal rstb_bram_rstb_i      :  std_logic := '0';
signal enb_bram_enb_i        :  std_logic := '0';
signal REGCEB                :  std_logic := '0';
signal web_bram_web_i        :  std_logic_vector(C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0');
signal addrb_bram_addrb_i    :  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
signal dinb_bram_dinb_i      :  std_logic_vector(C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0) := (others => '0');
signal doutb_bram_doutb_i    :  std_logic_vector(C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0);


-----------------------------------------------------------------------
-- Architecture Body
-----------------------------------------------------------------------

begin

gint_inst: IF (C_BRAM_INST_MODE = "INTERNAL" ) GENERATE

constant c_addrb_width    : INTEGER := log2roundup(C_MEMORY_DEPTH);
constant C_WEA_WIDTH_I    : INTEGER := (C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128))) ;
constant C_WRITE_WIDTH_A_I  : INTEGER := (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))) ;
constant C_READ_WIDTH_A_I : INTEGER := (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128)));
constant C_ADDRA_WIDTH_I  : INTEGER := log2roundup(C_MEMORY_DEPTH);
constant C_WEB_WIDTH_I     : INTEGER := (C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128)));
constant C_WRITE_WIDTH_B_I : INTEGER := (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128)));
constant C_READ_WIDTH_B_I  : INTEGER := (C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128)));

signal s_axi_rdaddrecc_bmg_int : STD_LOGIC_VECTOR(c_addrb_width-1 DOWNTO 0);
signal s_axi_dbiterr_bmg_int : STD_LOGIC;
signal s_axi_sbiterr_bmg_int : STD_LOGIC;
signal s_axi_rvalid_bmg_int : STD_LOGIC;
signal s_axi_rlast_bmg_int : STD_LOGIC;
signal s_axi_rresp_bmg_int : STD_LOGIC_VECTOR(1 DOWNTO 0);
signal s_axi_rdata_bmg_int : STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128))-1 downto 0); 
signal s_axi_rid_bmg_int : STD_LOGIC_VECTOR(3 DOWNTO 0);
signal s_axi_arready_bmg_int : STD_LOGIC;
signal s_axi_bvalid_bmg_int : STD_LOGIC;
signal s_axi_bresp_bmg_int : STD_LOGIC_VECTOR(1 DOWNTO 0);
signal s_axi_bid_bmg_int : STD_LOGIC_VECTOR(3 DOWNTO 0);
signal s_axi_wready_bmg_int : STD_LOGIC;
signal s_axi_awready_bmg_int : STD_LOGIC;
signal rdaddrecc_bmg_int : STD_LOGIC_VECTOR(c_addrb_width-1 DOWNTO 0);
signal dbiterr_bmg_int : STD_LOGIC;
signal sbiterr_bmg_int : STD_LOGIC;

begin

xpm_mem_gen : if (C_SELECT_XPM = 1) generate
xpm_memory_inst: xpm_memory_tdpram

   generic map (
      MEMORY_SIZE             => C_WRITE_WIDTH_A_I*C_MEMORY_DEPTH,
      MEMORY_PRIMITIVE        => "blockram",
      CLOCKING_MODE           => "common_clock",
      ECC_MODE                => "no_ecc",
      MEMORY_INIT_FILE        => "none",
      MEMORY_INIT_PARAM       => "",
      WAKEUP_TIME             => "disable_sleep",
      MESSAGE_CONTROL         =>  0,

      WRITE_DATA_WIDTH_A      =>  C_WRITE_WIDTH_A_I,
      READ_DATA_WIDTH_A       =>  C_READ_WIDTH_A_I,
      BYTE_WRITE_WIDTH_A      =>  8,
      ADDR_WIDTH_A            =>  C_ADDRA_WIDTH_I, 
      READ_RESET_VALUE_A      => "0",
      READ_LATENCY_A          =>  1,
      WRITE_MODE_A            => "write_first",  --write_first

      WRITE_DATA_WIDTH_B      => C_WRITE_WIDTH_B_I,
      READ_DATA_WIDTH_B       => C_READ_WIDTH_B_I,
      BYTE_WRITE_WIDTH_B      =>  8,
      ADDR_WIDTH_B            =>  C_ADDRB_WIDTH,
      READ_RESET_VALUE_B      => "0",
      READ_LATENCY_B          =>  1,
      WRITE_MODE_B            => "write_first"
      )
      port map (
       -- Common module ports
      sleep                   =>  GND,
    
     -- Port A module ports
      clka                    => clka_bram_clka_i,
      rsta                    => rsta_bram_rsta_i, 
      ena                     => ena_bram_ena_i, 
      regcea                  => GND,
      wea                     => wea_bram_wea_i,
      addra                   => addra_bram_addra_i(BMG_ADDR_WIDTH-1 downto (BMG_ADDR_WIDTH - C_BRAM_ADDR_WIDTH)),
      dina                    => dina_bram_dina_i,
      injectsbiterra          => GND,
      injectdbiterra          => GND,
      douta                   => douta_bram_douta_i,
      sbiterra                => open,
      dbiterra                => open,
    
     -- Port B module ports
      clkb                    => clkb_bram_clkb_i,
      rstb                    => rstb_bram_rstb_i,
      enb                     => enb_bram_enb_i,
      regceb                  => GND,
      web                     => web_bram_web_i,
      addrb                   => addrb_bram_addrb_i(BMG_ADDR_WIDTH-1 downto (BMG_ADDR_WIDTH - C_BRAM_ADDR_WIDTH)),
      dinb                    => dinb_bram_dinb_i,
      injectsbiterrb          => GND,
      injectdbiterrb          => GND,
      doutb                   => doutb_bram_doutb_i,
      sbiterrb                => open,
      dbiterrb                => open
      );
end generate;

blk_mem_gen : if (C_SELECT_XPM = 0) generate
bmgv81_inst : entity blk_mem_gen_v8_3_4.blk_mem_gen_v8_3_4

  GENERIC MAP(
  ----------------------------------------------------------------------------
  -- Generic Declarations
  ----------------------------------------------------------------------------
  --Device Family & Elaboration Directory Parameters:
    C_FAMILY                   => C_FAMILY,
    C_XDEVICEFAMILY            => C_FAMILY,
----    C_ELABORATION_DIR          => "NULL"                          ,
  
    C_INTERFACE_TYPE           => 0                           ,
  --General Memory Parameters:  
-----    C_ENABLE_32BIT_ADDRESS     => 0      ,
    C_MEM_TYPE                 => MEM_TYPE                  ,
    C_BYTE_SIZE                => 8                 ,
    C_ALGORITHM                => 1                 ,
    C_PRIM_TYPE                => 1                 ,
  
  --Memory Initialization Parameters:
    C_LOAD_INIT_FILE           => 0            ,
    C_INIT_FILE_NAME           => "no_coe_file_loaded"            ,
    C_USE_DEFAULT_DATA         => 0          ,
    C_DEFAULT_DATA             => "NULL"              ,
  
  --Port A Parameters:
    --Reset Parameters:
    C_HAS_RSTA                 => 0                  ,
  
    --Enable Parameters:
    C_HAS_ENA                  => 1                   ,
    C_HAS_REGCEA               => 0                ,
  
    --Byte Write Enable Parameters:
    C_USE_BYTE_WEA             => 1              ,
    C_WEA_WIDTH                => C_WEA_WIDTH_I, --(C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128)))                 ,
  
    --Write Mode:
    C_WRITE_MODE_A             => "WRITE_FIRST"              ,
  
    --Data-Addr Width Parameters:
    C_WRITE_WIDTH_A            => C_WRITE_WIDTH_A_I,--(C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128)))             ,
    C_READ_WIDTH_A             => C_READ_WIDTH_A_I,--(C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128)))              ,
    C_WRITE_DEPTH_A            => C_MEMORY_DEPTH             ,
    C_READ_DEPTH_A             => C_MEMORY_DEPTH             ,
    C_ADDRA_WIDTH              => C_ADDRA_WIDTH_I,--log2roundup(C_MEMORY_DEPTH)               ,
  
  --Port B Parameters:
    --Reset Parameters:
    C_HAS_RSTB                 => 0                  ,
  
    --Enable Parameters:
    C_HAS_ENB                  => 1                   ,
    C_HAS_REGCEB               => 0               ,
  
    --Byte Write Enable Parameters:
    C_USE_BYTE_WEB             => BWE_B              ,
    C_WEB_WIDTH                => C_WEB_WIDTH_I,--(C_S_AXI_DATA_WIDTH/8 + C_ECC*(1+(C_S_AXI_DATA_WIDTH/128)))                 ,
  
    --Write Mode:
    C_WRITE_MODE_B             => "WRITE_FIRST"              ,
  
    --Data-Addr Width Parameters:
    C_WRITE_WIDTH_B            => C_WRITE_WIDTH_B_I,--(C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128)))             ,
    C_READ_WIDTH_B             => C_READ_WIDTH_B_I,--(C_S_AXI_DATA_WIDTH+C_ECC*8*(1+(C_S_AXI_DATA_WIDTH/128)))              ,
    C_WRITE_DEPTH_B            => C_MEMORY_DEPTH             ,
    C_READ_DEPTH_B             => C_MEMORY_DEPTH              ,
    C_ADDRB_WIDTH              => C_ADDRB_WIDTH,--log2roundup(C_MEMORY_DEPTH)               ,
  
  --Output Registers/ Pipelining Parameters:
    C_HAS_MEM_OUTPUT_REGS_A    => 0     ,
    C_HAS_MEM_OUTPUT_REGS_B    => 0     ,
    C_HAS_MUX_OUTPUT_REGS_A    => 0     ,
    C_HAS_MUX_OUTPUT_REGS_B    => 0     ,
    C_MUX_PIPELINE_STAGES      => 0      ,

   --Input/Output Registers for SoftECC :
    C_HAS_SOFTECC_INPUT_REGS_A => 0  ,
    C_HAS_SOFTECC_OUTPUT_REGS_B=> 0 ,
  
  --ECC Parameters
    C_USE_ECC                  => 0                  ,
    C_USE_SOFTECC              => 0              ,
    C_HAS_INJECTERR            => 0             ,
    C_EN_ECC_PIPE              => 0,
	C_EN_SLEEP_PIN             => 0,
	C_USE_URAM                 => 0, 
	C_EN_RDADDRA_CHG           => 0,
	C_EN_RDADDRB_CHG           => 0,
	C_EN_DEEPSLEEP_PIN         => 0,
	C_EN_SHUTDOWN_PIN          => 0,  
  --Simulation Model Parameters:
    C_SIM_COLLISION_CHECK      => "NONE"       ,
    C_COMMON_CLK               => 1                ,
    C_DISABLE_WARN_BHV_COLL    => 1     ,
    C_DISABLE_WARN_BHV_RANGE   => 1    
  ) 
  PORT MAP(
  ----------------------------------------------------------------------------
  -- Input and Output Declarations
  ----------------------------------------------------------------------------
  -- Native BMG Input and Output Port Declarations
  --Port A:
    clka                            => clka_bram_clka_i               ,
    rsta                            => rsta_bram_rsta_i              ,
    ena                             => ena_bram_ena_i                ,
    regcea                          => GND                           ,
    wea                             => wea_bram_wea_i                ,
    addra                           => addra_bram_addra_i(BMG_ADDR_WIDTH-1 downto (BMG_ADDR_WIDTH - C_BRAM_ADDR_WIDTH))            ,
    --addra                           => addra_bram_addra_i(C_S_AXI_ADDR_WIDTH-1 downto (C_S_AXI_ADDR_WIDTH - C_BRAM_ADDR_WIDTH))            ,
    dina                            => dina_bram_dina_i              ,
    douta                           => douta_bram_douta_i            ,
  
  --port b:
    clkb                            => clkb_bram_clkb_i              ,
    rstb                            => rstb_bram_rstb_i              ,
    enb                             => enb_bram_enb_i                ,
    regceb                          => GND                           ,
    web                             => web_bram_web_i                ,
    addrb                           => addrb_bram_addrb_i(BMG_ADDR_WIDTH-1 downto (BMG_ADDR_WIDTH - C_BRAM_ADDR_WIDTH))            ,
    --addrb                           => addrb_bram_addrb_i(C_S_AXI_ADDR_WIDTH-1 downto (C_S_AXI_ADDR_WIDTH - C_BRAM_ADDR_WIDTH))            ,
    dinb                            => dinb_bram_dinb_i              ,
    doutb                           => doutb_bram_doutb_i            ,
  
  --ecc:
    injectsbiterr                   => GND                           ,
    injectdbiterr                   => GND                           ,
    sbiterr                         => sbiterr_bmg_int,
    dbiterr                         => dbiterr_bmg_int,
    rdaddrecc                       => rdaddrecc_bmg_int,
    eccpipece                       => GND,
	sleep                           => GND,
	deepsleep                       => GND,
	shutdown                        => GND,   
   -- axi bmg input and output Port Declarations

    -- axi global signals
    s_aclk                        => GND                             ,
    s_aresetn                     => GND                             ,

    -- axi full/lite slave write (write side)
    s_axi_awid                    => ZERO4                           ,
    s_axi_awaddr                  => ZERO32                          ,
    s_axi_awlen                   => ZERO8                           ,
    s_axi_awsize                  => ZERO3                           ,
    s_axi_awburst                 => ZERO2                           ,
    s_axi_awvalid                 => GND                             ,
    s_axi_awready                 => s_axi_awready_bmg_int,
    s_axi_wdata                   => ZERO64                          ,
    s_axi_wstrb                   => WSTRB_ZERO,
    s_axi_wlast                   => GND                             ,
    s_axi_wvalid                  => GND                             ,
    s_axi_wready                  => s_axi_wready_bmg_int,
    s_axi_bid                     => s_axi_bid_bmg_int,
    s_axi_bresp                   => s_axi_bresp_bmg_int,
    s_axi_bvalid                  => s_axi_bvalid_bmg_int,
    s_axi_bready                  => GND                             ,

    -- axi full/lite slave read (Write side)
    s_axi_arid                    => ZERO4,
    s_axi_araddr                  => "00000000000000000000000000000000",
    s_axi_arlen                   => "00000000",
    s_axi_arsize                  => "000",
    s_axi_arburst                 => "00",
    s_axi_arvalid                 => '0',
    s_axi_arready                 => s_axi_arready_bmg_int,
    s_axi_rid                     => s_axi_rid_bmg_int,
    s_axi_rdata                   => s_axi_rdata_bmg_int,
    s_axi_rresp                   => s_axi_rresp_bmg_int,
    s_axi_rlast                   => s_axi_rlast_bmg_int,
    s_axi_rvalid                  => s_axi_rvalid_bmg_int,
    s_axi_rready                  => GND                             ,

    -- axi full/lite sideband Signals
    s_axi_injectsbiterr           => GND                             ,
    s_axi_injectdbiterr           => GND                             ,
    s_axi_sbiterr                 => s_axi_sbiterr_bmg_int,
    s_axi_dbiterr                 => s_axi_dbiterr_bmg_int,
    s_axi_rdaddrecc               => s_axi_rdaddrecc_bmg_int
  );

end generate;

abcv4_0_int_inst : entity work.axi_bram_ctrl_top
generic map(

    -- AXI Parameters

    C_BRAM_ADDR_WIDTH  => C_BRAM_ADDR_WIDTH                        ,

    C_S_AXI_ADDR_WIDTH  => C_S_AXI_ADDR_WIDTH                        ,
        -- Width of AXI address bus (in bits)

    C_S_AXI_DATA_WIDTH  => C_S_AXI_DATA_WIDTH                        ,
        -- Width of AXI data bus (in bits)

    C_S_AXI_ID_WIDTH    => C_S_AXI_ID_WIDTH                                ,
        --  AXI ID vector width

    C_S_AXI_PROTOCOL    => C_S_AXI_PROTOCOL                          ,
        -- Set to AXI4LITE to optimize out burst transaction support

    C_S_AXI_SUPPORTS_NARROW_BURST => C_S_AXI_SUPPORTS_NARROW_BURST   ,
        -- Support for narrow burst operations

    C_SINGLE_PORT_BRAM  => C_SINGLE_PORT_BRAM                        ,
        -- Enable single port usage of BRAM

    -- AXI-Lite Register Parameters
    C_S_AXI_CTRL_ADDR_WIDTH  => C_S_AXI_CTRL_ADDR_WIDTH              ,
        -- Width of AXI-Lite address bus (in bits)

    C_S_AXI_CTRL_DATA_WIDTH  => C_S_AXI_CTRL_DATA_WIDTH              ,
        -- Width of AXI-Lite data bus (in bits)

    -- ECC Parameters

    C_ECC => C_ECC                                                   ,
        -- Enables or disables ECC functionality
    C_ECC_TYPE                      =>  C_ECC_TYPE                      ,   

    C_FAULT_INJECT => C_FAULT_INJECT                                 ,
        -- Enable fault injection registers
        -- (default = disabled)

    C_ECC_ONOFF_RESET_VALUE => C_ECC_ONOFF_RESET_VALUE               
        -- By default, ECC checking is on
        -- (can disable ECC @ reset by setting this to 0)
       )
  port map(

    -- AXI Interface Signals

    -- AXI Clock and Reset
    S_AXI_ACLK              => S_AXI_ACLK                            ,
    S_AXI_ARESETN           => S_AXI_ARESETN                         ,

    ECC_Interrupt           => ECC_Interrupt                         ,
    ECC_UE                  => ECC_UE                                ,

    -- AXI Write Address Channel Signals (AW)
    S_AXI_AWID              => S_AXI_AWID                            ,
    S_AXI_AWADDR            => S_AXI_AWADDR                          ,
    S_AXI_AWLEN             => S_AXI_AWLEN                           ,
    S_AXI_AWSIZE            => S_AXI_AWSIZE                          , 
    S_AXI_AWBURST           => S_AXI_AWBURST                         ,
    S_AXI_AWLOCK            => S_AXI_AWLOCK                          , 
    S_AXI_AWCACHE           => S_AXI_AWCACHE                         ,
    S_AXI_AWPROT            => S_AXI_AWPROT                          ,
    S_AXI_AWVALID           => S_AXI_AWVALID                         ,
    S_AXI_AWREADY           => S_AXI_AWREADY                         ,

    -- AXI Write Data Channel Signals (W)
    S_AXI_WDATA             => S_AXI_WDATA                           ,
    S_AXI_WSTRB             => S_AXI_WSTRB                           ,
    S_AXI_WLAST             => S_AXI_WLAST                           ,

    S_AXI_WVALID            => S_AXI_WVALID                          ,
    S_AXI_WREADY            => S_AXI_WREADY                          ,

    -- AXI Write Data Response Channel Signals (B)
    S_AXI_BID               => S_AXI_BID                             ,
    S_AXI_BRESP             => S_AXI_BRESP                           ,

    S_AXI_BVALID            => S_AXI_BVALID                          ,
    S_AXI_BREADY            => S_AXI_BREADY                          ,

    -- AXI Read Address Channel Signals (AR)
    S_AXI_ARID              => S_AXI_ARID                            ,
    S_AXI_ARADDR            => S_AXI_ARADDR                          ,
    S_AXI_ARLEN             => S_AXI_ARLEN                           ,
    S_AXI_ARSIZE            => S_AXI_ARSIZE                          ,
    S_AXI_ARBURST           => S_AXI_ARBURST                         ,
    S_AXI_ARLOCK            => S_AXI_ARLOCK                          ,
    S_AXI_ARCACHE           => S_AXI_ARCACHE                         ,
    S_AXI_ARPROT            => S_AXI_ARPROT                          ,

    S_AXI_ARVALID           => S_AXI_ARVALID                         ,
    S_AXI_ARREADY           => S_AXI_ARREADY                         ,

    -- AXI Read Data Channel Signals (R)
    S_AXI_RID               => S_AXI_RID                             ,
    S_AXI_RDATA             => S_AXI_RDATA                           ,
    S_AXI_RRESP             => S_AXI_RRESP                           ,
    S_AXI_RLAST             => S_AXI_RLAST                           ,

    S_AXI_RVALID            => S_AXI_RVALID                          ,
    S_AXI_RREADY            => S_AXI_RREADY                          ,

    -- AXI-Lite ECC Register Interface Signals

    -- AXI-Lite Write Address Channel Signals (AW)
    S_AXI_CTRL_AWVALID          => S_AXI_CTRL_AWVALID                ,
    S_AXI_CTRL_AWREADY          => S_AXI_CTRL_AWREADY                ,
    S_AXI_CTRL_AWADDR           => S_AXI_CTRL_AWADDR                 ,

    -- AXI-Lite Write Data Channel Signals (W)
    S_AXI_CTRL_WDATA            => S_AXI_CTRL_WDATA                  ,
    S_AXI_CTRL_WVALID           => S_AXI_CTRL_WVALID                 ,
    S_AXI_CTRL_WREADY           => S_AXI_CTRL_WREADY                 ,

    -- AXI-Lite Write Data Response Channel Signals (B)
    S_AXI_CTRL_BRESP            => S_AXI_CTRL_BRESP                  ,
    S_AXI_CTRL_BVALID           => S_AXI_CTRL_BVALID                 ,
    S_AXI_CTRL_BREADY           => S_AXI_CTRL_BREADY                 ,

    -- AXI-Lite Read Address Channel Signals (AR)
    S_AXI_CTRL_ARADDR           => S_AXI_CTRL_ARADDR                 ,
    S_AXI_CTRL_ARVALID          => S_AXI_CTRL_ARVALID                ,
    S_AXI_CTRL_ARREADY          => S_AXI_CTRL_ARREADY                ,

    -- AXI-Lite Read Data Channel Signals (R)
    S_AXI_CTRL_RDATA             => S_AXI_CTRL_RDATA                 ,
    S_AXI_CTRL_RRESP             => S_AXI_CTRL_RRESP                 ,
    S_AXI_CTRL_RVALID            => S_AXI_CTRL_RVALID                ,
    S_AXI_CTRL_RREADY            => S_AXI_CTRL_RREADY                ,

    -- BRAM Interface Signals (Port A)
    BRAM_Rst_A              => rsta_bram_rsta_i                      ,
    BRAM_Clk_A              => clka_bram_clka_i                      ,
    BRAM_En_A               => ena_bram_ena_i                        ,
    BRAM_WE_A               => wea_bram_wea_i                        ,
    BRAM_Addr_A             => addra_bram_addra_i,
    BRAM_WrData_A           => dina_bram_dina_i                      ,
    BRAM_RdData_A           => douta_bram_douta_i                    ,

    -- BRAM Interface Signals (Port B)
    BRAM_Rst_B              => rstb_bram_rstb_i                      ,
    BRAM_Clk_B              => clkb_bram_clkb_i                      ,
    BRAM_En_B               => enb_bram_enb_i                        ,
    BRAM_WE_B               => web_bram_web_i                        ,
    BRAM_Addr_B             => addrb_bram_addrb_i                    ,
    BRAM_WrData_B           => dinb_bram_dinb_i                      ,
    BRAM_RdData_B           => doutb_bram_doutb_i                    
    );
-- The following signals are driven 0's to remove the synthesis warnings
    bram_rst_a              <= '0';
    bram_clk_a              <= '0';
    bram_en_a               <= '0';
    bram_we_a               <= (others => '0');
    bram_addr_a             <= (others => '0');
    bram_wrdata_a           <= (others => '0');

    bram_rst_b              <= '0';
    bram_clk_b              <= '0'; 
    bram_en_b               <= '0';
    bram_we_b               <= (others => '0');
    bram_addr_b             <= (others => '0');
    bram_wrdata_b           <= (others => '0');


  END GENERATE gint_inst; -- End of internal bram instance 


gext_inst: IF (C_BRAM_INST_MODE = "EXTERNAL" ) GENERATE

abcv4_0_ext_inst : entity work.axi_bram_ctrl_top
generic map(

    -- AXI Parameters

    C_BRAM_ADDR_WIDTH  => C_BRAM_ADDR_WIDTH                        ,

    C_S_AXI_ADDR_WIDTH  => C_S_AXI_ADDR_WIDTH                        ,
        -- Width of AXI address bus (in bits)

    C_S_AXI_DATA_WIDTH  => C_S_AXI_DATA_WIDTH                        ,
        -- Width of AXI data bus (in bits)

    C_S_AXI_ID_WIDTH    => C_S_AXI_ID_WIDTH                                ,
        --  AXI ID vector width

    C_S_AXI_PROTOCOL    => C_S_AXI_PROTOCOL                          ,
        -- Set to AXI4LITE to optimize out burst transaction support

    C_S_AXI_SUPPORTS_NARROW_BURST => C_S_AXI_SUPPORTS_NARROW_BURST   ,
        -- Support for narrow burst operations

    C_SINGLE_PORT_BRAM  => C_SINGLE_PORT_BRAM                        ,
        -- Enable single port usage of BRAM

    -- AXI-Lite Register Parameters
    C_S_AXI_CTRL_ADDR_WIDTH  => C_S_AXI_CTRL_ADDR_WIDTH              ,
        -- Width of AXI-Lite address bus (in bits)

    C_S_AXI_CTRL_DATA_WIDTH  => C_S_AXI_CTRL_DATA_WIDTH              ,
        -- Width of AXI-Lite data bus (in bits)

    -- ECC Parameters

    C_ECC => C_ECC                                                   ,
        -- Enables or disables ECC functionality
    C_ECC_TYPE                      =>  C_ECC_TYPE                      ,   

    C_FAULT_INJECT => C_FAULT_INJECT                                 ,
        -- Enable fault injection registers
        -- (default = disabled)

    C_ECC_ONOFF_RESET_VALUE => C_ECC_ONOFF_RESET_VALUE               
        -- By default, ECC checking is on
        -- (can disable ECC @ reset by setting this to 0)
       )
  port map(

    -- AXI Interface Signals

    -- AXI Clock and Reset
    s_axi_aclk              => s_axi_aclk                            ,
    s_axi_aresetn           => s_axi_aresetn                         ,

    ecc_interrupt           => ecc_interrupt                         ,
    ecc_ue                  => ecc_ue                                ,

    -- axi write address channel signals (aw)
    s_axi_awid              => s_axi_awid                            ,
    s_axi_awaddr            => s_axi_awaddr                          ,
    s_axi_awlen             => s_axi_awlen                           ,
    s_axi_awsize            => s_axi_awsize                          , 
    s_axi_awburst           => s_axi_awburst                         ,
    s_axi_awlock            => s_axi_awlock                          , 
    s_axi_awcache           => s_axi_awcache                         ,
    s_axi_awprot            => s_axi_awprot                          ,
    s_axi_awvalid           => s_axi_awvalid                         ,
    s_axi_awready           => s_axi_awready                         ,

    -- axi write data channel signals (w)
    s_axi_wdata             => s_axi_wdata                           ,
    s_axi_wstrb             => s_axi_wstrb                           ,
    s_axi_wlast             => s_axi_wlast                           ,

    s_axi_wvalid            => s_axi_wvalid                          ,
    s_axi_wready            => s_axi_wready                          ,

    -- axi write data response channel signals (b)
    s_axi_bid               => s_axi_bid                             ,
    s_axi_bresp             => s_axi_bresp                           ,

    s_axi_bvalid            => s_axi_bvalid                          ,
    s_axi_bready            => s_axi_bready                          ,

    -- axi read address channel signals (ar)
    s_axi_arid              => s_axi_arid                            ,
    s_axi_araddr            => s_axi_araddr                          ,
    s_axi_arlen             => s_axi_arlen                           ,
    s_axi_arsize            => s_axi_arsize                          ,
    s_axi_arburst           => s_axi_arburst                         ,
    s_axi_arlock            => s_axi_arlock                          ,
    s_axi_arcache           => s_axi_arcache                         ,
    s_axi_arprot            => s_axi_arprot                          ,

    s_axi_arvalid           => s_axi_arvalid                         ,
    s_axi_arready           => s_axi_arready                         ,

    -- axi read data channel signals (r)
    s_axi_rid               => s_axi_rid                             ,
    s_axi_rdata             => s_axi_rdata                           ,
    s_axi_rresp             => s_axi_rresp                           ,
    s_axi_rlast             => s_axi_rlast                           ,

    s_axi_rvalid            => s_axi_rvalid                          ,
    s_axi_rready            => s_axi_rready                          ,

    -- axi-lite ecc register interface signals

    -- axi-lite write address channel signals (aw)
    s_axi_ctrl_awvalid          => s_axi_ctrl_awvalid                ,
    s_axi_ctrl_awready          => s_axi_ctrl_awready                ,
    s_axi_ctrl_awaddr           => s_axi_ctrl_awaddr                 ,

    -- axi-lite write data channel signals (w)
    s_axi_ctrl_wdata            => s_axi_ctrl_wdata                  ,
    s_axi_ctrl_wvalid           => s_axi_ctrl_wvalid                 ,
    s_axi_ctrl_wready           => s_axi_ctrl_wready                 ,

    -- axi-lite write data response channel signals (b)
    s_axi_ctrl_bresp            => s_axi_ctrl_bresp                  ,
    s_axi_ctrl_bvalid           => s_axi_ctrl_bvalid                 ,
    s_axi_ctrl_bready           => s_axi_ctrl_bready                 ,

    -- axi-lite read address channel signals (ar)
    s_axi_ctrl_araddr           => s_axi_ctrl_araddr                 ,
    s_axi_ctrl_arvalid          => s_axi_ctrl_arvalid                ,
    s_axi_ctrl_arready          => s_axi_ctrl_arready                ,

    -- axi-lite read data channel signals (r)
    s_axi_ctrl_rdata             => s_axi_ctrl_rdata                 ,
    s_axi_ctrl_rresp             => s_axi_ctrl_rresp                 ,
    s_axi_ctrl_rvalid            => s_axi_ctrl_rvalid                ,
    s_axi_ctrl_rready            => s_axi_ctrl_rready                ,

    -- bram interface signals (port a)
    bram_rst_a                   => bram_rst_a                       ,
    bram_clk_a                   => bram_clk_a                       ,
    bram_en_a                    => bram_en_a                        ,
    bram_we_a                    => bram_we_a                        ,
    bram_addr_a                  => bram_addr_a                      ,
    bram_wrdata_a                => bram_wrdata_a                    ,
    bram_rddata_a                => bram_rddata_a                    ,

    -- bram interface signals (port b)
    bram_rst_b                   => bram_rst_b                       ,
    bram_clk_b                   => bram_clk_b                       ,
    bram_en_b                    => bram_en_b                        ,
    bram_we_b                    => bram_we_b                        ,
    bram_addr_b                  => bram_addr_b                      ,
    bram_wrdata_b                => bram_wrdata_b                    ,
    bram_rddata_b                => bram_rddata_b                    
    );
  END GENERATE gext_inst; -- End of internal bram instance 

end architecture implementation;



