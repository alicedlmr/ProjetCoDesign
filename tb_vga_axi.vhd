library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_vga_axi is
end entity tb_vga_axi;

architecture sim of tb_vga_axi is

    -- -------------------------------------------------------
    -- Constantes temporelles (65 MHz -> periode ~ 15.38 ns)
    -- -------------------------------------------------------
    constant CLK_PERIOD : time := 15.38 ns;

    -- Timings VGA 1024x768 @ 60 Hz
    constant H_VISIBLE : integer := 1024;
    constant H_FRONT   : integer := 24;
    constant H_SYNC    : integer := 136;
    constant H_BACK    : integer := 160;
    constant H_TOTAL   : integer := 1344;

    constant V_VISIBLE : integer := 768;
    constant V_FRONT   : integer := 3;
    constant V_SYNC    : integer := 6;
    constant V_BACK    : integer := 29;
    constant V_TOTAL   : integer := 806;

    -- -------------------------------------------------------
    -- Signaux DUT
    -- -------------------------------------------------------
    signal clk            : std_logic := '0';
    signal rst            : std_logic := '1';

    signal s_axis_tdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axis_tvalid  : std_logic;   -- driver UNIQUE : processus source
    signal s_axis_tready  : std_logic;

    signal vga_hsync      : std_logic;
    signal vga_vsync      : std_logic;
    signal vga_r          : std_logic_vector(3 downto 0);
    signal vga_g          : std_logic_vector(3 downto 0);
    signal vga_b          : std_logic_vector(3 downto 0);

    -- -------------------------------------------------------
    -- Signal de controle du flux AXI (pilote par le stimulus)
    -- Permet d'activer/desactiver tvalid SANS creer
    -- un second driver sur s_axis_tvalid.
    -- -------------------------------------------------------
    signal tvalid_gate : std_logic := '1';

    -- -------------------------------------------------------
    -- Compteurs internes pour verification
    -- -------------------------------------------------------
    signal hsync_fall_count : integer := 0;
    signal vsync_fall_count : integer := 0;
    signal hsync_prev       : std_logic := '1';
    signal vsync_prev       : std_logic := '1';

    -- -------------------------------------------------------
    -- Compteur de pixels acceptes
    -- -------------------------------------------------------
    signal pixel_count : integer := 0;

