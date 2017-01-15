onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+axi_traffic_gen_0 -L xil_defaultlib -L xpm -L dist_mem_gen_v8_0_11 -L blk_mem_gen_v8_3_4 -L lib_bmg_v1_0_6 -L lib_cdc_v1_0_2 -L axi_traffic_gen_v2_0_11 -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.axi_traffic_gen_0 xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {axi_traffic_gen_0.udo}

run -all

endsim

quit -force
