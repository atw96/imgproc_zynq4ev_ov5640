# =============================================================================
# Vitis 2020.1 XSCT — 从本目录的 XSA + .regen_backup 重建 Platform + 裸机 Application
#
# 用法（在已加载 Vitis 环境的 CMD/PowerShell 中）:
#   cd /d <本脚本所在目录>
#   xsct create_vitis_workspace.tcl
#
# 或双击 / 调用: run_xsct_create.bat（需设置 XILINX_VITIS 或已 settings64.bat）
#
# 前置: 本目录下须有
#   - imgproc_top_ov5640.xsa
#   - .regen_backup/imgproc_baremetal_src/*.c *.h（及可选 *.txt）
#
# 说明: lwIP 库名随 BSP 版本可能是 lwip220 / lwip211，脚本会 catch 多试；
#       若仍缺库，请在 Vitis 中打开 Platform → BSP Settings 手动勾选 lwIP RAW API。
# =============================================================================

set script_dir [file dirname [file normalize [info script]]]
cd $script_dir
setws $script_dir

# domain list 返回的条目中，当前活动域名前会带 “*”（仅显示标记，不是真实域名）
proc xsct_normalize_domain_name {raw} {
	set n [string trim $raw]
	if {$n eq ""} {
		return ""
	}
	if {[string index $n 0] eq "*"} {
		set n [string trim [string range $n 1 end]]
	}
	# 若条目含 “NAME  DESCRIPTION” 两列，只取第一列
	set n [lindex [split $n " \t"] 0]
	return $n
}

# Eclipse 元数据里若仍登记 imgproc_baremetal*，仅删磁盘目录会导致 app create 报 “already exists”
set projmeta [file join $script_dir .metadata .plugins org.eclipse.core.resources .projects]
foreach n {imgproc_baremetal imgproc_baremetal_system} {
	set mp [file join $projmeta $n]
	if {[file exists $mp]} {
		puts "INFO: 删除工作区工程登记 $mp"
		file delete -force $mp
	}
}

set xsa [file join $script_dir imgproc_top_ov5640.xsa]
if {![file exists $xsa]} {
	return -code error "XSA 不存在: $xsa\n请将 Vivado 导出的 imgproc_top_ov5640.xsa 放在与本脚本同一目录。"
}

set backup [file join $script_dir .regen_backup imgproc_baremetal_src]
if {![file isdirectory $backup]} {
	return -code error "备份目录不存在: $backup"
}

# 删除旧 Platform / Application 目录（纯文件删除；请勿在 Vitis 打开本 workspace 时运行）
foreach rel {zynq_imgproc_platform imgproc_baremetal imgproc_baremetal_system} {
	set p [file join $script_dir $rel]
	if {[file exists $p]} {
		puts "INFO: 删除旧目录 $p"
		file delete -force $p
	}
}

# 优先一步创建含 A53 standalone 的 platform（2020.1 支持 -proc/-os 时可直接得到 default domain）
puts "INFO: platform create (尝试 -proc psu_cortexa53_0 -os standalone)"
if {[catch {
	platform create -name zynq_imgproc_platform -hw $xsa -proc psu_cortexa53_0 -os standalone
}]} {
	puts "INFO: 回退: platform create 仅 -hw，再手动 domain create"
	platform create -name zynq_imgproc_platform -hw $xsa
}
platform active zynq_imgproc_platform

# 确保存在 A53 standalone domain（否则 platform generate 报 default domain is empty）
set dlist [domain list]
puts "INFO: domain list (create 后): $dlist"

set has_a53 0
foreach d $dlist {
	set dn [xsct_normalize_domain_name $d]
	if {$dn eq ""} {
		continue
	}
	if {[string match *psu_cortexa53_0* $dn] && [string match *standalone* $dn]} {
		set has_a53 1
		break
	}
}
if {!$has_a53} {
	puts "INFO: 未发现 A53 standalone，显式 domain create"
	if {[catch {
		domain create -name standalone_psu_cortexa53_0 -display-name {standalone_psu_cortexa53_0} \
			-os standalone -proc psu_cortexa53_0
	} err1]} {
		if {[catch {
			domain create -name standalone_psu_cortexa53_0 -display-name {standalone_psu_cortexa53_0} \
				-os standalone -proc psu_cortexa53_0 -arch {64-bit}
		} err2]} {
			return -code error "domain create 失败（无 -arch: $err1）（带 -arch 64-bit: $err2）"
		}
	}
	set dlist [domain list]
	puts "INFO: domain list (domain create 后): $dlist"
}

