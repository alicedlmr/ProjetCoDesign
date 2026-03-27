library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- ---------------------------------------------------------------
-- Top-level de TEST pour valider vga_axi sur la Zedboard
-- sans DMA : un generateur de barres de couleurs alimente
-- directement l'IP vga_axi via un AXI Stream local.
--
-- Entrees physiques :
--   sys_clk   : 100 MHz (oscillateur sur-board de la Zedboard)
--   sys_rst_n : bouton reset actif bas (BTNC ou switch)
--
-- Sorties vers connecteur VGA de la Zedboard :
--   vga_hs, vga_vs, vga_r(3:0), vga_g(3:0), vga_b(3:0)
-- ---------------------------------------------------------------

entity top_vga_test is
    port (
        sys_clk   : in  std_logic;   -- 100 MHz
        sys_rst_n : in  std_logic;   -- reset actif bas (ex: BTNC)

        vga_hs    : out std_logic;
        vga_vs    : out std_logic;
        vga_r     : out std_logic_vector(3 downto 0);
        vga_g     : out std_logic_vector(3 downto 0);
        vga_b     : out std_logic_vector(3 downto 0)
    );
end entity top_vga_test;

architecture rtl of top_vga_test is

    -- -----------------------------------------------------------
    -- Composants
    -- -----------------------------------------------------------

    -- PLL : genere 65 MHz a partir de 100 MHz
    -- A remplacer par le composant Clocking Wizard genere par Vivado
    component clk_wiz_65mhz
        port (
            clk_in1  : in  std_logic;   -- 100 MHz
            clk_out1 : out std_logic;   -- 65 MHz
            locked   : out std_logic;
            reset    : in  std_logic
        );
    end component;

    component vga_axi
        port (
            clk           : in  std_logic;
            rst           : in  std_logic;
            s_axis_tdata  : in  std_logic_vector(31 downto 0);
            s_axis_tvalid : in  std_logic;
            s_axis_tready : out std_logic;
            vga_hsync     : out std_logic;
            vga_vsync     : out std_logic;
            vga_r         : out std_logic_vector(3 downto 0);
            vga_g         : out std_logic_vector(3 downto 0);
            vga_b         : out std_logic_vector(3 downto 0)
        );
    end component;

    -- -----------------------------------------------------------
    -- Signaux internes
    -- -----------------------------------------------------------
    signal clk_65     : std_logic;
    signal pll_locked : std_logic;
    signal rst        : std_logic;   -- actif haut vers vga_axi

    -- AXI Stream local (pattern generator -> vga_axi)
    signal tdata      : std_logic_vector(31 downto 0);
    signal tvalid     : std_logic;
    signal tready     : std_logic;

    -- Compteurs de position pixel (copies internes pour le generateur)
    -- On reutilise les memes constantes que dans vga_axi
    constant H_VISIBLE : integer := 1024;
    constant H_TOTAL   : integer := 1344;
    constant V_VISIBLE : integer := 768;
    constant V_TOTAL   : integer := 806;

    signal h_count : unsigned(10 downto 0) := (others => '0');
    signal v_count : unsigned(10 downto 0) := (others => '0');
    signal visible : std_logic;

    -- Couleur generee par le pattern generator
    signal pixel_color : std_logic_vector(11 downto 0);  -- RGB444

begin

    -- -----------------------------------------------------------
    -- Reset : actif haut pour vga_axi, derive du bouton actif bas
    -- et du signal locked de la PLL (on reste en reset tant que
    -- la PLL n'est pas stable).
    -- -----------------------------------------------------------
    rst <= (sys_rst_n) or (not pll_locked);

    -- -----------------------------------------------------------
    -- PLL Clocking Wizard (genere avec Vivado IP Catalog)
    -- Nom du composant : clk_wiz_65mhz
    -- Input  : 100 MHz
    -- Output : 65 MHz
    -- -----------------------------------------------------------
    U_PLL : clk_wiz_65mhz
        port map (
            clk_in1  => sys_clk,
            clk_out1 => clk_65,
            locked   => pll_locked,
            reset    => sys_rst_n   -- reset actif haut pour la PLL
        );

    -- -----------------------------------------------------------
    -- Instanciation vga_axi
    -- -----------------------------------------------------------
    U_VGA : vga_axi
        port map (
            clk           => clk_65,
            rst           => rst,
            s_axis_tdata  => tdata,
            s_axis_tvalid => tvalid,
            s_axis_tready => tready,
            vga_hsync     => vga_hs,
            vga_vsync     => vga_vs,
            vga_r         => vga_r,
            vga_g         => vga_g,
            vga_b         => vga_b
        );

    -- -----------------------------------------------------------
    -- Generateur de pattern : barres de couleurs verticales
    -- Le pattern generator a ses propres compteurs h/v pour
    -- savoir ou il en est dans la trame et calculer la couleur.
    -- -----------------------------------------------------------

    -- Compteurs locaux (meme logique que dans vga_axi)
    process(clk_65)
    begin
        if rising_edge(clk_65) then
            if rst = '1' then
                h_count <= (others => '0');
                v_count <= (others => '0');
            else
                if h_count = H_TOTAL - 1 then
                    h_count <= (others => '0');
                    if v_count = V_TOTAL - 1 then
                        v_count <= (others => '0');
                    else
                        v_count <= v_count + 1;
                    end if;
                else
                    h_count <= h_count + 1;
                end if;
            end if;
        end if;
    end process;

    visible <= '1' when (h_count < H_VISIBLE) and (v_count < V_VISIBLE)
               else '0';

    -- tvalid toujours a 1 : le generateur a toujours une couleur disponible
    tvalid <= '1';

    -- -----------------------------------------------------------
    -- Pattern : 8 barres verticales de couleurs
    -- La largeur de chaque barre = H_VISIBLE / 8 = 128 pixels
    --
    -- Barre 0 : Blanc   FF_F
    -- Barre 1 : Jaune   FF_0
    -- Barre 2 : Cyan    0F_F
    -- Barre 3 : Vert    0F_0
    -- Barre 4 : Magenta F0_F
    -- Barre 5 : Rouge   F0_0
    -- Barre 6 : Bleu    00_F
    -- Barre 7 : Noir    00_0
    -- -----------------------------------------------------------
    process(h_count)
        variable barre : unsigned(2 downto 0);
    begin
        barre := h_count(9 downto 7);  -- divise par 128 (= 1024/8)
        case barre is
            when "000" => pixel_color <= x"FFF";  -- Blanc
            when "001" => pixel_color <= x"FF0";  -- Jaune
            when "010" => pixel_color <= x"0FF";  -- Cyan
            when "011" => pixel_color <= x"0F0";  -- Vert
            when "100" => pixel_color <= x"F0F";  -- Magenta
            when "101" => pixel_color <= x"F00";  -- Rouge
            when "110" => pixel_color <= x"00F";  -- Bleu
            when others => pixel_color <= x"000"; -- Noir
        end case;
    end process;

    -- Mise en forme tdata : bits 11:0 = RGB444, bits 31:12 = 0
    tdata(11 downto 0)  <= pixel_color;
    tdata(31 downto 12) <= (others => '0');

end architecture rtl;
