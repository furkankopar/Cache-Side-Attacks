-- Ameer Shalabi

-- FSM for safty check for cache.
-- comments will show the meaning of each line.
-- this is a mealy FSM

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity SI_FSM_logic is
	generic (
		CACHE_SETS			: positive	:= 256;		--	The number of sets in the cache
		INDEX_BITS			: positive	:= 1;		--	N bits used as index bits in the cache address
		OFFSET_BITS			: positive	:= 1;		--	N bits used as offset bits in the cache address
		CPU_ADDR_BITS		: positive	:= 1;		--	N bit in the cache address
		process_ID_len		: positive 	:= 2		--	Number of bits used to identify a process (procID)
	);
	port (
		clk					:	in std_logic;		--	system clock
		rst					:	in std_logic;		--	system reset 
		--	cache hit and miss indicators
		cache_H				:	in std_logic;
		cache_M				:	in std_logic;
		--	cache address
		cpu_addr		:	in unsigned(CPU_ADDR_BITS-1 downto 0);
		---	current process perfroming access to the cache
		process_ID			:	in std_logic_vector(process_ID_len-1 downto 0);
		---	process we want to secure
		safe_process_ID		:	in std_logic_vector(process_ID_len-1 downto 0);
		--- safe (0) vs unsafe (1)
		safety				:	out std_logic --- 0 is safe , 1 is unsafe
	);
end entity SI_FSM_logic;

architecture rtl of SI_FSM_logic is
type states is (s0,s1,s2,s3,s4,s5);
signal	addr_index		: 	unsigned(INDEX_BITS-1 downto 0);
signal	prev_addr_reg		: 	unsigned(CPU_ADDR_BITS-1 downto 0);

signal	different_index	: 	boolean;
signal	curState		:	states;
signal	nextState		:	states;
signal  safety_stt 		:   std_logic;

signal  cache_HM 		:   std_logic;
signal	reg_safe_count	: 	std_logic_vector(63 downto 0);
signal	reg_index_count	: 	std_logic_vector(63 downto 0);

type STATE_MEM is array (CACHE_SETS - 1 downto 0) of states;
signal	FSM_mem			: STATE_MEM;

begin
---------------------------------------------------------------------------------------------
--	Extract the address index from the address.												|
--		The index is used to store the state of the set where this index is located			|
--		then the state is read to resume the FSM. Additionally, the address index signal	|
--		is used to detect changes on the index-bits input to evaluate the 					|
---------------------------------------------------------------------------------------------
addr_index <= cpu_addr(OFFSET_BITS+INDEX_BITS-1 downto OFFSET_BITS);

---------------------------------------------------------------------------------------------
--	init_stt: Initial state process															|
--		The reset of the FSM in a for loop (mem_rst) using the rst input. FSM is reset to s0|
--		where all the start states begin for each location.									|
--		At the falling edge of the clk, the next state of the FSM is stored in the memory	|
--		at location addr_index.																|
---------------------------------------------------------------------------------------------
init_stt : process(clk,rst)
begin
	if(rst='1') then
		mem_rst : for i in 0 to (CACHE_SETS - 1) loop
			FSM_mem(i)	<=	s0; --reset all the mem to s0 (start state)
		end loop mem_rst;
	elsif(falling_edge(clk)) then
		FSM_mem(to_integer(addr_index)) <= nextState; -- store next state 
  end if;
end process init_stt;

---------------------------------------------------------------------------------------------
--	NEWINDEX_proc: Process to read the state of FSM for location index						|
--		This is primarily is used to read the content of memory and retrieve the stored 	|
--		state of the FSM for the new index.													|
---------------------------------------------------------------------------------------------
NEWINDEX_proc : process(cpu_addr)
begin
	curState	<=	FSM_mem(to_integer(cpu_addr(OFFSET_BITS+INDEX_BITS-1 downto OFFSET_BITS)));
end process NEWINDEX_proc;

