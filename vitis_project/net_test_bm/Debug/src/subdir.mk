C_SRCS += ../src/main.c ../src/echo.c ../src/platform_zynqmp.c
OBJS += ./src/main.o ./src/echo.o ./src/platform_zynqmp.o
C_DEPS += ./src/main.d ./src/echo.d ./src/platform_zynqmp.d

src/%.o: ../src/%.c
	@echo 'Building file: $<'
	aarch64-none-elf-gcc -Wall -O0 -g3 -c -fmessage-length=0 -MT"$@" -ID:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/zynq_imgproc_platform/export/zynq_imgproc_platform/sw/zynq_imgproc_platform/standalone_psu_cortexa53_0/bspinclude/include -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
