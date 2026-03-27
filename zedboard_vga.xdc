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
set_property PACKAGE_PIN V20 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN U20 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN V19 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN V18 [get_ports {vga_r[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[*]}]

# ----------------------------------------------------------------
# VGA - Vert (4 bits)
# ----------------------------------------------------------------
set_property PACKAGE_PIN AB22 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN AA22 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN AB21 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN AA21 [get_ports {vga_g[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[*]}]

# ----------------------------------------------------------------
# VGA - Bleu (4 bits)
# ----------------------------------------------------------------
set_property PACKAGE_PIN Y21  [get_ports {vga_b[0]}]
set_property PACKAGE_PIN Y20  [get_ports {vga_b[1]}]
set_property PACKAGE_PIN AB20 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN AB19 [get_ports {vga_b[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[*]}]