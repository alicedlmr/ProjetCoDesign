library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2s_axis_tx is
    port (
        -- Signaux Physiques vers le Codec
        sdata_out      : out std_logic;
        
        -- Signaux de synchro (partagés avec le Receiver)
        bclk_en        : in  std_logic; 
        lrclk_reg      : in  std_logic;
        
        -- Interface AXI-Stream Slave (reçoit du DMA ou du Receiver)
        s_axis_aclk    : in  std_logic;
        s_axis_aresetn : in  std_logic;
        s_axis_tdata   : in  std_logic_vector(31 downto 0);
        s_axis_tvalid  : in  std_logic;
        s_axis_tready  : out std_logic
    );
end i2s_axis_tx;

architecture rtl of i2s_axis_tx is
    signal tx_reg        : std_logic_vector(31 downto 0) := (others => '0');
    signal bit_cnt       : integer range 0 to 31 := 0;
    signal lrclk_delayed : std_logic := '0';
    signal tready_int    : std_logic := '0';
begin

    process(s_axis_aclk)
    begin
        if rising_edge(s_axis_aclk) then
            if s_axis_aresetn = '0' then
                tx_reg <= (others => '0');
                bit_cnt <= 0;
                tready_int <= '1';
                sdata_out <= '0';
            else
                lrclk_delayed <= lrclk_reg;

                -- Détection du début d'un nouveau canal (Changement de LRCLK)
                if (lrclk_reg /= lrclk_delayed) then
                    -- Si une donnée est valide sur le bus, on la charge
                    if s_axis_tvalid = '1' then
                        tx_reg <= s_axis_tdata;
                        tready_int <= '1'; -- On accepte la donnée
                    end if;
                    bit_cnt <= 31; -- On se prépare à envoyer le MSB
                
                elsif bclk_en = '1' then
                    tready_int <= '0'; -- Occupé à sérialiser
                    -- Sortie du bit actuel (MSB first)
                    sdata_out <= tx_reg(bit_cnt);
                    
                    if bit_cnt > 0 then
                        bit_cnt <= bit_cnt - 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    s_axis_tready <= tready_int;

end rtl;