----------------------------------------------------------------------------------
-- Company: Tallinn University of Technology
-- Engineer: Ameer Shalabi, Furkan Kopar
-- 
-- Create Date: 07/31/2020 07:15:19 PM
-- Design Name: A Mealy FSM for cache safety check
-- Module Name: SI_FSM - RTL
-- Project Name: 
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

entity SI_FSM is
			Generic 
			(	
				CACHE_SETS		: POSITIVE		:= 4;		-- The number of sets in the cache
				INDEX_BITS		: POSITIVE		:= 2;		-- N bits used as index bits in the cache address
				OFFSET_BITS		: POSITIVE		:= 2;		-- N bits used as offset bits in the cache address
				CPU_ADDR_BITS	: POSITIVE		:= 8;	-- N bit in the cache address
				PROCESS_ID_LEN	: POSITIVE		:= 1 		-- Number of bits used to identify a process (procID)
			);	
			
			Port 
			(
				clk				: in	STD_LOGIC;		-- System clock
				rst				: in	STD_LOGIC;		-- System reset 
				-- Cache hit and miss indicators
				cache_H			: in	STD_LOGIC;		-- Cache hit signal
				cache_M			: in	STD_LOGIC;		-- Cache miss signal
				-- Cache read and write indicators
				cache_OP		: in	STD_LOGIC;
				-- Cache address
				cpu_addr		: in	UNSIGNED(CPU_ADDR_BITS - 1 downto 0);
				-- Current process perfroming access to the cache
				process_ID		: in	STD_LOGIC_VECTOR(PROCESS_ID_LEN - 1 downto 0);
				-- Process to be secured
				safe_process_ID	: in	STD_LOGIC_VECTOR(PROCESS_ID_LEN - 1 downto 0);
				-- Safe: 0, Unsafe: 1
				safety			: out	STD_LOGIC
			);
end SI_FSM;

architecture RTL of SI_FSM is

-- FSM states
type states is (s0, s1, s2, s3);
signal curState, nextState : states;

-- FSM memory
type STATE_MEM is array (CACHE_SETS - 1 downto 0) of states;
signal FSM_mem : STATE_MEM;

signal addr_index				: unsigned(INDEX_BITS - 1 downto 0);
signal prev_addr_reg			: unsigned(CPU_ADDR_BITS - 1 downto 0);
signal different_index			: std_logic;
signal safety_stt				: std_logic;
signal cache_HM					: std_logic;
signal safeProcess				: boolean;

-- Counters
signal reg_safe_count			: unsigned(63 downto 0);		-- count the occurrences of unsafe states
signal reg_safeProc_count		: unsigned(63 downto 0);	-- count the occurrences of unsafe states during a run of safe proc
signal reg_index_count			: unsigned(63 downto 0);		-- count the number of accesses that where evaluataed by the FSM

