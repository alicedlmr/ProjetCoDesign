library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_axis is
    generic (
        DATA_WIDTH : integer := 32
    );
    port (
        bclk           : in  std_logic; -- Bit Clock de l'I2S
        lrclk          : in  std_logic; -- Left-Right Clock de l'I2S
        sdata          : in  std_logic; -- Serial Data de l'I2S
        m_axis_aclk    : in  std_logic; -- Horloge pour AXI-Stream
        m_axis_aresetn : in  std_logic; -- Reset actif bas
        m_axis_tdata   : out std_logic_vector(DATA_WIDTH-1 downto 0); -- Données de sortie de l'AXI-Stream
        m_axis_tvalid  : out std_logic; -- signal de validité pour l'AXI-Stream
        m_axis_tlast   : out std_logic; -- fin de trame (dernier mot du paquet )
        m_axis_tready  : in  std_logic -- signal de prêt du Master AXI-Stream (DMA)
    );
end i2s_axis;

architecture rtl of i2s_axis is
    signal shift_reg           : std_logic_vector(31 downto 0) := (others => '0');
    signal data_ready_buffer   : std_logic_vector(31 downto 0) := (others => '0');
    signal lrclk_delayed       : std_logic := '0';
    signal axis_valid_internal : std_logic := '0';
begin

    -- Processus de capture I2S synchrone sur BCLK
    process(bclk)
    begin
        if rising_edge(bclk) then
            if m_axis_aresetn = '0' then
                shift_reg <= (others => '0');
                axis_valid_internal <= '0';
                lrclk_delayed <= '0';
                data_ready_buffer <= (others => '0');
            else
                -- Retard pour détecter le front de LRCLK
                lrclk_delayed <= lrclk;
                
                -- On décale les bits en permanence
                shift_reg <= shift_reg(30 downto 0) & sdata;

                -- Détection du changement de canal (Fin d'un échantillon)
                -- En I2S, on transfère la donnée 1 cycle après le front de LRCLK
                if (lrclk /= lrclk_delayed) then
                    data_ready_buffer <= shift_reg;
                    axis_valid_internal <= '1';
                elsif m_axis_tready = '1' then
                    -- On baisse Valid dès que le Master AXI-S a accepté la donnée
                    axis_valid_internal <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Assignations de sortie
    m_axis_tdata  <= data_ready_buffer;
    m_axis_tvalid <= axis_valid_internal;
    
    -- TLAST = '1' quand on envoie le canal DROIT (souvent LRCLK = '1')
    m_axis_tlast  <= '1' when (lrclk_delayed = '1' and axis_valid_internal = '1') else '0';

end rtl;