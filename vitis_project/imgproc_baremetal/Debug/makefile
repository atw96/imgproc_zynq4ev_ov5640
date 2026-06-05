################################################################################
# Automatically-generated file. Do not edit!
################################################################################

-include ../makefile.init

RM := rm -rf

# All of the sources participating in the build are defined here
-include sources.mk
-include src/subdir.mk
-include subdir.mk
-include objects.mk

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(S_UPPER_DEPS)),)
-include $(S_UPPER_DEPS)
endif
ifneq ($(strip $(C_DEPS)),)
-include $(C_DEPS)
endif
endif

-include ../makefile.defs

# Add inputs and outputs from these tool invocations to the build variables 
ELFSIZE += \
imgproc_baremetal.elf.size \


# All Target
all: imgproc_baremetal.elf secondary-outputs

# Tool invocations
imgproc_baremetal.elf: $(OBJS) ../src/lscript.ld $(USER_OBJS)
	@echo 'Building target: $@'
	@echo 'Invoking: ARM v8 gcc linker'
	aarch64-none-elf-gcc -Wl,-T -Wl,../src/lscript.ld -LD:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/zynq_imgproc_platform/export/zynq_imgproc_platform/sw/zynq_imgproc_platform/standalone_psu_cortexa53_0/bsplib/lib -o "imgproc_baremetal.elf" $(OBJS) $(USER_OBJS) $(LIBS)
	@echo 'Finished building target: $@'
	@echo ' '

imgproc_baremetal.elf.size: imgproc_baremetal.elf
	@echo 'Invoking: ARM v8 Print Size'
	aarch64-none-elf-size imgproc_baremetal.elf  |tee "imgproc_baremetal.elf.size"
	@echo 'Finished building: $@'
	@echo ' '

# Other Targets
clean:
	-$(RM) $(EXECUTABLES)$(OBJS)$(S_UPPER_DEPS)$(C_DEPS)$(ELFSIZE) imgproc_baremetal.elf
	-@echo ' '

secondary-outputs: $(ELFSIZE)

.PHONY: all clean dependents

-include ../makefile.targets
