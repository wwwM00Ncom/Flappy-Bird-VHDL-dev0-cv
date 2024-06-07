library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.util_pkg.all;
use work.sprites_pkg.all;

LIBRARY altera_mf;
USE altera_mf.all;

entity graphics_controller is
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
        powerup : in t_powerup;
        move_pixels : in integer;
        training : in boolean;
        active_powerup : in t_powerup_type;
        paused : in boolean;
        start_counter : in integer;
        damage_frames : in integer;
        powerup_timer : in integer
    );
end entity;

architecture behaviour of graphics_controller is 
    signal clock_25Mhz : std_logic := '0';
    signal row, column : std_logic_vector(9 downto 0);
    signal red_enable, green_enable, blue_enable : std_logic;

    -- As the bird can overlap with the background and pipes, we need 2 read heads 

    -- Used for the bird and collectables
	signal rom_address_a : std_logic_vector (ADDRESS_WIDTH - 1 downto 0);
    signal rom_data_a : std_logic_vector(11 downto 0);

    -- Used for pipes and background
	signal rom_address_b : std_logic_vector (ADDRESS_WIDTH - 1 downto 0);
    signal rom_data_b : std_logic_vector(11 downto 0);

    signal char_addr : std_logic_vector(6 downto 0);
    signal char_row, char_col : std_logic_vector(2 downto 0);
    signal char_bit : std_logic;
    -- Used for coloured and animated text
    -- Assumes text never overlaps
    signal text_colour : std_logic_vector(11 downto 0);
    signal counter_60Hz : integer range 0 to 60;
    constant health_pos : t_gen_pos := (x => 25, y => 25);

    signal current_pixel : std_logic_vector(11 downto 0);

    -- Enables rendering from that layer's ROM for the current pixel
    signal render_layer_a, render_layer_b, render_layer_text : boolean;

    signal ground_offset: integer := 0;
    signal background_offset : integer := 0;

    component vga_sync is
        PORT(	clock_25Mhz, red, green, blue		: IN	STD_LOGIC;
			red_out, green_out, blue_out, horiz_sync_out, vert_sync_out	: OUT	STD_LOGIC;
			pixel_row, pixel_column: OUT STD_LOGIC_VECTOR(9 DOWNTO 0));
    end component;

    component char_rom is
        PORT
        (
            character_address	:	IN STD_LOGIC_VECTOR (6 DOWNTO 0);
            font_row, font_col	:	IN STD_LOGIC_VECTOR (2 DOWNTO 0);
            clock				: 	IN STD_LOGIC ;
            rom_mux_output		:	OUT STD_LOGIC
        );
    end component;

    -- Used to interface with the spritesheet.
    -- Dual port, as we need to work with sprite transparency.
    component altsyncram is
        generic (
            operation_mode : string;
            width_a  : integer;
            widthad_a : integer;
            numwords_a : integer;
            width_b : integer;
            widthad_b : integer;
            numwords_b : integer;
            lpm_type : string;
            init_file : string;
            intended_device_family : string;
            address_aclr_a : string;
            address_aclr_b : string;
            clock_enable_input_a : string;
            clock_enable_input_b : string;
            clock_enable_output_a : string;
            clock_enable_output_b : string;
            outdata_aclr_a : string;
            outdata_aclr_b : string;
            outdata_reg_a : string;
            outdata_reg_b : string;
            width_byteena_a : integer;
            width_byteena_b : integer
        );
        port (
            clock0 : in std_logic;
            clock1 : in std_logic;
            address_a : in std_logic_vector(widthad_a - 1 downto 0);
            q_a : out std_logic_vector(width_a - 1 downto 0);
            address_b : in std_logic_vector(widthad_b - 1 downto 0);
            q_b : out std_logic_vector(width_b - 1 downto 0)
        );
    end component;
