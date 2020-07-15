----------------------------------------------------------------------------------
-- Company: Tallinn University of Technology
-- Engineer: Furkan Kopar
-- 
-- Create Date: 07/13/2020 05:33:01 PM
-- Design Name: Cache Side Channel Timing Attack Detector with Mealy Machine
-- Module Name: attack_detector - mealy_design
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

-- The inputs of the system are the reset, processor ID and the cache behavior
-- Loop  = infinite flow                   - rst = 0
-- Reset = turning back to the start state - rst = 1
-- Processor ID; S = security critical process - proc = 0
--               I = intruder process          - proc = 1
-- Cache Behavior; H = hit  - hit_miss = 0
--                 M = miss - hit_miss = 1
-- The output of the system is the safety indicator of the state
-- Safe   = no attack can occur - unsafe = 0
-- Unsafe = an attack may occur - unsafe = 1

entity attack_detector is
    Port ( rst      : in  STD_LOGIC;
           proc     : in  STD_LOGIC;
           hit_miss : in  STD_LOGIC;
           clk      : in  STD_LOGIC;
           unsafe   : out STD_LOGIC);
end attack_detector;

architecture mealy_design of attack_detector is

type state is (start, s1, s2, s3, s4, s5);
signal present_state, next_state : state;

begin

    state_register: process (clk, rst)
    begin    
        if rst = '1' then
            present_state <= start;
        elsif rising_edge(clk) then
            present_state <= next_state;
        end if;
    end process;
    
    output: process (present_state, proc, hit_miss)
    begin
        case present_state is
            when s1 =>
                if ((NOT proc) AND hit_miss) = '1' then
                    unsafe <= '1';
                else
                    unsafe <= '0';
                end if;
            when s2 =>
                if ((NOT proc) AND hit_miss) = '1' then
                    unsafe <= '1';
                else
                    unsafe <= '0';
                end if;
            when s3 =>
                if hit_miss = '1' then
                    unsafe <= '1';
                else
                    unsafe <= '0';
                end if;
            when s4 =>
                if ((NOT proc) AND hit_miss) = '1' then
                    unsafe <= '1';
                else
                    unsafe <= '0';
                end if;
            when s5 =>
                if proc = '1' then
                    unsafe <= '0';
                else
                    unsafe <= '1';
                end if;
            when others =>
                unsafe <= '0';
        end case;  
    end process;
    
    next_st: process (present_state, proc, hit_miss)
    begin
        case present_state is
            when start =>
                if proc = '1' then
                    next_state <= s2;
                else
                    next_state <= s1;
                end if;
            when s1 =>
                if proc = '1' then
                    if hit_miss = '1' then
                        next_state <= s5;
                    else
                        next_state <= s4;
                    end if;
                else
                    if hit_miss = '1' then
                        next_state <= s1;
                    else
                        next_state <= s3;
                    end if;
                end if;
            when s2 =>
                if proc = '1' then
                    if hit_miss = '1' then
                        next_state <= s5;
                    else
                        next_state <= s4;
                    end if;
                else
                    next_state <= s1;
                end if;
            when s3 | s4 | s5 =>
                if proc = '1' then
                    next_state <= s2;
                else
                    next_state <= s1;
                end if;
            when others =>
                next_state <= start;
        end case;
    end process;

end mealy_design;
