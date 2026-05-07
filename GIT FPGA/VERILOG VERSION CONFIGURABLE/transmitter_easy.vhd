----------------------------------------------------------------------------------
-- transmitter_easy.vhd
--
-- Remplacement drop-in du bloc VHDL "transmitter" (Enigma).
-- Interface identique :
--   rst        : in  STD_LOGIC
--   clk        : in  STD_LOGIC
--   enable     : in  STD_LOGIC
--   stream_in  : in  STD_LOGIC_VECTOR(7 downto 0)
--   stream_out : out STD_LOGIC_VECTOR(7 downto 0)
--   data_valid : out STD_LOGIC
--
-- Traitement : stream_out = stream_in + 1
-- Latence    : 1 cycle (data_valid arrive 1 cycle après enable)
--
-- Pour l'intégrer dans frame_processing_style2.v, remplacer :
--   transmitter u_transmitter ( ... );
-- par :
--   transmitter_easy u_transmitter ( ... );
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity transmitter_easy is
    Port (
        rst        : in  STD_LOGIC;
        clk        : in  STD_LOGIC;
        enable     : in  STD_LOGIC;
        stream_in  : in  STD_LOGIC_VECTOR(7 downto 0);
        stream_out : out STD_LOGIC_VECTOR(7 downto 0);
        data_valid : out STD_LOGIC
    );
end entity transmitter_easy;

architecture Behavioral of transmitter_easy is

    -- Registre intermédiaire de pipeline
    signal result_reg  : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal valid_pipe  : STD_LOGIC := '0';  -- enable décalé d'1 cycle

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                result_reg <= (others => '0');
                valid_pipe <= '0';
                stream_out <= (others => '0');
                data_valid <= '0';
            else
                -- Cycle 1 : traitement (enable -> calcul +1 dans result_reg)
                valid_pipe <= enable;
                if enable = '1' then
                    result_reg <= std_logic_vector(unsigned(result_reg) + 1);
                end if;

                -- Cycle 2 : publication (result_reg -> stream_out, data_valid)
                data_valid <= valid_pipe;
                if valid_pipe = '1' then
                    stream_out <= result_reg;
                end if;
            end if;
        end if;
    end process;

end architecture Behavioral;