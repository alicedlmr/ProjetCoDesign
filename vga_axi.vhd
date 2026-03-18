library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_axi is
    port (
        clk   : in std_logic;  -- 65 MHz
        rst   : in std_logic;

        -- AXI Stream en entree (depuis DMA)
        s_axis_tdata  : in  std_logic_vector(31 downto 0);
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;

        -- Signaux VGA vers connecteur
        vga_hsync : out std_logic;
        vga_vsync : out std_logic;
        vga_r     : out std_logic_vector(3 downto 0);
        vga_g     : out std_logic_vector(3 downto 0);
        vga_b     : out std_logic_vector(3 downto 0)
    );
end entity vga_axi;

architecture rtl of vga_axi is

    -- Timings 1024x768 @ 60Hz
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

    -- Compteurs
    signal h_count : unsigned(10 downto 0) := (others => '0');
    signal v_count : unsigned(10 downto 0) := (others => '0');

    -- Zone visible
    signal visible : std_logic;

begin

    -- Compteurs H et V
    process(clk)
    begin
        if rising_edge(clk) then
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

    -- Zone visible
    visible <= '1' when (h_count < H_VISIBLE) and (v_count < V_VISIBLE)
               else '0';

    -- hsync et vsync
    vga_hsync <= '0' when (h_count >= H_VISIBLE + H_FRONT) and
                          (h_count <  H_VISIBLE + H_FRONT + H_SYNC)
                 else '1';

    vga_vsync <= '0' when (v_count >= V_VISIBLE + V_FRONT) and
                          (v_count <  V_VISIBLE + V_FRONT + V_SYNC)
                 else '1';

    -- On accepte un pixel du DMA uniquement quand on est dans la zone visible
    s_axis_tready <= visible;

    -- Sortie RGB
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                vga_r <= (others => '0');
                vga_g <= (others => '0');
                vga_b <= (others => '0');
            else
                if visible = '1' and s_axis_tvalid = '1' then
                    vga_r <= s_axis_tdata(11 downto 8);
                    vga_g <= s_axis_tdata(7  downto 4);
                    vga_b <= s_axis_tdata(3  downto 0);
                else
                    vga_r <= (others => '0');
                    vga_g <= (others => '0');
                    vga_b <= (others => '0');
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
