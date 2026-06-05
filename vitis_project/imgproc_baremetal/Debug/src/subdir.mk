################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
LD_SRCS += \
../src/lscript.ld 

C_SRCS += \
../src/eth_stream.c \
../src/main.c \
../src/ov5640_sensor.c \
../src/pl_iic_ov5640.c \
../src/pl_isp.c \
../src/platform.c \
../src/platform_zynqmp.c 

OBJS += \
./src/eth_stream.o \
./src/main.o \
./src/ov5640_sensor.o \
./src/pl_iic_ov5640.o \
./src/pl_isp.o \
./src/platform.o \
./src/platform_zynqmp.o 

C_DEPS += \
./src/eth_stream.d \
./src/main.d \
./src/ov5640_sensor.d \
./src/pl_iic_ov5640.d \
./src/pl_isp.d \
./src/platform.d \
./src/platform_zynqmp.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: ARM v8 gcc compiler'
	aarch64-none-elf-gcc -Wall -O0 -g3 -c -fmessage-length=0 -MT"$@" -ID:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/zynq_imgproc_platform/export/zynq_imgproc_platform/sw/zynq_imgproc_platform/standalone_psu_cortexa53_0/bspinclude/include -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