# 选择 A53 standalone；名称可能是短名或带路径（须去掉 list 中的 “*” 活动标记）
set dom ""
foreach d [domain list] {
	set dn [xsct_normalize_domain_name $d]
	if {$dn eq ""} {
		continue
	}
	if {[string match *psu_cortexa53_0* $dn] && [string match *standalone* $dn]} {
		set dom $dn
		break
	}
}
if {$dom eq ""} {
	foreach d [domain list] {
		set dn [xsct_normalize_domain_name $d]
		if {$dn eq ""} {
			continue
		}
		if {[string match *cortexa53* $dn] && [string match *standalone* $dn]} {
			set dom $dn
			break
		}
	}
}
if {$dom eq ""} {
	return -code error "无法解析 A53 standalone domain，当前 domain list: [domain list]"
}
puts "INFO: 使用 domain: $dom"

# generate 前必须 domain active，否则易出现 “default domain is empty”
if {[catch {domain active $dom} eactive]} {
	return -code error "domain active 失败: $eactive ; domain=$dom ; list=[domain list]"
}
puts "INFO: domain active 成功 -> $dom"

puts "INFO: platform generate (初次，生成 BSP 骨架)"
platform generate

# BSP: 启用 lwIP（RAW API 在常见 BSP 中通过 api_mode 配置；库名因版本而异）
if {[catch {domain active $dom} err]} {
	puts "WARNING: domain active $dom 失败: $err — 尝试其它 domain 名"
	foreach try [domain list] {
		set tn [xsct_normalize_domain_name $try]
		if {$tn eq ""} {
			continue
		}
		if {[string match *psu_cortexa53_0* $tn] && [string match *standalone* $tn]} {
			if {![catch {domain active $tn}]} {
				puts "INFO: domain active $tn"
				set dom $tn
				break
			}
		}
	}
}

set lwip_ok 0
foreach lib {lwip220 lwip211 lwip201} {
	if {![catch {bsp setlib -name $lib}]} {
		puts "INFO: bsp setlib -name $lib"
		set lwip_ok 1
		break
	}
}
if {!$lwip_ok} {
	puts "WARNING: bsp setlib lwIP 未成功，请在 Vitis BSP Settings 中手动添加 lwIP（RAW API）。"
}
foreach cfg {
	{lwip220_api_mode RAW_API}
	{lwip211_api_mode RAW_API}
	{lwip201_api_mode RAW_API}
} {
	set k [lindex $cfg 0]
	set v [lindex $cfg 1]
	if {![catch {bsp config $k $v}]} {
		puts "INFO: bsp config $k $v"
	}
}

catch {domain active $dom}
puts "INFO: platform generate (BSP 更新后)"
platform generate

# 再次移除 XSCT 工作区中可能存在的同名 app（避免 “already exists”）
if {![catch {app remove imgproc_baremetal}]} {
	puts "INFO: app remove imgproc_baremetal"
}
if {![catch {app remove imgproc_baremetal_system}]} {
	puts "INFO: app remove imgproc_baremetal_system"
}
foreach n {imgproc_baremetal imgproc_baremetal_system} {
	set mp [file join $projmeta $n]
	if {[file exists $mp]} {
		puts "INFO: 再次删除工作区登记 $mp"
		file delete -force $mp
	}
}
foreach rel {imgproc_baremetal imgproc_baremetal_system} {
	set p [file join $script_dir $rel]
	if {[file exists $p]} {
		puts "INFO: 再次删除目录 $p"
		file delete -force $p
	}
}

puts "INFO: app create imgproc_baremetal (Empty Application)"
set app_created 0
set app_create_errors {}
foreach tmpl {{Empty Application(C)} {Empty Application} {empty_application}} {
	if {![catch {
		app create -name imgproc_baremetal -lang c -template $tmpl \
			-platform zynq_imgproc_platform -domain $dom
	} app_err]} {
		puts "INFO: app create 成功，template=$tmpl"
		set app_created 1
		break
	}
	lappend app_create_errors "$tmpl => $app_err"
}
if {!$app_created} {
	return -code error "app create 失败，已尝试模板: $app_create_errors"
}

set app_src [file join $script_dir imgproc_baremetal src]
file mkdir $app_src
foreach ext {c h} {
	foreach f [glob -nocomplain [file join $backup *.$ext]] {
		puts "INFO: copy [file tail $f] -> src/"
		file copy -force $f $app_src
	}
}
foreach f [glob -nocomplain [file join $backup *.txt]] {
	file copy -force $f $app_src
}

puts "INFO: app build"
app build -name imgproc_baremetal

puts "INFO: 完成。请用 Vitis 以本目录为 Workspace 打开，检查 BSP 中 lwIP/AXI DMA/IIC 是否与硬件一致后再次 Build。"
