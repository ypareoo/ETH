library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_Rotor is
end tb_Rotor;

architecture Behavioral of tb_Rotor is

    -- Composant à tester (DUT)
    component Rotor is
        Port ( 
            clk : in std_logic;
            data_in : in std_logic_vector(6 downto 0);
            dv_in : in std_logic;
            data_out : out std_logic_vector(6 downto 0);
            dv_out : out std_logic
        );
    end component;

    -- Signaux internes du testbench
    signal clk_tb,dv_in_tb,dv_out_tb    : std_logic := '0';
    signal data_in_tb  : std_logic_vector(6 downto 0) := (others => '0');
    signal data_out_tb : std_logic_vector(6 downto 0);

    constant CLK_PERIOD : time := 10 ns;

begin

    -- Instanciation du DUT
    DUT : Rotor
        port map (
            clk      => clk_tb,
            data_in  => data_in_tb,
            dv_in => dv_in_tb,
            dv_out => dv_out_tb,
            data_out => data_out_tb
        );

    ------------------------------------------------------------------
    -- Génération de l'horloge
    ------------------------------------------------------------------
    clk_process : process
    begin
        while true loop
            clk_tb <= '0';
            wait for CLK_PERIOD / 2;
            clk_tb <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    ------------------------------------------------------------------
    -- Stimuli
    ------------------------------------------------------------------
    stim_process : process
    begin
        -- Attente de quelques cycles
        wait for 50 ns;

        -- Test 1
        dv_in_tb <= '1';
        data_in_tb <= "0000001"; -- 1
        wait for CLK_PERIOD;
        dv_in_tb <= '0';

--        -- Test 2
--        data_in_tb <= "0000010"; -- 10
--        wait for CLK_PERIOD;

--        -- Test 3
--        data_in_tb <= "0000011"; -- 20
--        wait for CLK_PERIOD;

--        -- Test 4
--        data_in_tb <= "0000100"; -- 63
--        wait for CLK_PERIOD;

--        -- Test 5
--        data_in_tb <= "0000000"; -- 0
--        wait for 3 * CLK_PERIOD;

        -- Fin de simulation
        wait;
    end process;

end Behavioral;

