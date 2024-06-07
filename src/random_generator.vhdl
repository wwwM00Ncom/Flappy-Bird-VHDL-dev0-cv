library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity random_generator is
    port (
        clock_60Hz : in std_logic;
        rng : out integer range 0 to 65535
    );
end entity;

architecture behaviour of random_generator is
    signal rng_internal : std_logic_vector(15 downto 0) := "0000000000000001";
begin
    process (clock_60Hz)
    begin
        if (rising_edge(clock_60Hz)) then
            -- Using these 'tap bits' should result in it going through all 65535 states
            rng_internal <= rng_internal(14 downto 0) & (rng_internal(15) xor rng_internal(13) xor rng_internal(12) xor rng_internal(10));
        end if;
    end process;
    rng <= to_integer(unsigned(rng_internal));
end architecture;