begin

	---------------------------------------------------------------------------------------------
	--	Extract the address index from the address.												|
	--	The index is used to store the state of the set where this index is located.			|
	--	Then, the state is read to resume the FSM.												|
	--	Additionally, the address index signal is used to detect changes on the index-bits		|
	--	 input to evaluate the array index to be used for the FSM computation.					|
	---------------------------------------------------------------------------------------------
	addr_index <= cpu_addr(OFFSET_BITS + INDEX_BITS - 1 downto OFFSET_BITS);

	---------------------------------------------------------------------------------------------
	--	state_memory: Initial state process														|
	--	The reset of the FSM in a for loop (mem_rst) using the rst input.						|
	--	FSM is reset to s0 where all the start states begin for each location.					|
	--	At the falling edge of the clock, the next state of the FSM is stored in the memory at	|
	--		location addr_index.																|
	---------------------------------------------------------------------------------------------
	state_memory : process (clk, rst)
	begin
		if rst = '1' then
			mem_rst : for i in 0 to CACHE_SETS - 1 loop
				FSM_mem(i) <= s0;	 -- Reset all the memory to s0 (start state)
			end loop mem_rst;
		elsif falling_edge(clk) and different_index = '1' then
			FSM_mem(to_integer(addr_index)) <= nextState;	 -- Store the next state 
		end if;
	end process state_memory;
	
	---------------------------------------------------------------------------------------------
	--	state_register: Process to read the state of FSM for location index						|
	--	This is primarily used to read the content of memory and retrieve the stored state of	|
	--	 the FSM for the new index.																|
	---------------------------------------------------------------------------------------------
	state_register : process (cpu_addr)
	begin
		curState <= FSM_mem(to_integer(cpu_addr(OFFSET_BITS + INDEX_BITS - 1 downto OFFSET_BITS)));
	end process state_register;
	
	---------------------------------------------------------------------------------------------
	--	address_register: Process to detect changes on the address input						|
	--	This is primarily used to detect any changes on the address input.						|
	--	This helps determining when a transition on the FSM is needed.							|
	--	This avoids additional unwanted transition when the cache_HM (in the HM_proc) changes	|
	--	 during the same access.																|
	--	This is possible when a miss occurs that the cache reports the miss, however, when		|
	--	 the miss is mitigated, the cache reports a hit before the access is finished.			|
	--	This change of miss/hit signals can cause transitions that are unwanted.				|
	--	This process ensures that only at the first clock cycle of an access that transitions	|
	--	 occur in the FSM.																		|
	---------------------------------------------------------------------------------------------
	address_register : process (clk, rst)
	begin
		if rst = '1' then
			prev_addr_reg <= (others => '0');
		elsif rising_edge(clk) then
			prev_addr_reg <= cpu_addr;
		end if;
	end process address_register;
	
	---------------------------------------------------------------------------------------------
	--	Marking the first clk cycle of an access by comparing the signals from the the address	|
	--	 input and the index_REG_proc.															|
	---------------------------------------------------------------------------------------------
	different_index <= '0' when prev_addr_reg = cpu_addr or cache_OP = '1'
							 else '1';
							 
	---------------------------------------------------------------------------------------------
	--	Only when a miss occurs that a miss is reported.										|
	---------------------------------------------------------------------------------------------
	cache_HM <= '0' when cache_M = '1' AND cache_H = '0' and different_index = '1' else
				'1' when cache_M = '0' AND cache_H = '1' and different_index = '1' else
				'-';
	
	---------------------------------------------------------------------------------------------
	--	output: Checks the ID of the process then makes a descision.							|
	--	Perhaps a better approach is by defining the range of the safe process.					|
	--	This will help define which is a safe and unsafe process without having to define the	|
	--	 process itself.																		|
	---------------------------------------------------------------------------------------------
	
	safeProcess <= true when process_ID = safe_process_ID else false;

	output : process (safeProcess,process_ID, safe_process_ID, cache_HM, curState)
	begin

			nextState <= s0;	--	all transitions are to the initital state, unless otherwise decided by the FSM
			case curState is
				when s0 =>		--	initial state
					--	A cache hit or miss, regardless of the type of the proc (safe or not)
					--	transitions from s0 are always to s1
                    safety_stt <= '0';
					if cache_HM = '0' or cache_HM= '1' then nextState	<= s1; end if;
					--	Regardless, all transition out of this state is safe.
					
				when s1 =>		--	second stage
					safety_stt <= '0';
                    if safeProcess then
						if cache_HM = '0' then  nextState	 <= s2; end if;
                        if cache_HM = '1' then  nextState    <= s3; end if; 
					else														 -- I
						if cache_HM = '0' or cache_HM= '1' then nextState	<= s3; end if;
					end if;
				when s2 =>		--	first of the two third stage transitions
					nextState	<= s0;
					if (safeProcess AND (cache_HM = '1' or cache_HM = '0')) or (not safeProcess AND cache_HM = '1') then       -- SM || H
                        safety_stt <= '1';
                    end if;
				when s3 =>		--	second of the two third stage transitions
					nextState	<= s0;
					if safeProcess AND cache_HM = '0' then	safety_stt <= '1'; end if; -- SM
			end case;

	end process output;
	
	---------------------------------------------------------------------------------------------
	--	safety_register: Counters																|
	--	reg_safe_count counts the number of unsafe accesses.									|
	--	reg_index_count counts the number of accesses.											|
	---------------------------------------------------------------------------------------------
	
	safety_register : process (clk, rst)
	begin
		
		if rst = '1' then
			reg_safe_count <= (others => '0');
		elsif clk'event then
			safety <= safety_stt;
		end if;

		if rst = '1' then
			reg_safeProc_count <= (others => '0');
		elsif falling_edge(clk) and safeProcess AND different_index = '1' and safety_stt = '1' then
			reg_safeProc_count <= reg_safeProc_count + 1;
		end if;

		if rst = '1' then
			reg_safe_count <= (others => '0');
		elsif falling_edge(clk) AND different_index = '1' and safety_stt = '1' then
			reg_safe_count <= reg_safe_count + 1;
		end if;
		
		if rst = '1' then
			reg_index_count <= (others => '0');
		elsif falling_edge(clk) AND different_index = '1' then
			reg_index_count <= reg_index_count + 1;
		end if;
	end process safety_register;
	
	---------------------------------------------------------------------------------------------
	--	Safety latch is used to maitain the safety output until the end of an access,			|
	--	 will be removed later.																	|
	---------------------------------------------------------------------------------------------
	--safety <= safety_stt when different_index; --

end RTL;