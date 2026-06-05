path = r"imgproc_baremetal/src/platform_zynqmp.c"
with open(path, "r", encoding="utf-8", errors="replace") as f:
    s = f.read()
old = """void platform_enable_interrupts()
{
	/*
	 * Enable non-critical exceptions.
	 */
	Xil_ExceptionEnableMask(XIL_EXCEPTION_IRQ);
	XScuGic_EnableIntr(INTC_DIST_BASE_ADDR, TIMER_IRPT_INTR);
	XTtcPs_EnableInterrupts(&TimerInstance, XTTCPS_IXR_INTERVAL_MASK);
	XTtcPs_Start(&TimerInstance);
	return;
}

void init_platform()
{
	xil_printf("[PLAT] init_platform start\\r\\n");
	platform_setup_timer();
	platform_setup_interrupts();
	xil_printf("[PLAT] init_platform done\\r\\n");
}"""
new = """void platform_enable_interrupts()
{
}

void init_platform()
{
	xil_printf("[PLAT] poll mode (skip TTC/GIC)\\r\\n");
}"""
assert old in s, "pattern not found"
with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(s.replace(old, new))
print("platform ok")
