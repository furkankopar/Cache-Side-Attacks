----------------------------------------------------------------------------------
-- Company: Tallinn University of Technology
-- Engineer: Furkan Kopar
-- 
-- Create Date: 07/20/2020 02:11:36 PM
-- Design Name: Cache Side Channel Timing Attack Detector with Mealy Machine
-- Module Name: SI_FSM_tb - Testbench
-- Project Name: Attack Detector
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity SI_FSM_tb is
--  Port ( );
end SI_FSM_tb;

architecture Testbench of SI_FSM_tb is

component SI_FSM
    Generic ( CACHE_SETS     : positive	:= 256;   -- The number of sets in the cache
		      INDEX_BITS     : positive	:= 8;	  -- N bits used as index bits in the cache address
		      OFFSET_BITS    : positive	:= 5;	  -- N bits used as offset bits in the cache address
		      CPU_ADDR_BITS	 : positive	:= 32;	  -- N bit in the cache address
		      PROCESS_ID_LEN : positive := 2      -- Number of bits used to identify a process (procID)
		      );
    Port ( clk			   : in  std_logic;   -- System clock
		   rst		   	   : in  std_logic;	  -- System reset 
		   -- Cache hit and miss indicators
		   cache_H		   : in  std_logic;
		   cache_M		   : in  std_logic;
		   cpu_addr		   : in  unsigned (CPU_ADDR_BITS - 1 downto 0);            -- Cache address
		   process_ID	   : in  std_logic_vector (PROCESS_ID_LEN - 1 downto 0);   -- Current process perfroming access to the cache
		   safe_process_ID : in  std_logic_vector (PROCESS_ID_LEN - 1 downto 0);   -- Process to be secured
		   safety	   	   : out std_logic                                         -- Safe = 0, Unsafe = 1
           );
end component;

constant CACHE_SETS_tb     : positive := 256;   -- The number of sets in the cache
constant INDEX_BITS_tb     : positive := 8;	    -- N bits used as index bits in the cache address
constant OFFSET_BITS_tb    : positive := 5;	    -- N bits used as offset bits in the cache address
constant CPU_ADDR_BITS_tb  : positive := 32;	-- N bit in the cache address
constant PROCESS_ID_LEN_tb : positive := 1;     -- Number of bits used to identify a process (procID)

-- Testing cache addresses
constant S0SET33OFF0 : unsigned := x"5555_4660";
constant S0SET33OFF1 : unsigned := x"5555_4670";
constant S1SET33OFF0 : unsigned := x"5555_C660";
constant S1SET33OFF1 : unsigned := x"5555_C670";

constant S0SETDDOFF0 : unsigned := x"5555_5BA0";
constant S0SETDDOFF1 : unsigned := x"5555_5BB0";
constant S1SETDDOFF0 : unsigned := x"5555_DBA0";
constant S1SETDDOFF1 : unsigned := x"5555_DBB0";

constant I0SET33OFF0 : unsigned := x"AAAA_A660";
constant I0SET33OFF1 : unsigned := x"AAAA_A670";
constant I1SET33OFF0 : unsigned := x"AAAB_A660";
constant I1SET33OFF1 : unsigned := x"AAAB_A670";

constant I0SETDDOFF0 : unsigned := x"AAAA_BBA0";
constant I0SETDDOFF1 : unsigned := x"AAAA_BBB0";
constant I1SETDDOFF0 : unsigned := x"AAAB_BBA0";
constant I1SETDDOFF1 : unsigned := x"AAAB_BBB0";

signal clk_tb			  : std_logic := '0';   -- System clock
signal rst_tb		   	  : std_logic;	        -- System reset 
-- Cache hit and miss indicators
signal cache_H_tb		  : std_logic;
signal cache_M_tb		  : std_logic;
signal cpu_addr_tb		  : unsigned (CPU_ADDR_BITS_tb - 1 downto 0);            -- Cache address
signal process_ID_tb	  : std_logic_vector (PROCESS_ID_LEN_tb - 1 downto 0);   -- Current process perfroming access to the cache
signal safe_process_ID_tb : std_logic_vector (PROCESS_ID_LEN_tb - 1 downto 0);   -- Process to be secured
signal safety_tb   	      : std_logic;                                           -- Safe = 0, Unsafe = 1

