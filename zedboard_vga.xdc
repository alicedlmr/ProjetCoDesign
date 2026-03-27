# ================================================================
# Contraintes XDC pour la Zedboard - Test VGA
# Reference : Zedboard Master XDC (Digilent)
# ================================================================

# ----------------------------------------------------------------
# Horloge systeme 100 MHz
# ----------------------------------------------------------------
set_property PACKAGE_PIN Y9 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]
create_clock -period 10.000 -name sys_clk [get_ports sys_clk]

# ----------------------------------------------------------------
# Reset : bouton BTNC (centre) actif haut sur la Zedboard
# On l'utilise en actif bas (sys_rst_n) donc on inverse dans le VHDL
# ----------------------------------------------------------------
set_property PACKAGE_PIN P16 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports sys_rst_n]

# ----------------------------------------------------------------
# VGA - Synchros
# ----------------------------------------------------------------
set_property PACKAGE_PIN AA19 [get_ports vga_hs]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hs]

set_property PACKAGE_PIN Y19 [get_ports vga_vs]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vs]

# ----------------------------------------------------------------
# VGA - Rouge (4 bits)
# ----------------------------------------------------------------
set_property PACKAGE_PIN V20  [get_ports {vga_r[0]}]
set_property PACKAGE_PIN U20  [get_ports {vga_r[1]}]
set_property PACKAGE_PIN AB22 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN AB21 [get_ports {vga_r[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[*]}]

# ----------------------------------------------------------------
# VGA - Vert (4 bits)
# ----------------------------------------------------------------
set_property PACKAGE_PIN AA22 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN R19  [get_ports {vga_g[1]}]
set_property PACKAGE_PIN T19  [get_ports {vga_g[2]}]
set_property PACKAGE_PIN T20  [get_ports {vga_g[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[*]}]

# ----------------------------------------------------------------
# VGA - Bleu (4 bits)
# ----------------------------------------------------------------
set_property PACKAGE_PIN R18  [get_ports {vga_b[0]}]
set_property PACKAGE_PIN T17  [get_ports {vga_b[1]}]
set_property PACKAGE_PIN W20  [get_ports {vga_b[2]}]
set_property PACKAGE_PIN V26  [get_ports {vga_b[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[*]}]

# ----------------------------------------------------------------
# Fausse contrainte pour la clock 65 MHz generee par le Clocking
# Wizard (Vivado la genere automatiquement, mais on la documente)
# ----------------------------------------------------------------
# La contrainte de la clock 65 MHz est normalement auto-derivee
# par Vivado depuis le Clocking Wizard. Si ce n'est pas le cas :
# create_generated_clock -name clk_65 \
#     -source [get_pins U_PLL/clk_in1] \
#     -multiply_by 13 -divide_by 20 \
#     [get_pins U_PLL/clk_out1]