---------------------------------------------------------------------------------------------
--	index_REG_proc: Process to detect changes on the address input							|
--		This is primarily is used to detect any changes on the address input. This helps	|
--		determining when a transition on the FSM is needed. This avoids additional unwanted |
--		transition when the cache_HM (in the HM_proc) changes during the same access.		|
--		This is possible when a miss occurs that the cache reports the miss, however, when	|
--		the miss is mitigated, the cache reports a hit before the access is finished. This	|
--		change of miss/hit signals can cause transitions that are unwanted.	This process	|
--		esures that only at the first clk cycle of an access that transitions occur in the 	|
-- 		FSM.																				|
---------------------------------------------------------------------------------------------
index_REG_proc : process(clk, rst)
	begin
		if (rst = '1') then
			prev_addr_reg	<= (others => '0');
		elsif (clk'event and clk = '1') then
			prev_addr_reg <= cpu_addr;
		end if;
end process index_REG_proc;


---------------------------------------------------------------------------------------------
--	Marking the first clk cycle of an access												|
--		Compring the signals from the the address input and the index_REG_proc.				|
---------------------------------------------------------------------------------------------
different_index <= false when prev_addr_reg = cpu_addr else true;

---------------------------------------------------------------------------------------------
--	HM_proc: Process to detect changes on the hit and miss inputs							|
--		Only when a hit occurs that a hit is reported, otherwise, a miss is assumed.		|
---------------------------------------------------------------------------------------------

HM_proc : process(cache_H,cache_M)
begin
	
	if(cache_H='1' and cache_M='0') then
		cache_HM		<= '1';
	elsif(cache_M='1'and cache_H='0') then
		cache_HM		<= '0';
	else 
		cache_HM <= '0';
	end if;
end process HM_proc;



-- checks the ID of the process then makes a descision.
-- perhaps a better approach is by defining the range of the safe process
-- this will help define which is a safe and none safe process without having
-- to define the process itself.

FSM_comb : process(process_ID,safe_process_ID,cache_HM,curState,different_index)
	begin
		safety_stt <= '0';
		case (curState) is
			when s0 =>
				if (process_ID = safe_process_ID) then
					if (different_index and (cache_HM = '1' or cache_HM = '0')) then
						nextState <= s1;
						safety_stt <= '0';
						--FSM_TRANSITION <= "S0SE";
					end if;
				else
					if (different_index and (cache_HM = '1' or cache_HM = '0')) then
						nextState <= s2;
						safety_stt <= '0';
						--FSM_TRANSITION <= "S0IE";
					end if;
				end if;

			-- ======= S1
			when s1 =>
				if (process_ID = safe_process_ID) then								-- S
					if (different_index and cache_HM = '0') then 					-- miss
						safety_stt <= '1';
						nextState <= s1;
						--FSM_TRANSITION <= "S1SM";
					elsif (different_index and cache_HM = '1') then 				-- hit
						safety_stt <= '0';
						nextState <= s3;
						--FSM_TRANSITION <= "S1SH";
					end if;
				else																-- I
					if (different_index and cache_HM = '0') then					-- miss
						safety_stt <= '0';
						nextState <= s5;
						--FSM_TRANSITION <= "S1IM";
					elsif (different_index and cache_HM = '1') then					-- hit
						safety_stt <= '0';
						nextState <= s4;
						--FSM_TRANSITION <= "S1IH";
					end if;
				end if;


			-- ======= S2
			when s2 =>
				if (process_ID = safe_process_ID) then 								-- S
					if (different_index and cache_HM = '0' ) then 					-- miss
						safety_stt <= '1';
						nextState <= s1;
						--FSM_TRANSITION <= "S2SM";
					elsif (different_index and cache_HM = '1') then 				-- hit
						safety_stt <= '0';
						nextState <= s1;
						--FSM_TRANSITION <= "S2SH";
					end if;
				else																-- I
					if (different_index and cache_HM = '0') then					-- miss
						safety_stt <= '0';
						nextState <= s5;
						--FSM_TRANSITION <= "S2IM";
					elsif (different_index and cache_HM = '1') then					-- hit
						safety_stt <= '0';
						nextState <= s4;

						--FSM_TRANSITION <= "S2IH";
					end if;
				end if;

			-- ======= S3
			when s3 =>
				if (process_ID = safe_process_ID) then 								-- S
					if (different_index and cache_HM = '0' ) then 					-- miss
						safety_stt <= '1';
						nextState <= s1;
						--FSM_TRANSITION <= "S3SM";
					elsif (different_index and cache_HM = '1') then 				-- hit
						safety_stt <= '0';
						nextState <= s1;
						--FSM_TRANSITION <= "S3SH";
					end if;
				else																-- I
					if (different_index and cache_HM = '0' ) then					-- miss
						safety_stt <= '1';
						nextState <= s2;
						--FSM_TRANSITION <= "S3IM";
					elsif (different_index and cache_HM = '1') then					-- hit
						safety_stt <= '0';
						nextState <= s2;
						--FSM_TRANSITION <= "S3IH";
					end if;
				end if;

			-- ======= S4
			when s4 =>
				if (process_ID = safe_process_ID) then								-- S
					if (different_index and cache_HM = '0' ) then					-- miss
						safety_stt <= '1';
						nextState <= s1;
						--FSM_TRANSITION <= "S4SM";
					elsif (different_index and cache_HM = '1') then					-- hit
						safety_stt <= '0';
						nextState <= s1;
						--FSM_TRANSITION <= "S4SH";
					end if;
				else																-- I
					if (different_index and cache_HM = '0') then					-- miss
						safety_stt <= '0';
						nextState <= s2;
						--FSM_TRANSITION <= "S4IM";
					elsif (different_index and cache_HM = '1') then					-- hit
						safety_stt <= '0';
						nextState <= s2;
						--FSM_TRANSITION <= "S4IH";
					end if;
				end if;

			-- ======= S5
			when s5 =>
				if (process_ID = safe_process_ID) then 								-- S
					if (different_index and cache_HM = '0' ) then 					-- miss
						safety_stt <= '1';
						nextState <= s1;
						--FSM_TRANSITION <= "S5SM";
					elsif (different_index and cache_HM = '1' ) then 				-- hit
						safety_stt <= '1';
						nextState <= s1;
						--FSM_TRANSITION <= "S5SH";
					end if;
				else																-- I
					if (different_index and cache_HM = '0') then					-- miss
						safety_stt <= '0';
						nextState <= s2;
						--FSM_TRANSITION <= "S5IH";
					elsif (different_index and cache_HM = '1') then					-- hit
						safety_stt <= '0';
						nextState <= s2;
						--FSM_TRANSITION <= "S5IH";
					end if;
				end if;

		end case;

end process FSM_comb;

---------------------------------------------------------------------------------------------
--	safeCOUNT_proc: Counters																|
--		reg_safe_count counts the number of unsafe accesses									|
--		reg_index_count counts the number of accesses										|
---------------------------------------------------------------------------------------------

safeCOUNT_proc : process(clk,rst)
begin
	if (rst = '1') then
		reg_safe_count	<=	(others => '0');
	elsif (falling_edge(clk) and safety_stt = '1') then
		reg_safe_count	<=	reg_safe_count + 1;
	end if;

	if (rst = '1') then
		reg_index_count	<=	(others => '0');
	elsif (falling_edge(clk) and different_index) then
		reg_index_count	<=	reg_index_count + 1;
	end if;
end process safeCOUNT_proc;

---------------------------------------------------------------------------------------------
--	safety latch																			|
--		used to maitain the safety output until the end of an access, will be removed later.|
---------------------------------------------------------------------------------------------
safety <= safety_stt when different_index;
end rtl;