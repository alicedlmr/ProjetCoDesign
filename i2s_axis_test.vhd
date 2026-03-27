library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_axis is
    generic (
        DATA_WIDTH : integer := 32
    );
    port (
        -- Signaux Physiques vers le Codec Audio de la Zedboard
        bclk           : out std_logic; 
        lrclk          : out std_logic; 
        sdata          : in  std_logic; 
        
        -- Interface AXI-Stream (vers le DMA / PS)
        m_axis_aclk    : in  std_logic; -- Doit être à 22.579 MHz
        m_axis_aresetn : in  std_logic; 
        m_axis_tdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_axis_tvalid  : out std_logic;
        m_axis_tlast   : out std_logic; 
        m_axis_tready  : in  std_logic 
    );
end i2s_axis;

architecture rtl of i2s_axis is
    -- Compteurs pour la génération d'horloge
    signal cnt_bclk   : integer range 0 to 3 := 0;   -- Divise 22.5MHz par 8 pour BCLK
    signal cnt_lrclk  : integer range 0 to 255 := 0; -- Divise pour LRCLK (44.1kHz)
    
    -- Signaux d'horloge internes
    signal bclk_reg   : std_logic := '0';
    signal lrclk_reg  : std_logic := '0';
    signal bclk_en    : std_logic := '0'; -- Impulsion d'activation (Enable)
    
    -- Registres de données
    signal shift_reg           : std_logic_vector(31 downto 0) := (others => '0');
    signal data_ready_buffer   : std_logic_vector(31 downto 0) := (others => '0');
    signal lrclk_delayed       : std_logic := '0';
    signal axis_valid_internal : std_logic := '0';

begin

    ----------------------------------------------------------------------------
    -- 1. GENERATEUR D'HORLOGES ET D'ENABLE
    ----------------------------------------------------------------------------
    process(m_axis_aclk)
    begin
        if rising_edge(m_axis_aclk) then
            if m_axis_aresetn = '0' then
                cnt_bclk  <= 0;
                cnt_lrclk <= 0;
                bclk_reg  <= '0';
                lrclk_reg <= '0';
                bclk_en   <= '0';
            else
                -- Génération du front de BCLK (Toggle toutes les 4 aclk)
                if cnt_bclk = 3 then
                    cnt_bclk <= 0;
                    bclk_reg <= not bclk_reg;
                    -- On génère un "Enable" uniquement sur le front montant de BCLK
                    if bclk_reg = '0' then 
                        bclk_en <= '1'; 
                    else 
                        bclk_en <= '0'; 
                    end if;
                else
                    cnt_bclk <= cnt_bclk + 1;
                    bclk_en  <= '0';
                end if;

                -- Génération de LRCLK (Bascule tous les 256 aclk)
                if cnt_lrclk = 255 then
                    cnt_lrclk <= 0;
                    lrclk_reg <= not lrclk_reg;
                else
                    cnt_lrclk <= cnt_lrclk + 1;
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- 2. CAPTURE DES DONNEES (Synchrone ACLK, rythmée par BCLK_EN)
    ----------------------------------------------------------------------------
    process(m_axis_aclk)
    begin
        if rising_edge(m_axis_aclk) then
            if m_axis_aresetn = '0' then
                shift_reg <= (others => '0');
                axis_valid_internal <= '0';
                lrclk_delayed <= '0';
                data_ready_buffer <= (others => '0');
            else
                -- On ne travaille que lorsque BCLK_EN est actif (front montant virtuel de BCLK)
                if bclk_en = '1' then
                    lrclk_delayed <= lrclk_reg;
                    shift_reg     <= shift_reg(30 downto 0) & sdata;

                    -- Si LRCLK vient de changer, l'échantillon précédent est complet
                    if (lrclk_reg /= lrclk_delayed) then
                        data_ready_buffer <= shift_reg;
                        axis_valid_internal <= '1';
                    end if;
                end if;

                -- Gestion du Handshake AXI-Stream (indépendant de BCLK_EN)
                if axis_valid_internal = '1' and m_axis_tready = '1' then
                    axis_valid_internal <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Sorties Physiques
    bclk  <= bclk_reg;
    lrclk <= lrclk_reg;

    -- Sorties AXI-Stream
    m_axis_tdata  <= data_ready_buffer;
    m_axis_tvalid <= axis_valid_internal;
    -- TLAST sur le canal Droit (LRCLK delayed = '1')
    m_axis_tlast  <= '1' when (lrclk_delayed = '1' and axis_valid_internal = '1') else '0';

end rtl;