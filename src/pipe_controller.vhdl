library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity pipe_controller is
    port (
        state : in t_game_state;
        clock_60Hz : in std_logic;
        pipe_posns : out t_pipe_pos_arr;
        rng : in integer;
        move_pixels : in integer
    );
end entity;

architecture behaviour of pipe_controller is

signal current_pipe_posns : t_pipe_pos_arr;
signal initial_pipe : boolean := true;

begin
    process (clock_60Hz)
        variable new_pipe_x : integer;
        variable new_pipe_y : integer;
        variable pipe_pos : t_pipe_pos;
        variable random_y : integer;
    begin
	
	 
        if (rising_edge(clock_60Hz)) then
            -- Generate random y within specified ranges
            random_y := (rng mod (PIPE_MAX_Y - PIPE_MIN_Y)) + PIPE_MIN_Y;

            -- State Initial
            if (state = S_INIT and initial_pipe) then
                -- set this one to fix bugs that in the initial state, the pipe y position will be assigned once.
                initial_pipe <= false;

                -- initial random x, y
                for i in 0 to 2 loop
                    current_pipe_posns(i).x <= SCREEN_CENTRE_X + ((SCREEN_MAX_X + PIPE_WIDTH) / 3) + i * ((SCREEN_MAX_X + PIPE_WIDTH) / 3);
                    current_pipe_posns(i).y <= ((random_y + 5201314 * i) mod (PIPE_MAX_Y - PIPE_MIN_Y)) + PIPE_MIN_Y;
                end loop;

            -- State Game
            else
                if (state = S_GAME) then
                    -- set this one to fix bugs that in the initial state, the pipe y position will be assigned once.
                    initial_pipe <= true;
                    -- x y generation
                    for i in 0 to 2 loop
                        pipe_pos := current_pipe_posns(i);
                        new_pipe_x := pipe_pos.x - move_pixels;
                        new_pipe_y := pipe_pos.y;
                        if (new_pipe_x < -PIPE_WIDTH / 2) then
                            new_pipe_x := SCREEN_MAX_X + PIPE_WIDTH / 2;
                            new_pipe_y := random_y;
                        end if;
                        current_pipe_posns(i).x <= new_pipe_x;
                        current_pipe_posns(i).y <= new_pipe_y;
                    end loop;
                end if;
            end if;
        end if;
    end process;
	 pipe_posns <= current_pipe_posns;
end architecture;