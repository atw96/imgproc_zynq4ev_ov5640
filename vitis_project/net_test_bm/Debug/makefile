################################################################################
RM := rm -rf
-include objects.mk
-include src/subdir.mk

all: net_test_bm.elf secondary-outputs

net_test_bm.elf: $(OBJS) ../src/lscript.ld $(USER_OBJS)
	@echo 'Building target: $@'
	aarch64-none-elf-gcc -Wl,-T -Wl,../src/lscript.ld -LD:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/zynq_imgproc_platform/export/zynq_imgproc_platform/sw/zynq_imgproc_platform/standalone_psu_cortexa53_0/bsplib/lib -o "net_test_bm.elf" $(OBJS) $(USER_OBJS) $(LIBS)

net_test_bm.elf.size: net_test_bm.elf
	aarch64-none-elf-size net_test_bm.elf | tee "net_test_bm.elf.size"

secondary-outputs: net_test_bm.elf.size

clean:
	-$(RM) $(OBJS) $(C_DEPS) net_test_bm.elf net_test_bm.elf.size

.PHONY: all clean