begin
    sync: vga_sync port map (
        clock_25Mhz => clock_25Mhz, 
        red => '1', green => '1', blue => '1', 
        red_out => red_enable, green_out => green_enable, blue_out => blue_enable, 
        horiz_sync_out => VGA_HS, vert_sync_out => VGA_VS, 
        pixel_row => row, pixel_column => column
    );

    chars: char_rom port map (
        character_address => char_addr,
        font_row => char_row, font_col => char_col,
        clock => CLOCK2_50,
        rom_mux_output => char_bit
    );

    altsyncram_component : altsyncram
	generic map (
    operation_mode => "BIDIR_DUAL_PORT",
    width_a => 12,
    widthad_a => ADDRESS_WIDTH,
    numwords_a => PIXEL_ALLOCATION,
    width_b => 12,
    widthad_b => ADDRESS_WIDTH,
    numwords_b => PIXEL_ALLOCATION,
    lpm_type => "altsyncram",
    init_file  => "sprites/sprites.mif",
    intended_device_family => "Cyclone III",
    address_aclr_a => "NONE",
    address_aclr_b => "NONE",
    clock_enable_input_a => "BYPASS",
    clock_enable_input_b => "BYPASS",
    clock_enable_output_a => "BYPASS",
    clock_enable_output_b => "BYPASS",
    outdata_aclr_a => "NONE",
    outdata_aclr_b => "NONE",
    outdata_reg_a => "UNREGISTERED",
    outdata_reg_b => "UNREGISTERED",
    width_byteena_a => 1,
    width_byteena_b => 1
    )
    port map (
        clock0 => CLOCK2_50,
        clock1 => CLOCK2_50,
        address_a => rom_address_a,
        q_a => rom_data_a,
        address_b => rom_address_b,
        q_b => rom_data_b
    );

    render: process (CLOCK2_50)
        variable x : integer range 0 to SCREEN_MAX_X;
        variable y : integer range 0 to SCREEN_MAX_Y;
        variable dX, dY : integer;

        variable current_pipe_gap : integer;

        variable current_pixel_computed : std_logic_vector(11 downto 0);

        variable screen_centre_string : string(1 to 16);
        constant training_string : string(1 to 13) := "TRAINING MODE";
        variable char : character;

        variable pipe_pos : t_pipe_pos;
        variable pipe_bg_fix : boolean;

        variable rom_a, rom_b : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);

        variable render_a, render_b, render_text : boolean;

        variable x_start, x_end, y_start, y_end : integer;

        variable bg_sprite_offset : integer;
        variable bird_sprite_offset : integer;
        variable powerup_sprite_offset : integer;

        variable digit : integer range 0 to 10; -- 10 is empty
        variable place : integer range 0 to 2;
        variable score_length : integer range 1 to 3;
        variable score_pos : t_gen_pos;
    begin
        if (rising_edge(CLOCK2_50)) then
            -- Figure out the length of the score
            if (score(2) = 0 and score(1) = 0) then
                score_length := 1;
            elsif (score(2) = 0) then
                score_length := 2;
            else
                score_length := 3;
            end if;
            -- Use that to centre the score position
            score_pos := (x => SCREEN_CENTRE_X - (6 - score_length) * SPRITE_NUMBERS_WIDTH, y => 25);

            -- Figure out the title string
            if (STATE = S_INIT) then
                screen_centre_string := " Click to Start ";
            elsif (STATE = S_DEATH) then
                screen_centre_string := "Click to Restart";
            end if;

            -- Set the background colour and sprite according to the day/night DIP switch
            if (day = '1') then
                current_pixel_computed := x"5cc";
                bg_sprite_offset := SPRITE_BG_DAY_OFFSET;
            else
                current_pixel_computed := x"189";
                bg_sprite_offset := SPRITE_BG_NIGHT_OFFSET;
            end if;

            -- Animate the bird
            if (state = S_GAME) then
                if (active_powerup = P_GHOST) then
                    bird_sprite_offset := SPRITE_BIRD_GHOST_OFFSET;
                elsif ((counter_60Hz mod 32) < 11) then
                    if (damage_frames > 0) then
                        bird_sprite_offset := SPRITE_BIRD_TINT_3_OFFSET;
                    else
                        bird_sprite_offset := SPRITE_BIRD_3_OFFSET;
                    end if;
                elsif ((counter_60Hz mod 32) < 21) then
                    if (damage_frames > 0) then
                        bird_sprite_offset := SPRITE_BIRD_TINT_2_OFFSET;
                    else
                        bird_sprite_offset := SPRITE_BIRD_2_OFFSET;
                    end if;
                else
                    if (damage_frames > 0) then
                        bird_sprite_offset := SPRITE_BIRD_TINT_OFFSET;
                    else
                        bird_sprite_offset := SPRITE_BIRD_OFFSET;
                    end if;
                end if;
            else
                if (damage_frames > 0) then
                    bird_sprite_offset := SPRITE_BIRD_TINT_2_OFFSET;
                else
                    bird_sprite_offset := SPRITE_BIRD_2_OFFSET;
                end if;
            end if;

            -- For all draw ops involving sprites, the address is set when the 25MHz clock is high and the data is read when it is low.
            -- This is to ensure the ROM has time to stabilise its output.

            if (clock_25MHz = '1') then

                x := to_integer(unsigned(column));
                y := to_integer(unsigned(row));

                rom_b := rom_address_b;
                rom_a := rom_address_a;

                -- Rendering is all shifted one pixel to the right, to counteract the ROM propagation delay. This means the leftmost pixel column is rendered black.

                -- 'B' LAYER (renders behind 'A' layer)

                render_b := false;

                -- Draw background
                if (y >= BACKGROUND_START_Y and y < GROUND_START_Y) then
                    -- This usage of `mod` is acceptable as the background sprites are specifically
                    -- 128 pixels wide, meaning it's optimised away to just `and 127`.
                    dX := ((x + background_offset) / 2) mod SPRITE_BG_DAY_WIDTH;
                    dY := (y - BACKGROUND_START_Y) / 2;
                    rom_b := std_logic_vector(to_unsigned(bg_sprite_offset + dY * SPRITE_BG_DAY_WIDTH + dX, ADDRESS_WIDTH));
                    render_b := true;
                end if;

                -- Draw stars
                if (day = '0') then
                    if (y >= STARS_START_Y and y < STARS_START_Y + 2 * SPRITE_BG_STARS_HEIGHT) then
                        -- Same here, sprite is 128 pixels wide
                        dX := ((x + background_offset) / 2) mod SPRITE_BG_STARS_WIDTH;
                        dY := (y - STARS_START_Y) / 2;
                        rom_b := std_logic_vector(to_unsigned(SPRITE_BG_STARS_OFFSET + dY * SPRITE_BG_STARS_WIDTH + dX, ADDRESS_WIDTH));
                        render_b := true;
                    end if;
                end if;

                if (active_powerup = P_SPRING) then
                    current_pipe_gap := PIPE_GAP_RADIUS + POWERUP_SPRING_VALUE;
                else
                    current_pipe_gap := PIPE_GAP_RADIUS;
                end if;

                -- Draw pipes
                for i in 0 to 2 loop
                    pipe_pos := pipe_posns(i);
                    -- Check the current pixel is within the pipe horizontally and not inside the gap
                    if (x >= pipe_pos.x - PIPE_WIDTH / 2 and x <= pipe_pos.x + PIPE_WIDTH / 2 and y < GROUND_START_Y and (y < pipe_pos.y - current_pipe_gap or y >= pipe_pos.y + current_pipe_gap)) then
                        dY := y - pipe_pos.y;

                        -- Check if the pixel is in the body of the pipe
                        if (dY < -current_pipe_gap - 2 * SPRITE_PIPE_HEAD_HEIGHT or dY >= current_pipe_gap + 2 * SPRITE_PIPE_HEAD_HEIGHT) then
                            x_start := pipe_pos.x - SPRITE_PIPE_BODY_WIDTH;
                            x_end := pipe_pos.x + SPRITE_PIPE_BODY_WIDTH;

                            -- This check fixes dragging pixels in the section in front of the background scenery
                            pipe_bg_fix := (x < x_end or (y < BACKGROUND_START_Y and (day = '1' or (y < STARS_START_Y or y >= STARS_START_Y + 2 * SPRITE_BG_STARS_HEIGHT))));

                            -- We need another horizontal check here, as the body's 2 pixels thinner than the pipe overall
                            if (x >= x_start and x <= x_end and pipe_bg_fix) then
                                dX := x - x_start;
                                rom_b := std_logic_vector(to_unsigned(SPRITE_PIPE_BODY_OFFSET + (dX / 2), ADDRESS_WIDTH));
                                if (dX > 0) then
                                    render_b := true;
                                end if;
                            end if;
                        else
                            -- Get the appropriate delta depending on if we're rendering the upper or lower pipe head
                            if (dY >= current_pipe_gap) then
                                dY := dY - current_pipe_gap;
                            elsif dY < -current_pipe_gap then
                                dY := SPRITE_PIPE_HEAD_HEIGHT * 2 - (dY + current_pipe_gap + SPRITE_PIPE_HEAD_HEIGHT * 2) - 1;
                            end if;

                            x_start := pipe_pos.x - SPRITE_PIPE_HEAD_WIDTH;
                            x_end := pipe_pos.x + SPRITE_PIPE_HEAD_WIDTH;

                            -- This check fixes dragging pixels in the section in front of the background scenery
                            pipe_bg_fix := (x < x_end or (y < BACKGROUND_START_Y and (day = '1' or (y < STARS_START_Y or y >= STARS_START_Y + 2 * SPRITE_BG_STARS_HEIGHT))));

                            if (pipe_bg_fix) then
                                dX := x - x_start;
                                rom_b := std_logic_vector(to_unsigned(SPRITE_PIPE_HEAD_OFFSET + (dY / 2) * SPRITE_PIPE_HEAD_WIDTH + (dX / 2), ADDRESS_WIDTH));
                                if (dX > 0) then
                                    render_b := true;
                                end if;
                            end if;
                        end if;
                    end if;
                end loop;

                -- 'A' LAYER (renders behind Text layer)
                -- We assign the ROM address directly in this layer as we assume two sprites in the A layer NEVER overlap.

                render_a := false;

                -- Render powerups
                if (powerup.active and x >= powerup.x and x <= (powerup.x + POWERUP_SIZE) and y >= powerup.y and y < (powerup.y + POWERUP_SIZE)) then
                    dX := x - powerup.x;
                    dY := y - powerup.y;
                    case powerup.p_type is
                        when P_HEALTH => powerup_sprite_offset := SPRITE_POWERUP_HEALTH_OFFSET;
                        when P_SLOW => powerup_sprite_offset := SPRITE_POWERUP_SLOW_OFFSET;
                        when P_GHOST => powerup_sprite_offset := SPRITE_POWERUP_GHOST_OFFSET;
                        when P_SPRING => powerup_sprite_offset := SPRITE_POWERUP_SPRING_OFFSET;
                    end case;
                    rom_a := std_logic_vector(to_unsigned(powerup_sprite_offset + (dY / 2) * (POWERUP_SIZE / 2) + (dX / 2), ADDRESS_WIDTH));
                    if (dX > 0) then
                        render_a := true;
                    end if;
                end if;

                -- Draw the bird
                if (x >= bird_pos.x and x <= (bird_pos.x + (SPRITE_BIRD_WIDTH * 2)) and y >= bird_pos.y and y < (bird_pos.y + SPRITE_BIRD_HEIGHT * 2)) then
                    dX := x - bird_pos.x;
                    dY := y - bird_pos.y;
                    rom_a := std_logic_vector(to_unsigned(bird_sprite_offset + (dY / 2) * SPRITE_BIRD_WIDTH + (dX / 2), ADDRESS_WIDTH));
                    if (dX > 0) then
                        render_a := true;
                    end if;
                end if;

                -- Draw the ground
                if (y >= GROUND_START_Y) then
                    -- Sprite is 16 pixels wide
                    dX := ((x + ground_offset) / 2) mod SPRITE_GROUND_WIDTH;
                    dY := (y - GROUND_START_Y) / 2;
                    rom_a := std_logic_vector(to_unsigned(SPRITE_GROUND_OFFSET + dY * SPRITE_GROUND_WIDTH + dX, ADDRESS_WIDTH));
                    render_a := true;
                end if;

                -- Score is rendered as a sprite on the A layer, so that B&W can be used without requiring a new text ROM format
                if (x >= score_pos.x and x <= 3 * 2 * SPRITE_NUMBERS_WIDTH + score_pos.x and y >= score_pos.y and y < 2 * TEXT_NUMBER_HEIGHT + score_pos.y) then
                    dX := x - score_pos.x;
                    dY := y - score_pos.y;

                    -- Figure out the place - 0 is ones, 1 is tens, 2 is hundreds
                    place := 2 - (dX / (SPRITE_NUMBERS_WIDTH * 2));
                    digit := score(place);

                    -- If the rightmost non-zero digit is past this place we render an empty sprite
                    if (place >= score_length) then
                        digit := 10;
                    end if;

                    rom_a := std_logic_vector(to_unsigned(
                        SPRITE_NUMBERS_OFFSET 
                        -- Offset of digit in sprite
                        + digit * SPRITE_NUMBERS_WIDTH * TEXT_NUMBER_HEIGHT
                        -- Row in digit
                        + (dY / 2) * SPRITE_NUMBERS_WIDTH
                        -- Column in digit, with compensation for digit's place
                        + ((dX / 2) - (2 - place) * SPRITE_NUMBERS_WIDTH),
                        ADDRESS_WIDTH
                    ));

                    if (dX > 0) then
                        render_a := true;
                    end if;
                end if;

                -- Draw the 'paused' icon
                if (paused) then
                    x_start := SCREEN_CENTRE_X - SPRITE_PAUSED_WIDTH;
                    x_end := SCREEN_CENTRE_X + SPRITE_PAUSED_WIDTH;
                    y_start := 86;
                    y_end := 86 + 2 * SPRITE_PAUSED_HEIGHT;
                    if (x >= x_start and x <= x_end and y >= y_start and y < y_end) then
                        dX := x - x_start;
                        dY := y - y_start;
                        rom_a := std_logic_vector(to_unsigned(SPRITE_PAUSED_OFFSET + (dY / 2) * SPRITE_PAUSED_WIDTH + (dX / 2), ADDRESS_WIDTH));
                        if (dX > 0) then
                            render_a := true;
                        end if;
                    end if;
                end if;

                -- Draw the active powerup
                -- If the powerup timer has less than a second remaining, we flash it
                if (active_powerup /= P_HEALTH and (powerup_timer > 60 or (powerup_timer mod 8 < 4))) then
                    x_start := 25;
                    x_end := 25 + POWERUP_SIZE;
                    y_start := 65;
                    y_end := 65 + POWERUP_SIZE;
                    if (x >= x_start and x <= x_end and y >= y_start and y < y_end) then
                        dX := x - x_start;
                        dY := y - y_start;
                        case active_powerup is
                            when P_HEALTH => powerup_sprite_offset := SPRITE_POWERUP_HEALTH_OFFSET;
                            when P_SLOW => powerup_sprite_offset := SPRITE_POWERUP_SLOW_OFFSET;
                            when P_GHOST => powerup_sprite_offset := SPRITE_POWERUP_GHOST_OFFSET;
                            when P_SPRING => powerup_sprite_offset := SPRITE_POWERUP_SPRING_OFFSET;
                        end case;
                        rom_a := std_logic_vector(to_unsigned(powerup_sprite_offset + (dY / 2) * (POWERUP_SIZE / 2) + (dX / 2), ADDRESS_WIDTH));
                        if (dX > 0) then
                            render_a := true;
                        end if;
                    end if;
                end if;

                -- TEXT LAYER

                render_text := false;
                
                -- Draw the "Click to Start" or "Click to Restart" text
                if (start_counter = 0 and (state = S_INIT or state = S_DEATH)) then
                    x_start := SCREEN_CENTRE_X - (screen_centre_string'length * TEXT_CHAR_SIZE) + 2;
                    x_end := SCREEN_CENTRE_X + (screen_centre_string'length * TEXT_CHAR_SIZE);
                    y_start := SCREEN_CENTRE_Y - TEXT_CHAR_SIZE;
                    y_end := SCREEN_CENTRE_Y + TEXT_CHAR_SIZE;
                    if (y >= y_start and y < y_end and x >= x_start and x <= x_end) then
                        dX := (x - x_start) / 2;
                        dY := (y - y_start) / 2;
                        char := screen_centre_string(dX / TEXT_CHAR_SIZE + 1);
                        char_row <= std_logic_vector(to_unsigned(dY, 3));
                        char_col <= std_logic_vector(to_unsigned(dX, 3));

                        char_addr <= std_logic_vector(to_unsigned(character'pos(char), 7));
                        if (counter_60Hz >= 30) then
                            text_colour <= x"888";
                        else
                            text_colour <= x"fff";
                        end if;

                        if (dX > 0) then
                            render_text := true;
                        end if;
                    end if;
                end if;

                -- Draw training mode text
                if (training) then
                    x_start := SCREEN_MAX_X - training_string'length * 2 * TEXT_CHAR_SIZE - 25;
                    x_end := SCREEN_MAX_X - 25;
                    if (x >= x_start and x <= x_end and y >= 25 and y < 2 * TEXT_CHAR_SIZE + 25) then
                        dX := (x - x_start) / 2;
                        dY := (y - 25) / 2;
                        char := training_string(dX / TEXT_CHAR_SIZE + 1);
                        char_row <= std_logic_vector(to_unsigned(dY, 3));
                        char_col <= std_logic_vector(to_unsigned(dX, 3));
                        char_addr <= std_logic_vector(to_unsigned(character'pos(char), 7));
                        text_colour <= x"fff";
                        if (dX > 0) then
                            render_text := true;
                        end if;
                    end if;
                end if;

                -- Draw health (technically text, stored in the font sheet)
                if (x >= health_pos.x and x < 3 * 4 * TEXT_CHAR_SIZE + health_pos.x and y >= health_pos.y and y < 4 * TEXT_CHAR_SIZE + health_pos.y) then
                    dX := (x - health_pos.x) / 4;
                    dY := (y - health_pos.y) / 4;
                    place := dX / TEXT_CHAR_SIZE;

                    char_row <= std_logic_vector(to_unsigned(dY, 3));
                    char_col <= std_logic_vector(to_unsigned(dX, 3));

                    -- Figure out if this heart should be full or empty
                    if (place < health) then
                        char_addr <= std_logic_vector(to_unsigned(16, 7));
                        text_colour <= x"f00";
                    else
                        char_addr <= std_logic_vector(to_unsigned(17, 7));
                        text_colour <= x"900";
                    end if;
                    
                    if (x > health_pos.x) then
                        render_text := true;
                    end if;
                end if;
            end if;

            -- We send pixel data out when the 25MHz is low, so that it's rendered when it goes high
            if (clock_25MHz = '0') then
                -- Render layer B at the back
                if (render_layer_b and rom_data_b /= x"000") then
                    current_pixel_computed := rom_data_b;
                end if;
                -- Render layer A in front of that
                if (render_layer_a and rom_data_a /= x"000") then
                    current_pixel_computed := rom_data_a;
                end if;
                -- Render the text layer at the front
                if (render_layer_text and char_bit = '1') then
                    current_pixel_computed := text_colour;
                end if;

                -- The aforementioned black leftmost column (would be garbage pixels otherwise)
                if (x = 0) then
                    current_pixel <= x"000";
                else
                    current_pixel <= current_pixel_computed;
                end if;
            end if;

            clock_25Mhz <= not clock_25Mhz;

            rom_address_a <= rom_a;
            rom_address_b <= rom_b;

            render_layer_a <= render_a;
            render_layer_b <= render_b;
            render_layer_text <= render_text;
        end if;
    end process;

    -- Scroll the parallax backgrounds
    parallax_scroll : process (clock_60Hz)
        variable bg_offset, gr_offset: integer;
        variable move_pixels_temp : integer;
    begin
        if (rising_edge(clock_60Hz) and STATE = S_GAME ) then
            -- Divide the pixels to move this frame by 2 for the background
            move_pixels_temp := (move_pixels / 2);
            if (move_pixels_temp = 0) then
                move_pixels_temp := 1;
            end if;
            bg_offset := background_offset + move_pixels_temp;
            if (bg_offset >= BACKGROUND_WIDTH) then
                bg_offset := bg_offset - BACKGROUND_WIDTH;
            end if;
            background_offset <= bg_offset;

            gr_offset := ground_offset + move_pixels;
            if (gr_offset >= 2 * SPRITE_GROUND_WIDTH) then
                gr_offset := gr_offset - 2 * SPRITE_GROUND_WIDTH;
            end if;
            ground_offset <= gr_offset;
        end if;
    end process;

    count : process(clock_60Hz)
        variable counter_temp : integer;
    begin
        if (rising_edge(clock_60Hz)) then
            counter_temp := counter_60Hz + 1;
            if (counter_temp >= 60) then
                counter_temp := 0;
            end if;
            counter_60Hz <= counter_temp;
        end if;
    end process;

    VGA_R <= current_pixel(11 downto 8) when red_enable = '1' else "0000";
    VGA_G <= current_pixel(7 downto 4) when green_enable = '1' else "0000";
    VGA_B <= current_pixel(3 downto 0) when blue_enable = '1' else "0000";
end architecture;