begin

    -- -------------------------------------------------------
    -- Horloge 65 MHz
    -- -------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    -- -------------------------------------------------------
    -- Instanciation DUT
    -- -------------------------------------------------------
    DUT : entity work.vga_axi
        port map (
            clk           => clk,
            rst           => rst,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            vga_hsync     => vga_hsync,
            vga_vsync     => vga_vsync,
            vga_r         => vga_r,
            vga_g         => vga_g,
            vga_b         => vga_b
        );

    -- -------------------------------------------------------
    -- Source AXI Stream (SEUL driver de s_axis_tvalid)
    -- Envoie une couleur incrementale, gere tvalid_gate.
    -- -------------------------------------------------------
    process(clk)
        variable color : unsigned(11 downto 0) := (others => '0');
    begin
        if rising_edge(clk) then
            if rst = '1' then
                s_axis_tdata  <= (others => '0');
                s_axis_tvalid <= '0';
                color         := (others => '0');
            else
                -- tvalid_gate permet au processus stimulus de couper le flux
                -- sans creer un second driver sur s_axis_tvalid
                s_axis_tvalid <= tvalid_gate;

                if tvalid_gate = '1' then
                    s_axis_tdata(11 downto 0)  <= std_logic_vector(color);
                    s_axis_tdata(31 downto 12) <= (others => '0');
                    if s_axis_tready = '1' then
                        color := color + 1;
                    end if;
                else
                    s_axis_tdata <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------
    -- Comptage des fronts descendants des syncs (monitoring)
    -- -------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            hsync_prev <= vga_hsync;
            vsync_prev <= vga_vsync;

            if hsync_prev = '1' and vga_hsync = '0' then
                hsync_fall_count <= hsync_fall_count + 1;
            end if;

            if vsync_prev = '1' and vga_vsync = '0' then
                vsync_fall_count <= vsync_fall_count + 1;
            end if;

            if s_axis_tready = '1' and s_axis_tvalid = '1' then
                pixel_count <= pixel_count + 1;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------
    -- Stimulus principal + auto-verification
    -- -------------------------------------------------------
    process
        variable hsync_snap : integer := 0;
        variable vsync_snap : integer := 0;
        variable pixel_snap : integer := 0;
    begin
        -- =================================================
        -- TEST 1 : Reset
        -- =================================================
        report "=== TEST 1 : Reset ==========";
        tvalid_gate <= '1';
        rst <= '1';
        wait for CLK_PERIOD * 5;
        wait until rising_edge(clk);

        assert vga_r = "0000" and vga_g = "0000" and vga_b = "0000"
            report "FAIL TEST 1 : RGB non nul pendant reset"
            severity failure;
        report "PASS TEST 1 : RGB = 0 pendant reset";

        -- =================================================
        -- TEST 2 : Sortie du reset -> tready = 1
        -- =================================================
        report "=== TEST 2 : Sortie du reset ==========";
        rst <= '0';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        assert s_axis_tready = '1'
            report "FAIL TEST 2 : tready = 0 juste apres reset"
            severity failure;
        report "PASS TEST 2 : tready = 1 en zone visible";

        -- =================================================
        -- TEST 3 : Timing hsync
        -- =================================================
        report "=== TEST 3 : Timing hsync ==========";
        wait for CLK_PERIOD * (H_VISIBLE + H_FRONT);
        wait until falling_edge(vga_hsync);

        assert s_axis_tready = '0'
            report "FAIL TEST 3 : tready = 1 pendant hsync"
            severity failure;
        report "PASS TEST 3 : tready = 0 pendant le blanking horizontal";

        wait until rising_edge(vga_hsync);
        report "PASS TEST 3 : Impulsion hsync detectee";

        -- =================================================
        -- TEST 4 : Retour zone visible apres back porch
        -- =================================================
        report "=== TEST 4 : Retour zone visible ==========";
        wait for CLK_PERIOD * H_BACK;
        wait until rising_edge(clk);

        assert s_axis_tready = '1'
            report "FAIL TEST 4 : tready = 0 en zone visible (apres back porch)"
            severity failure;
        report "PASS TEST 4 : tready = 1 en zone visible (nouvelle ligne)";

        -- =================================================
        -- TEST 5 : Comptage des syncs sur 2 trames completes
        -- =================================================
        report "=== TEST 5 : Comptage des syncs sur 2 trames ==========";

        -- Repartir d'un etat propre pour le DUT
        rst <= '1';
        wait until rising_edge(clk);
        rst <= '0';
        -- Attendre un cycle pour que le DUT soit stable
        wait until rising_edge(clk);

        -- On se synchronise sur le debut d'une trame via vsync
        -- => robuste, independant de la phase de depart
        wait until falling_edge(vga_vsync);

        -- Snapshot pris exactement au debut de la trame 1
        hsync_snap := hsync_fall_count;
        vsync_snap := vsync_fall_count;
        pixel_snap := pixel_count;

        -- Attente event-based : 2 trames = 2 fronts descendants vsync
        -- Beaucoup plus robuste qu'un wait for a base de cycles
        wait until falling_edge(vga_vsync);  -- fin trame 1
        wait until falling_edge(vga_vsync);  -- fin trame 2

        -- Delta vsync = 2
        assert (vsync_fall_count - vsync_snap) = 2
            report "FAIL TEST 5 : fronts vsync = " &
                   integer'image(vsync_fall_count - vsync_snap) & " (attendu 2)"
            severity failure;
        report "PASS TEST 5 : 2 trames vsync detectees";

        -- Delta hsync = 2 * V_TOTAL = 1612
        assert (hsync_fall_count - hsync_snap) = 2 * V_TOTAL
            report "FAIL TEST 5 : fronts hsync = " &
                   integer'image(hsync_fall_count - hsync_snap) &
                   " (attendu " & integer'image(2 * V_TOTAL) & ")"
            severity failure;
        report "PASS TEST 5 : " & integer'image(hsync_fall_count - hsync_snap) &
               " fronts hsync (attendu " & integer'image(2 * V_TOTAL) & ")";

        -- =================================================
        -- TEST 6 : Pixels acceptes sur les 2 trames
        -- =================================================
        report "=== TEST 6 : Nombre de pixels acceptes ==========";
        assert (pixel_count - pixel_snap) = 2 * H_VISIBLE * V_VISIBLE
            report "FAIL TEST 6 : pixel_count = " &
                   integer'image(pixel_count - pixel_snap) & " (attendu " &
                   integer'image(2 * H_VISIBLE * V_VISIBLE) & ")"
            severity failure;
        report "PASS TEST 6 : " & integer'image(pixel_count - pixel_snap) &
               " pixels acceptes sur 2 trames";

        -- =================================================
        -- TEST 7 : Flux coupe (tvalid_gate = 0) -> RGB noir
        -- =================================================
        report "=== TEST 7 : Flux coupe (tvalid_gate=0) ==========";
        rst <= '1';
        wait until rising_edge(clk);
        rst <= '0';
        -- On coupe le flux via tvalid_gate (pas de second driver sur tvalid)
        tvalid_gate <= '0';

        wait for CLK_PERIOD * 2;
        wait until rising_edge(clk);

        assert vga_r = "0000" and vga_g = "0000" and vga_b = "0000"
            report "FAIL TEST 7 : RGB non nul quand tvalid = 0"
            severity failure;
        report "PASS TEST 7 : RGB = 0 quand tvalid = 0 (pas de donnee)";

        -- =================================================
        -- FIN
        -- =================================================
        report "=== TOUS LES TESTS PASSES ===";
        wait;
    end process;

end architecture sim;