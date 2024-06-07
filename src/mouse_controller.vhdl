library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity mouse_controller is
    port (
        CLOCK2_50, reset : in std_logic;
        left_button, right_button : out std_logic;
        cursor_row, cursor_column : out std_logic_vector(9 downto 0);
        PS2_CLK, PS2_DAT : inout std_logic
    );
end entity;

architecture behaviour of mouse_controller is
    signal clock_25Mhz : std_logic := '0';

    component mouse is
        PORT( clock_25Mhz, reset 		: IN std_logic;
         mouse_data					: INOUT std_logic;
         mouse_clk 					: INOUT std_logic;
         left_button, right_button	: OUT std_logic;
		 mouse_cursor_row 			: OUT std_logic_vector(9 DOWNTO 0); 
		 mouse_cursor_column 		: OUT std_logic_vector(9 DOWNTO 0));       	
    end component;
begin
    mouse_component: mouse port map (
        clock_25Mhz => clock_25MHz,
        mouse_data => PS2_DAT, mouse_clk => PS2_CLK,
        reset => '0',
        left_button => left_button, right_button => right_button,
        mouse_cursor_row => cursor_row, mouse_cursor_column => cursor_column
    );

    process (CLOCK2_50)
    begin
        if (rising_edge(CLOCK2_50)) then
            clock_25MHz <= not clock_25MHz;
        end if;
    end process;
end architecture;