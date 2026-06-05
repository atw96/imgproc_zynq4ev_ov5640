################################################################
# create_project_ov5640.tcl
# 主自动化脚本 — AXU4EVB + AV5641 OV5640 MIPI ISP 工程
# 用法: vivado -mode batch -source create_project_ov5640.tcl
# 或在 Vivado Tcl Console: source create_project_ov5640.tcl
#
# RTL 布局与 files/sources_1 一致:
#   rtl_top/imgproc_top_ov5640.v (模块 imgproc_top_ov5640)
#   project/src/*.v
#   common/*.v, common/ram/*.v
#
# 封装/引脚：PS MIO 与 doc 原理图 PDF 的对照说明见 create_bd_ov5640.tcl 头部；
#            PL 引脚在 imgproc_axu4evb_ov5640.xdc（原理图 PDF 需人工搜索网络名核对）。
# PS：UART0 MIO42-43；SD1 为 SD 2.0（SLOT_TYPE），MIO39-51 + CD MIO45（详见 create_bd_ov5640.tcl）。
################################################################

# 0. 路径配置
set script_dir  [file dirname [file normalize [info script]]]
set proj_root   [file dirname $script_dir]
set proj_name   "imgproc_axu4evb_ov5640"
set proj_dir    [file normalize "$proj_root/vivado_proj"]
set src_dir     [file normalize "$script_dir/sources_1"]
set constr_xdc  [file normalize "$script_dir/imgproc_axu4evb_ov5640.xdc"]
set bd_script   [file normalize "$script_dir/create_bd_ov5640.tcl"]
set part_name   "xczu4ev-sfvc784-2-i"

if {![file isdirectory $src_dir]} {
    puts "ERROR: sources_1 not found: $src_dir"
    return
}
if {![file exists $bd_script]} {
    puts "ERROR: BD script not found: $bd_script"
    return
}

create_project $proj_name $proj_dir -part $part_name -force
set_property BOARD_PART "" [current_project]
set_property target_language Verilog [current_project]
set_property default_lib xil_defaultlib [current_project]
puts "INFO: Project created — $part_name ($proj_dir)"

set top_v "$src_dir/rtl_top/imgproc_top_ov5640.v"
if {[file exists $top_v]} {
    add_files -norecurse $top_v
} else {
    puts "ERROR: Top RTL not found — $top_v"
}

set proj_src "$src_dir/project/src"
if {[file isdirectory $proj_src]} {
    foreach f [glob -nocomplain -directory $proj_src *.v] {
        add_files -norecurse $f
    }
} else {
    puts "WARN: Directory not found — $proj_src"
}

set common_dir "$src_dir/common"
if {[file isdirectory $common_dir]} {
    foreach f [glob -nocomplain -directory $common_dir *.v] {
        add_files -norecurse $f
    }
}

set ram_dir "$src_dir/common/ram"
if {[file isdirectory $ram_dir]} {
    foreach f [glob -nocomplain -directory $ram_dir *.v] {
        add_files -norecurse $f
    }
}
puts "INFO: RTL sources added from $src_dir"

if {[file exists $constr_xdc]} {
    add_files -fileset constrs_1 -norecurse $constr_xdc
    set constr_obj [get_files -quiet -of_objects [get_filesets constrs_1] "imgproc_axu4evb_ov5640.xdc"]
    if {$constr_obj ne ""} {
        set_property PROCESSING_ORDER LATE $constr_obj
    }
    puts "INFO: Constraints added — $constr_xdc"
} else {
    puts "WARN: XDC not found — $constr_xdc"
}

source $bd_script
puts "INFO: Block Design Tcl sourced"

set bd_file [get_files -quiet zynq_imgproc_bd.bd]
if {$bd_file eq ""} {
    puts "ERROR: zynq_imgproc_bd.bd not in project"
    return
}
if {[catch {generate_target all $bd_file} err]} {
    puts "ERROR: generate_target failed: $err"
    return
}
if {[catch {make_wrapper -files $bd_file -top} err]} {
    puts "ERROR: make_wrapper failed: $err"
    return
}

set wrapper_in_proj [get_files -quiet zynq_imgproc_bd_wrapper.v]
if {$wrapper_in_proj ne ""} {
    puts "INFO: BD Wrapper in project: [lindex $wrapper_in_proj 0]"
} else {
    set wrapper_path ""
    foreach base [list [file join $proj_dir ${proj_name}.srcs] [file join $proj_dir ${proj_name}.gen]] {
        set hdl_dir [file join $base sources_1 bd zynq_imgproc_bd hdl]
        if {![file isdirectory $hdl_dir]} { continue }
        set cand [glob -nocomplain [file join $hdl_dir zynq_imgproc_bd_wrapper.v]]
        if {$cand ne ""} {
            set wrapper_path [lindex $cand 0]
            break
        }
    }
    if {$wrapper_path ne ""} {
        add_files -norecurse $wrapper_path
        puts "INFO: BD Wrapper added from disk: $wrapper_path"
    } else {
        puts "ERROR: zynq_imgproc_bd_wrapper.v not found under .srcs or .gen"
    }
}

set_property top imgproc_top_ov5640 [current_fileset]
if {[catch {update_compile_order -fileset sources_1} err]} {
    puts "WARN: update_compile_order: $err"
}
puts "INFO: Top module set to imgproc_top_ov5640"

set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE Default [get_runs synth_1]
set_property strategy "Performance_ExplorePostRoutePhysOpt" [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
puts "INFO: Synthesis/Implementation strategies configured"

if {[catch {report_ip_status -name ip_status} err]} {
    puts "WARN: report_ip_status skipped: $err"
}

puts ""
puts "Project setup COMPLETE."
