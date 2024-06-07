library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

entity flappy_bird is
    port (
        CLOCK2_50: in std_logic;
        KEY : in std_logic_vector(1 downto 0);
        SW : in std_logic_vector(1 downto 0);
        LEDR : out std_logic_vector(9 downto 0);
        VGA_HS, VGA_VS : out std_logic;
        VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
        PS2_CLK, PS2_DAT : inout std_logic;
        HEX0, HEX1, HEX2, HEX5 : out std_logic_vector(6 downto 0)
    );
end entity;

architecture behaviour of flappy_bird is
    signal state : t_game_state := S_INIT;

    -- Bird position
    signal bird_pos : t_bird_pos := (x => 75, y => 240);

    signal pipe_posns : t_pipe_pos_arr;

    -- Goes high at 60Hz, but spends most of the time at low - use this for rising edge detection only!
    signal clock_60Hz : std_logic;
    signal clock_30Hz : std_logic;

    signal health: integer range 0 to 3 := 3;

    -- Used to drive 60Hz clock, as we know its period is also 60Hz
    signal vertical_sync : std_logic;

    signal left_button, right_button : std_logic;
    signal mouse_row, mouse_column : std_logic_vector(9 downto 0);

    signal init : std_logic;

    signal paused : boolean := false;

    signal score : t_score;

    signal day : std_logic;
    signal training : boolean;

    signal collision : t_collision := C_NONE;
    signal collide_mem : boolean := false;
    signal damage_frames : integer range 0 to DAMAGE_NUM_FRAMES := 0;

    signal powerup: t_powerup;
    -- Because we can't drive with more than one process
    signal kill_powerup : boolean := false;
    signal active_powerup : t_powerup_type := P_HEALTH;
    signal powerup_timer : integer range 0 to 300 := 0;

    -- random number
    signal rng : integer range 0 to 65535;

    -- restart counter after death
    signal start_counter : integer := 0;

    -- difficulty set
    -- level of difficulty: original speed * difficulty
    signal difficulty: integer range 1 to 9;

    signal move_pixels_this_frame : integer := 0;
    signal move_pixels : integer := 0;

    component BCD_to_SevenSeg is
        port (BCD_digit : in std_logic_vector(3 downto 0);
        SevenSeg_out : out std_logic_vector(6 downto 0));
    end component;

    component graphics_controller is
        port (
            state : in t_game_state;
            CLOCK2_50, clock_60Hz: in std_logic;
            VGA_HS, VGA_VS : out std_logic;
            VGA_R, VGA_G, VGA_B : out std_logic_vector(3 downto 0);
            bird_pos : in t_bird_pos;
            pipe_posns : in t_pipe_pos_arr;
            score : in t_score;
            day : in std_logic;
            health : in integer;
            powerup : t_powerup;
            move_pixels : integer;
            training : boolean;
            active_powerup : in t_powerup_type;
            paused : in boolean;
            start_counter : in integer;
            damage_frames : in integer;
            powerup_timer : in integer
        );
    end component;

    component mouse_controller is
        port (
            CLOCK2_50, reset : in std_logic;
            left_button, right_button : out std_logic;
            cursor_row, cursor_column : out std_logic_vector(9 downto 0);
            PS2_CLK, PS2_DAT : inout std_logic
        );
    end component;

    component bird_controller is
        port (
            state : t_game_state;
            clock_60Hz : in std_logic;
            bird_pos : inout t_bird_pos;
            left_click : in std_logic
        );
    end component;

    component score_controller is
        port (
            clock_60Hz : in std_logic;
            pipes : in t_pipe_pos_arr;
            bird : in t_bird_pos;
            score_out : out t_score;
            state : in t_game_state;
            difficulty : out integer
        );
    end component;

    component pipe_controller is
        port (
            state : in t_game_state;
            clock_60Hz : in std_logic;
            pipe_posns : out t_pipe_pos_arr;
            rng : in integer;
            move_pixels : in integer
        );
    end component;

    component powerup_controller is
        port (
            state : in t_game_state;
            clock_60Hz : in std_logic;
            powerup : out t_powerup;
            rng : in integer;
            pipe_posns: in t_pipe_pos_arr;
            health : in integer;
            move_pixels : in integer;
            kill_powerup : in boolean
        );
    end component;

    component random_generator is
        port (
            clock_60Hz : in std_logic;
            rng : out integer range 0 to 65535
        );
    end component;

    component collision_controller is
        port (
            clock_60Hz : in std_logic;
            bird_pos : in t_bird_pos;
            powerup: in t_powerup;
            pipe_posns : in t_pipe_pos_arr;
            collision : out t_collision;
            active_powerup : in t_powerup_type
        );
    end component;

    procedure initialise is
    begin
        state <= S_INIT;
        health <= 3;
        active_powerup <= P_HEALTH;
        powerup_timer <= 0;
        start_counter <= 0;
        damage_frames <= 0;
    end procedure;

