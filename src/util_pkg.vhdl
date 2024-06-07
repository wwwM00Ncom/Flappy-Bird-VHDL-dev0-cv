use work.sprites_pkg.all;

package util_pkg is
    constant SCREEN_MAX_X : integer := 639;
    constant SCREEN_MAX_Y : integer := 479;
    constant SCREEN_CENTRE_X : integer := SCREEN_MAX_X / 2;
    constant SCREEN_CENTRE_Y : integer := SCREEN_MAX_Y / 2;

    constant BIRD_MIN_X : integer := 0;
    constant BIRD_SCREEN_MAX_X : integer := SCREEN_MAX_X - SPRITE_BIRD_WIDTH * 2;
    constant BIRD_MIN_Y : integer := 0;
    constant BIRD_SCREEN_MAX_Y : integer := SCREEN_MAX_X - SPRITE_BIRD_HEIGHT * 2;

    constant BACKGROUND_WIDTH : integer := SPRITE_BG_DAY_WIDTH * 2;

    constant STARS_START_Y : integer := 150;

    constant PIPE_GAP_RADIUS : integer := 70;

    constant POWERUP_SPRING_VALUE : integer := 15;

    constant POWERUP_SIZE : integer := 24;

    -- Allows for a fairly large range of positions whilst minimising ALM usage
    constant PIPE_MIN_Y : integer := 112;
    constant PIPE_MAX_Y : integer := 368;

    constant PIPE_WIDTH : integer := SPRITE_PIPE_HEAD_WIDTH * 2;

    constant TEXT_CHAR_SIZE : integer := 8;
    constant TEXT_NUMBER_HEIGHT : integer := SPRITE_NUMBERS_HEIGHT / 11;

    constant GROUND_START_Y : integer := SCREEN_MAX_Y - 2 * SPRITE_GROUND_HEIGHT + 1;
    constant BACKGROUND_START_Y : integer := GROUND_START_Y - 2 * SPRITE_BG_DAY_HEIGHT;

    constant BIRD_MAX_VEL : integer := 10;
    constant BIRD_IMPULSE_VEL : integer := -8;

    constant DAMAGE_NUM_FRAMES : integer := 12;

    type t_powerup_type is (
        P_HEALTH, P_SLOW, P_GHOST, P_SPRING
    );

    type t_powerup is record
        x : integer;
        y : integer;
        --0 - Health, 1 - Pipes slow down, 2 - No collision with pipes
        p_type : t_powerup_type;
        active : boolean;
    end record;

    type t_gen_pos is record
        x : integer;
        y : integer;
    end record;

    type t_bird_pos is record
        x : integer range BIRD_MIN_X to BIRD_SCREEN_MAX_X;
        y : integer range BIRD_MIN_Y to BIRD_SCREEN_MAX_Y;
    end record;

    type t_pipe_pos is record
        x : integer range -PIPE_WIDTH / 2 to 2 * SCREEN_MAX_X; -- Large space to the right for initial pipe positions
        y : integer range PIPE_MIN_Y to PIPE_MAX_Y;
    end record;
    
    type t_pipe_pos_arr is array (0 to 2) of t_pipe_pos;

    type t_score is array (0 to 2) of integer range 0 to 10;

    type t_game_state is (
        S_INIT, S_GAME, S_DEATH
    );

    type t_collision is (
        C_NONE, C_PIPE, C_POWERUP, C_GROUND
    );
end package;