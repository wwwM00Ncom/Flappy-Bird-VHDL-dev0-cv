library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity score_controller is
    port (
        clock_60Hz : in std_logic;
        pipes : in t_pipe_pos_arr;
        bird : in t_bird_pos;
        score_out : out t_score;
        state : in t_game_state;
        difficulty : out integer
    );
end entity;

architecture behaviour of score_controller is
    signal score : t_score;
    signal old_pipes : t_pipe_pos_arr;
    -- Cascading increment
    procedure increment_score is
        variable score_hold : t_score;
    begin
        score_hold := score;

        score_hold(0) := score_hold(0) + 1;
        if (score_hold(0) = 10) then
            score_hold(0) := 0;
            score_hold(1) := score_hold(1) + 1;
            if (score_hold(1) = 10) then
                score_hold(1) := 0;
                score_hold(2) := score_hold(2) + 1;
                if (score_hold(2) = 10) then
                    score_hold(2) := 0;
                end if;
            end if;
        end if;
        
        score <= score_hold;
    end procedure;
begin
    process (clock_60Hz, state)
        variable new_pipe_x : integer;
        variable pipe_pos : t_pipe_pos;
        variable score_temp : natural;
        variable difficulty_temp : natural;
    begin
        if (state = S_INIT) then
            score <= (others => 0);
        elsif (rising_edge(clock_60Hz)) then
            -- Check if any pipes passed the bird this frame, and if so increment the score
            for i in 0 to 2 loop
                if (old_pipes(i).x >= bird.x and pipes(i).x < bird.x) then
                    increment_score;
                end if;
                old_pipes(i) <= pipes(i);
            end loop;
            -- each difficulty should be 10 scores a level (at least level 1)
            difficulty_temp := score(2) * 10 + score(1) + 1;
            if (difficulty_temp > 9) then
                difficulty_temp := 9;
            end if;
            difficulty <= difficulty_temp;
        end if;
    end process;

    score_out <= score;
end architecture;