vlib work
vcom -93 vga_axi.vhd
vcom -93 tb_vga_axi.vhd
vsim -novopt tb_vga_axi
add wave *
add wave -position end sim:/tb_vga_axi/DUT/*
run -a
