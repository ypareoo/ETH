----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09/18/2017 04:03:43 PM
-- Design Name: 
-- Module Name: transmitter - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity transmitter is
    Port ( rst : in STD_LOGIC;
           clk : in STD_LOGIC;
           enable : in STD_LOGIC;
           stream_in : in STD_LOGIC_VECTOR(7 downto 0);
           stream_out : out STD_LOGIC_VECTOR(7 downto 0);
           data_valid : out std_logic);
end transmitter;

architecture Behavioral of transmitter is   

component Rotor is
    Port ( 
        rst : in std_logic;
        clk : in std_logic;
        num_rot : in std_logic_vector(2 downto 0);
        data_in : in std_logic_vector(7 downto 0);
        dv_in : in std_logic;
        notch_pos : in std_logic_vector(7 downto 0); --ligne rajoutée
        data_out : out std_logic_vector(7 downto 0);
        dv_out : out std_logic
    );
end component;

component Rotor_inv is
    Port ( 
        rst : in std_logic;
        clk : in std_logic;
        num_rot : in std_logic_vector(2 downto 0);
        data_in : in std_logic_vector(7 downto 0);
        dv_in : in std_logic;
        notch_pos : in std_logic_vector(7 downto 0); --ligne rajoutée
        data_out : out std_logic_vector(7 downto 0);
        dv_out : out std_logic
    );
end component;

component reflecteur is
    Port (
    data_in : in std_logic_vector(7 downto 0);
    clk : in std_logic;
    data_out : out std_logic_vector(7 downto 0));
end component;

component Bascule is
    Port ( 
        v_in,clk : in std_logic;
        rst : in std_logic;
        v_out : out std_logic
    );
end component;

-- Signaux internes du testbench
signal tmp_1,tmp_2,tmp_3,tmp_4,tmp_5,tmp_6,tmp_7,tmp_8,tmp_9,tmp_10,dv_in_tb,dv_out_tb,dv_1,dv_2,rand_1,rand_2,rand_3,rand_4    : std_logic := '0';
signal data_out_tb,data_in_tb,tmp_out,tmp_in  : std_logic_vector(7 downto 0) := (others => '0');
signal data_1,data_2,data_3,data_4,data_5,data_6 : std_logic_vector(7 downto 0);

begin

DUT : Rotor
        port map (
            clk      => clk,
            rst => rst,
            num_rot => "011",
            notch_pos => std_logic_vector(to_unsigned(21, 8)), -- Encoche sur V
            data_in  => data_in_tb,
            dv_in => dv_in_tb,
            dv_out => dv_1,
            data_out => data_1
        );
        
DUT2 : Rotor
        port map (
            clk      => clk,
            rst => rst,
            num_rot => "010",
            notch_pos => std_logic_vector(to_unsigned(4, 8)), -- Encoche sur E
            data_in  => data_1,
            dv_in => dv_1,
            dv_out => dv_2,
            data_out => data_2
        );   

DUT3 : Rotor
        port map (
            clk      => clk,
            rst => rst,
            num_rot => "001",
            notch_pos => std_logic_vector(to_unsigned(16, 8)), -- Encoche sur Q
            data_in  => data_2,
            dv_in => dv_2,
            dv_out => rand_4,
            data_out => data_3
        );
        
REF : reflecteur
    port map(
        data_in => data_3,
        clk => clk,
        data_out => data_4
    );
    
DUT3R : Rotor_inv
        port map (
            clk      => clk,
            rst => rst,
            num_rot => "001",
            notch_pos => std_logic_vector(to_unsigned(16, 8)), -- Encoche sur Q
            data_in  => data_4,
            dv_in => dv_2,
            dv_out => rand_1,
            data_out => data_5
        );
        
DUT2R : Rotor_inv
        port map (
            clk      => clk,
            rst => rst,
            num_rot => "010",
            notch_pos => std_logic_vector(to_unsigned(4, 8)), -- Encoche sur E
            data_in  => data_5,
            dv_in => dv_1,
            dv_out => rand_2,
            data_out => data_6
        );
        
        
DUTR : Rotor_inv
        port map (
            clk      => clk,
            rst => rst,
            num_rot => "011",
            notch_pos => std_logic_vector(to_unsigned(21, 8)), -- Encoche sur V
            data_in  => data_6,
            dv_in => dv_in_tb,
            dv_out => rand_3,
            data_out => data_out_tb
        );
        
tempo_1 : Bascule
    Port map(
        clk => clk,
        rst => rst,
        v_in => dv_in_tb,
        v_out => tmp_1);

tempo_2 : Bascule
    Port map(
        clk => clk,
        v_in => tmp_1,
        rst => rst,
        v_out => tmp_2);

tempo_3 : Bascule
    Port map(
        clk => clk,
        rst => rst,
        v_in => tmp_2,
        v_out => tmp_3);    

tempo_4 : Bascule
    Port map(
        clk => clk,
        v_in => tmp_3,
        rst => rst,
        v_out => tmp_4);

tempo_5 : Bascule
    Port map(
        clk => clk,
        rst => rst,
        v_in => tmp_4,
        v_out => tmp_5);

tempo_6 : Bascule
    Port map(
        clk => clk,
        rst => rst,
        v_in => tmp_5,
        v_out => tmp_6);

tempo_7 : Bascule
    Port map(
        clk => clk,
        rst => rst,
        v_in => tmp_6,
        v_out => tmp_7);

tempo_8 : Bascule
    Port map(
        clk => clk,
        rst => rst,
        v_in => tmp_7,
        v_out => tmp_8);
        
tempo_9 : Bascule
    Port map(
        clk => clk,
        rst => rst,
        v_in => tmp_8,
        v_out => tmp_9);
        
tempo_10 : Bascule
    Port map(
        clk => clk,
        rst => rst,
        v_in => tmp_9,
        v_out => dv_out_tb);
               

process( clk)
begin
    if(rising_edge(clk)) then
        if(enable = '1') then
            tmp_in <= stream_in;
        else 
            tmp_in <= tmp_in;
        end if;
            data_in_tb <= tmp_in;
    end if;
    
end process;

process(clk)
begin
    if(rising_edge(clk)) then
        dv_in_tb <= enable;
    end if;
end process;

process(clk)
begin
    if(rising_edge(clk)) then
        if(tmp_8 = '1') then
            tmp_out <= data_out_tb;
        else 
            tmp_out <= tmp_out;
        end if;
        stream_out <=  tmp_out;
    end if;

end process;

process(clk)
begin
    if(rising_edge(clk)) then
        data_valid <= dv_out_tb;
    end if;
end process;

end Behavioral;