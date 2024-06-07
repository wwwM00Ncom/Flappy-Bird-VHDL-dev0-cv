library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity collision_controller is
    port (
        clock_60Hz : in std_logic;
        bird_pos : in t_bird_pos;
        powerup: in t_powerup;
        pipe_posns : in t_pipe_pos_arr;
        collision : out t_collision;
        active_powerup : in t_powerup_type
    );
end entity;

architecture behaviour of collision_controller is
begin
    process (clock_60Hz)
        variable collision_temp : t_collision;
        variable curr_pipe : t_pipe_pos;
        variable current_pipe_gap : integer;
    begin
        if (rising_edge(clock_60Hz)) then
            collision_temp := C_NONE;

            -- Widen the pipe gap if the player has the spring powerup
            if (active_powerup = P_SPRING) then
                current_pipe_gap := PIPE_GAP_RADIUS + POWERUP_SPRING_VALUE;
            else
                current_pipe_gap := PIPE_GAP_RADIUS;
            end if;

            -- Pipe collisions
            for i in 0 to 2 loop
                if (
                    bird_pos.x + (SPRITE_BIRD_WIDTH * 2) > pipe_posns(i).x - PIPE_WIDTH / 2 
                    and bird_pos.x < pipe_posns(i).x + PIPE_WIDTH / 2 
                    and (bird_pos.y + (SPRITE_BIRD_HEIGHT * 2) >= (pipe_posns(i).y + current_pipe_gap) or bird_pos.y <= pipe_posns(i).y - current_pipe_gap)
                ) then 
                    collision_temp := C_PIPE;
                end if;
            end loop;
            
            -- Powerup collision check
            if (powerup.active) then
                if (
                    bird_pos.x + (SPRITE_BIRD_WIDTH * 2) > powerup.x 
                    and bird_pos.x < powerup.x + (POWERUP_SIZE)
                    and bird_pos.y + (SPRITE_BIRD_HEIGHT * 2) >= powerup.y
                    and bird_pos.y < powerup.y + POWERUP_SIZE
                ) then 
                    collision_temp := C_POWERUP;
                end if;
            end if;

            -- Ground collisions come after as they take priority
            if (bird_pos.y + 2 * SPRITE_BIRD_HEIGHT >= GROUND_START_Y) then
                collision_temp := C_GROUND;
            end if;
            
            collision <= collision_temp;
        end if;
    end process;
end architecture;