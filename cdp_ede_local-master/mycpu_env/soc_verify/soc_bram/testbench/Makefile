.PHONY: iverilog wave clean

IVERILOG_DIR   := project/loongson.sim/sim_1/behav/iverilog
CPU_SOURCES    := $(wildcard ../../../myCPU/*.v)
SOC_SOURCES    := $(wildcard ../rtl/*.v ../rtl/*/*.v)
TEST_SOURCES   := sync_ram.v mycpu_tb.v
IVERILOG_FLAGS := -g2012 -Wall

iverilog: $(IVERILOG_DIR)/gettrace
	cd $(IVERILOG_DIR) && vvp ./gettrace

wave: $(IVERILOG_DIR)/gettrace
	cd $(IVERILOG_DIR) && vvp ./gettrace +DUMP_WAVE

$(IVERILOG_DIR)/gettrace: $(CPU_SOURCES) $(SOC_SOURCES) $(TEST_SOURCES)
	mkdir -p $(IVERILOG_DIR)
	iverilog $(IVERILOG_FLAGS) -o $@ $(CPU_SOURCES) $(SOC_SOURCES) $(TEST_SOURCES) -I ../../../myCPU/

clean:
	rm -rf ./project