begin
    score_hundreds : BCD_to_SevenSeg port map (
        BCD_digit => std_logic_vector(to_unsigned(score(2), 4)), SevenSeg_out => HEX2
    );
    score_tens : BCD_to_SevenSeg port map (
        BCD_digit => std_logic_vector(to_unsigned(score(1), 4)), SevenSeg_out => HEX1
    );
    score_ones : BCD_to_SevenSeg port map (
        BCD_digit => std_logic_vector(to_unsigned(score(0), 4)), SevenSeg_out => HEX0
    );

    health_bcd : BCD_to_SevenSeg port map (
        BCD_DIGIT => std_logic_vector(to_unsigned(health, 4)), SevenSeg_out => HEX5
    );

    graphics: graphics_controller port map (
        state => state,
        CLOCK2_50 => CLOCK2_50, clock_60Hz => clock_60Hz,
        VGA_HS => VGA_HS, VGA_VS => vertical_sync, 
        VGA_R => VGA_R, VGA_G => VGA_G, VGA_B => VGA_B,
        bird_pos => bird_pos, pipe_posns => pipe_posns,
        score => score,
        day => day,
        health => health,
        powerup => powerup,
        move_pixels => move_pixels_this_frame,
        training => training,
        active_powerup => active_powerup,
        paused => paused,
        start_counter => start_counter,
        damage_frames => damage_frames,
        powerup_timer => powerup_timer
    );

    mouse: mouse_controller port map (
        CLOCK2_50 => CLOCK2_50, reset => init,
        left_button => left_button, right_button => right_button,
        cursor_row => mouse_row, cursor_column => mouse_column,
        PS2_CLK => PS2_CLK, PS2_DAT => PS2_DAT
    );

    bird : bird_controller port map (
        state => state,
        clock_60Hz => clock_60Hz,
        bird_pos => bird_pos,
        left_click => left_button
    );

    scorer : score_controller port map (
        clock_60Hz => clock_60Hz,
        pipes => pipe_posns,
        bird => bird_pos,
        score_out => score,
        state => state,
        difficulty => difficulty
    );

    pipe : pipe_controller port map (
        state => state,
        clock_60Hz => clock_60Hz,
        pipe_posns => pipe_posns,
        rng => rng,
        move_pixels => move_pixels_this_frame
    );

    random : random_generator port map (
        clock_60Hz => clock_60Hz,
        rng => rng
    );

    collide : collision_controller port map (
        clock_60Hz => clock_60Hz,
        bird_pos => bird_pos,
        pipe_posns => pipe_posns,
        collision => collision,
        powerup => powerup,
        active_powerup => active_powerup
    );

    powerups : powerup_controller port map (
        state => state,
        clock_60Hz => clock_60Hz,
        powerup => powerup,
        rng => rng,
        pipe_posns => pipe_posns,
        health => health,
        move_pixels => move_pixels_this_frame,
        kill_powerup => kill_powerup
    );

    state_machine : process (clock_60Hz)
        variable health_temp : integer;
        variable should_kill_powerup : boolean;
        variable move_pixels_scaled : integer;
        variable powerup_timer_temp : integer;
        variable start_counter_temp : integer;
        variable damage_frames_temp : integer;
    begin
        if (rising_edge(clock_60Hz)) then
            clock_30Hz <= not clock_30Hz;

            start_counter_temp := start_counter;

            if (init = '1') then
                initialise;
            else
                -- Game start/restart
                if (left_button = '1' and state = S_INIT and start_counter = 0) then
                    state <= S_GAME;
                elsif (left_button = '1' and state = S_DEATH and start_counter = 0) then
                    initialise;
                    start_counter_temp := 2;
                end if;
            end if;
            -- This is done here so that it's vsynced
            day <= not SW(0);

            move_pixels_scaled := (move_pixels / 2) + (move_pixels / 4);
            -- Allow for odd numbers of pixels moved per two frames.
            -- This means we have twice the speeds to select from.
            if (clock_30Hz = '0') then
                -- If the active powerup is the slow one, the speed should be 4/5ths
                if (active_powerup = P_SLOW and powerup_timer > 0) then
                    move_pixels_this_frame <= move_pixels_scaled / 2;
                else
                    move_pixels_this_frame <= move_pixels / 2;
                end if;
                move_pixels <= move_pixels / 2 + (move_pixels mod 2);
            else
                if (active_powerup = P_SLOW and powerup_timer > 0) then
                    move_pixels_this_frame <= move_pixels_scaled;
                else
                    move_pixels_this_frame <= move_pixels;
                end if;
                move_pixels <= 3 + difficulty;
            end if;

            should_kill_powerup := false;
            powerup_timer_temp := powerup_timer;

            damage_frames_temp := damage_frames;

            -- Handle collisions
            -- Collision with the ground ignores collision memory, as it should be an insta-death
            if (state = S_GAME and collision = C_GROUND and active_powerup /= P_GHOST and not training) then
                health <= 0;
                state <= S_DEATH;
                start_counter_temp := 60;
                damage_frames_temp := DAMAGE_NUM_FRAMES;
            elsif (state = S_GAME and (health > 0 or training) and not collide_mem) then 
                -- Collision with pipe
                -- Player shouldn't take damage if they have damage frames
                if (collision = C_PIPE and active_powerup /= P_GHOST and damage_frames = 0) then
                    if (not training) then
                        health_temp := health - 1;
                        -- Player dies if health reaches 0
                        if (health_temp = 0 and state = S_GAME) then
                            state <= S_DEATH;
                            start_counter_temp := 60;
                        end if;
                        health <= health_temp;
                    end if;
                    collide_mem <= true;
                    damage_frames_temp := DAMAGE_NUM_FRAMES;
                -- Collision with powerup
                elsif (collision = C_POWERUP) then
                    should_kill_powerup := true;
                    if (powerup.p_type /= P_HEALTH) then
                        -- We do this here because we don't want health overriding an active powerup
                        active_powerup <= powerup.p_type;
                        powerup_timer_temp := 300;
                    elsif (powerup.p_type = P_HEALTH and health < 3 and not kill_powerup) then
                        health <= health + 1;
                        -- Set the timer to a small value so that the health
                        -- isn't applied more than once before it's set to inactive
                        powerup_timer_temp := 30;
                    end if;
                end if;
            elsif (collision = C_NONE and collide_mem and state /= S_DEATH) then
                collide_mem <= false;
            end if;

            kill_powerup <= should_kill_powerup;

            -- Decrement damage tint frames counter
            if (damage_frames_temp > 0) then
                damage_frames_temp := damage_frames_temp - 1;
            end if;

            damage_frames <= damage_frames_temp;
            
            -- Decrement the restart counter
            if (start_counter_temp > 0) then
                start_counter_temp := start_counter_temp - 1;
            end if;

            start_counter <= start_counter_temp;

            -- Decrement the powerup timer
            if (powerup_timer_temp > 0) then
                powerup_timer_temp := powerup_timer_temp - 1;
            elsif (powerup_timer = 0) then
                -- P_HEALTH has no effect as an active powerup
                active_powerup <= P_HEALTH;
            end if;

            powerup_timer <= powerup_timer_temp;

            -- Training mode toggle
            if (SW(1) = '1' and not training) then
                training <= true;
                if (state = S_GAME) then
                    STATE <= S_INIT;
                    health <= 3;
                end if;
            elsif (SW(1) = '0' and training) then
                training <= false;
                if (state = S_GAME) then
                    STATE <= S_INIT;
                    health <= 3;
                end if;
            end if;
        end if;
    end process;

    pause_handler : process(KEY(1))
    begin
        -- Falling edge because the buttons are active low (probably a pulldown resistor)
        if (falling_edge(KEY(1))) then
            paused <= not paused;
        end if;
    end process;

    VGA_VS <= vertical_sync;
    clock_60Hz <= clock_60Hz when paused else not vertical_sync;

    init <= not KEY(0);
end architecture;