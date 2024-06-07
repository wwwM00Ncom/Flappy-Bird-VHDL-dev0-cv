library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity bird_controller is
    port (
        state : t_game_state;
        clock_60Hz : in std_logic;
        bird_pos : inout t_bird_pos;
        left_click : in std_logic
    );
end entity;

architecture behaviour of bird_controller is
    signal left_click_mem : boolean := false;
    signal bird_y_vel : integer := 0;
    signal flip_flop : boolean := false;
begin
    process (clock_60Hz)
        variable y_vel, y_pos : integer;
    begin
        if (rising_edge(clock_60Hz)) then
            -- State Initial
            if (state = S_INIT) then
                -- Middle of the screen
                bird_pos.y <= SCREEN_MAX_Y / 2 - SPRITE_BIRD_HEIGHT / 2;
                bird_y_vel <= 0;
            -- State Game and Death
            else
                y_pos := bird_pos.y;

                -- Only increase the bird's Y velocity every 2 frames
                if (flip_flop) then
                    y_vel := bird_y_vel + 1;
                else
                    y_vel := bird_y_vel;
                end if;
                flip_flop <= not flip_flop;

                -- Cap the Y velocity
                if (y_vel > BIRD_MAX_VEL) then
                    y_vel := BIRD_MAX_VEL;
                end if;

                -- state Game
                if (state = S_GAME) then
                    -- Set the Y velocity to the impulse if the mouse button has been pressed
                    if (left_click = '1' and not left_click_mem) then
                        y_vel := BIRD_IMPULSE_VEL;
                        left_click_mem <= true;
                    elsif (left_click = '0' and left_click_mem) then
                        left_click_mem <= false;
                    end if;
                -- state Death: disable the mouse
                end if;

                y_pos := y_pos + y_vel;
                -- Stop the bird if it hits the ground
                if (y_pos + 2 * SPRITE_BIRD_HEIGHT > GROUND_START_Y) then
                    y_pos := GROUND_START_Y - 2 * SPRITE_BIRD_HEIGHT;
                    y_vel := 0;
                elsif (y_pos < 0) then
                    y_pos := 0;
                    y_vel := 0;
                end if;
                bird_pos.y <= y_pos;
                bird_y_vel <= y_vel;

            end if;
        end if;
    end process;
    bird_pos.x <= 100;
end architecture;