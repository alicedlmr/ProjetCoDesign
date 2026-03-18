library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_i2s_axis is
end tb_i2s_axis;

architecture bhv of tb_i2s_axis is
    -- Signaux pour l'IP
    signal bclk      : std_logic := '0';
    signal lrclk     : std_logic := '0';
    signal sdata     : std_logic := '0';
    signal aclk      : std_logic := '0';
    signal aresetn   : std_logic := '0';
    signal tdata     : std_logic_vector(31 downto 0);
    signal tvalid    : std_logic;
    signal tlast     : std_logic;
    signal tready    : std_logic := '1';

    -- Données de test
    constant TEST_LEFT  : std_logic_vector(31 downto 0) := x"A5A5A5A5";
    constant TEST_RIGHT : std_logic_vector(31 downto 0) := x"12345678";

    -- Génération des horloges
    -- T = 1 / 22 500 000 = 44.444 ns
    constant ACLK_PERIOD : time := 44.44 ns; -- 22.5 MHz

    -- BCLK = 44100 * 64 = 2.8224 MHz
    -- T_bclk = 1 / 2 822 400 = 354.3 ns
    constant BCLK_PERIOD : time := 354.3 ns;

begin
    -- Instanciation de IP
    DUT : entity work.i2s_axis
        port map (
            bclk           => bclk,
            lrclk          => lrclk,
            sdata          => sdata,
            m_axis_aclk    => aclk,
            m_axis_aresetn => aresetn,
            m_axis_tdata   => tdata,
            m_axis_tvalid  => tvalid,
            m_axis_tlast   => tlast,
            m_axis_tready  => tready
        );

    aclk <= not aclk after ACLK_PERIOD / 2;
    bclk <= not bclk after BCLK_PERIOD / 2;

    -- Processus de stimulation
    process
    begin
        -- Initialisation
        aresetn <= '0';
        sdata   <= '0';
        lrclk   <= '0';
        wait for 100 ns;
        aresetn <= '1';
        wait until falling_edge(bclk);

        -----------------------------------------------------------
        -- ENVOI CANAL GAUCHE (LRCLK = 0)
        -----------------------------------------------------------
        lrclk <= '0';
        -- En I2S, on attend 1 cycle de BCLK après le front de LRCLK
        wait until falling_edge(bclk); 
        
        for i in 31 downto 0 loop
            sdata <= TEST_LEFT(i); -- Envoi du bit MSB vers LSB
            wait until falling_edge(bclk);
        end loop;

        -----------------------------------------------------------
        -- ENVOI CANAL DROIT (LRCLK = 1)
        -----------------------------------------------------------
        lrclk <= '1';
        -- On attend encore 1 cycle de BCLK (règle I2S)
        wait until falling_edge(bclk);
        
        for i in 31 downto 0 loop
            sdata <= TEST_RIGHT(i);
            wait until falling_edge(bclk);
        end loop;

        -- Fin de trame, retour au repos
        lrclk <= '0';
        wait for 2 us;
        
        assert false report "Simulation finie" severity failure;
    end process;

end bhv;