begin

    uut: SI_FSM 
        Generic map ( CACHE_SETS     => CACHE_SETS_tb,
                      INDEX_BITS     => INDEX_BITS_tb,
                      OFFSET_BITS    => OFFSET_BITS_tb,
                      CPU_ADDR_BITS  => CPU_ADDR_BITS_tb,
                      PROCESS_ID_LEN => PROCESS_ID_LEN_tb)
        Port map ( clk             => clk_tb,
                   rst             => rst_tb,
                   cache_H         => cache_H_tb,
                   cache_M         => cache_M_tb,
                   cpu_addr        => cpu_addr_tb,
                   process_ID      => process_ID_tb,
                   safe_process_ID => safe_process_ID_tb,
                   safety          => safety_tb);
    
    clk_tb <= NOT clk_tb after 5 ns;
                   
    stimulus: process
    begin
        -- Reset, the system starts at S0
        rst_tb             <= '1';
        cache_H_tb         <= '0';
        cache_M_tb         <= '1';
        cpu_addr_tb        <= S0SET33OFF0;
        process_ID_tb      <= "0";
        safe_process_ID_tb <= "0";
        wait for 10 ns;                      -- Time: 10ns, State: S0
        
        -- Since the same address is used, the state stays at S0
        rst_tb     <= '0';
        wait for 20 ns;                      -- Time: 30ns, Next State: S0
        
        cpu_addr_tb <= S0SET33OFF1;          -- S & H
        cache_M_tb  <= '0';
        wait for 10 ns;                      -- Time: 40ns, Next State: S1
        
        cpu_addr_tb <= S0SET33OFF0;          -- S & H
        wait for 10 ns;                      -- Time: 50ns, Next State: S2
        
        cpu_addr_tb <= S0SET33OFF1;          -- S & H
        wait for 10 ns;                      -- Time: 60ns, Next State: S1, Safe
        
        cpu_addr_tb <= S0SET33OFF0;          -- S & H
        wait for 10 ns;                      -- Time: 70ns, Next State: S2
        
        cpu_addr_tb   <= I0SET33OFF0;        -- I & H
        process_ID_tb <= "1";
        wait for 10 ns;                      -- Time: 80ns, Next State: S1, Safe
        
        cpu_addr_tb   <= S0SET33OFF0;        -- S & H
        process_ID_tb <= "0";
        wait for 10 ns;                      -- Time: 90ns, Next State: S2
        
        cpu_addr_tb <= S1SET33OFF0;          -- S & M
        cache_M_tb  <= '1';
        wait for 10 ns;                      -- Time: 100ns, Next State: S1, Unsafe
        
        cpu_addr_tb <= S1SET33OFF1;          -- S & H
        cache_M_tb  <= '0';
        wait for 10 ns;                      -- Time: 110ns, Next State: S2
        
        -- A different set is accessed, therefore a different FSM is triggered
        safe_process_ID_tb <= "1";
        cpu_addr_tb        <= I0SETDDOFF0;   -- I & M
        cache_M_tb         <= '1';
        wait for 10 ns;                      -- Time: 120ns, Next State: S1
        
        safe_process_ID_tb <= "0";
        cpu_addr_tb        <= I0SET33OFF0;   -- I & M
        process_ID_tb      <= "1";
        wait for 10 ns;                      -- Time: 130ns, Next State: S1, Unsafe
        
        cpu_addr_tb <= I0SET33OFF0;          -- I & M
        wait for 10 ns;                      -- Time: 140ns, Next State: S3
        
        cpu_addr_tb   <= S0SET33OFF0;        -- S & H
        process_ID_tb <= "0";
        cache_M_tb    <= '0';
        wait for 10 ns;                      -- Time: 150ns, Next State: S1, Safe
        
        cpu_addr_tb   <= I0SET33OFF0;        -- I & M
        process_ID_tb <= "1";
        cache_M_tb    <= '1';
        wait for 10 ns;                      -- Time: 160ns, Next State: S3
        
        cpu_addr_tb <= I0SET33OFF1;          -- I & H
        cache_M_tb  <= '0';
        wait for 10 ns;                      -- Time: 170ns, Next State: S1, Safe
        
        cpu_addr_tb <= I1SET33OFF0;          -- I & M
        cache_M_tb  <= '1';
        wait for 10 ns;                      -- Time: 180ns, Next State: S3
        
        cpu_addr_tb   <= S0SET33OFF0;        -- S & M
        process_ID_tb <= "0";
        wait for 10 ns;                      -- Time: 190ns, Next State: S1, Unsafe
        
        cpu_addr_tb   <= I0SET33OFF0;        -- I & M
        process_ID_tb <= "1";
        wait for 10 ns;                      -- Time: 200ns, Next State: S3
        
        cpu_addr_tb <= I1SET33OFF0;          -- I & M
        wait for 10 ns;                      -- Time: 210ns, Next State: S1, Safe
        
        cpu_addr_tb <= I1SET33OFF1;          -- I & H
        cache_M_tb  <= '0';
        wait for 10 ns;                      -- Time: 220ns, Next State: S3
        
        cpu_addr_tb   <= S0SET33OFF0;        -- S & H
        process_ID_tb <= "0";
        wait for 10 ns;                      -- Time: 230ns, Next State: S1, Safe
        
        cpu_addr_tb   <= I1SET33OFF0;        -- I & H
        process_ID_tb <= "1";
        wait for 10 ns;                      -- Time: 240ns, Next State: S3
        
        cpu_addr_tb <= I1SET33OFF1;          -- I & H
        wait for 10 ns;                      -- Time: 250ns, Next State: S1, Safe
        
        cpu_addr_tb <= I1SET33OFF0;          -- I & H
        wait for 10 ns;                      -- Time: 260ns, Next State: S3
        
        cpu_addr_tb   <= S0SET33OFF0;        -- S & M
        process_ID_tb <= "0";
        cache_M_tb    <= '1';
        wait for 10 ns;                      -- Time: 270ns, Next State: S1, Unsafe
        
        cpu_addr_tb   <= I0SET33OFF0;        -- I & H
        process_ID_tb <= "1";
        cache_M_tb    <= '0';
        wait for 10 ns;                      -- Time: 280ns, Next State: S3
        
        cpu_addr_tb <= I1SET33OFF0;          -- I & M
        cache_M_tb  <= '1';
        wait for 10 ns;                      -- Time: 290ns, Next State: S1, Safe
        
        cpu_addr_tb   <= S0SET33OFF0;        -- S & M
        process_ID_tb <= "0";
        cache_M_tb    <= '1';
        wait for 10 ns;                      -- Time: 300ns, Next State: S1, Unsafe
        
        cpu_addr_tb   <= S1SET33OFF0;        -- S & M
        wait for 10 ns;                      -- Time: 310ns, Next State: S1, Unsafe
        
        cpu_addr_tb <= S1SET33OFF1;          -- S & H
        cache_M_tb  <= '0';
        wait for 10 ns;                      -- Time: 320ns, Next State: S2
        
        safe_process_ID_tb <= "1";
        cpu_addr_tb        <= S0SETDDOFF0;   -- S & M
        process_ID_tb      <= "1";
        cache_M_tb         <= '1';
        wait for 20 ns;                      -- Time: 340ns, Next State: S1, Unsafe
        
        safe_process_ID_tb <= "0";
        cpu_addr_tb        <= I0SET33OFF0;   -- I & M
        wait for 10 ns;                      -- Time: 350ns, Next State: S1, Unsafe
        
        safe_process_ID_tb <= "1";
        cpu_addr_tb        <= S0SETDDOFF0;   -- S & H
        cache_M_tb         <= '0';
        wait for 10 ns;                      -- Time: 360ns, Next State: S2
        
        cpu_addr_tb   <= I0SETDDOFF0;        -- I & H
        process_ID_tb <= "0";
        wait for 10 ns;                      -- Time: 370ns, Next State: S1
        
        wait;
        
    end process;

end Testbench;
