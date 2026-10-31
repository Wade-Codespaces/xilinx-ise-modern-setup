# ISE 安装辅助技术说明

[简体中文](helper.md) | [English](helper.en.md) · [返回 Windows 安装教程](README.md)

本文介绍安装辅助的组成、运行机制、文件改动和修复来源。安装操作见[Windows 安装教程](README.md)。

## 组成与运行环境

`ISE-Helper.cmd` 用于配合官方 Windows 原生 ISE 14.7 安装程序。文件包含启动入口、安装监视逻辑、DLL修复规则及备份逻辑，运行时使用Windows自带的命令解释器和Windows PowerShell，无需Python或额外的脚本模块。

启动入口申请管理员权限，随后在同一窗口运行安装监视和修复流程。脚本所在位置与官方安装包位置无须相同；安装器位置来自正在运行的进程，安装目录来自本次安装的相关子进程。

## 安装识别与监视机制

辅助等待原生安装器进程，核对其路径、Xilinx签名和安装包结构。安装中途启动辅助时，也使用相同的进程识别机制；末段已无相关子进程时，可能无法定位安装目录。

WebTalk处理限定于本次安装器的子进程。Version Equalizer处理进一步核对执行阶段、`xilperl.exe`路径及`fix_version.pl`命令行；持续30秒没有CPU、读写或日志变化后，结束对应的停留任务，并记录该阶段已被跳过。

Version Equalizer的处理用于继续安装，并不证明System Generator与MATLAB集成可用。辅助不自动建立MATLAB关联。

## 安装完成判定与文件修复

安装器退出后，辅助结合退出码、本轮安装日志中的成功标记、日志时间及关键文件判断安装结果。判定成功且ISE相关程序退出后，才进入文件修复。

修复流程读取官方32位和64位DLL，生成并校验修复副本，备份目标原件，再逐项替换并核对SHA-256。完整套件的本机验证覆盖13处DLL；实际目标取决于已安装的组件。辅助还将当前用户的`XILINX_VC_CHECK_NOOP`设为`1`，供ISE启动检查使用。

## 备份与日志

原DLL及恢复记录保存在安装目录的 `.ise-modern-repair/`，记录包含文件相对路径、替换前后哈希及启动检查变量的原值。重复应用保留原始备份，恢复逻辑会检查文件是否发生额外变化。

运行日志与生成的修复副本位于 `%LOCALAPPDATA%\ISE-Modern-Setup\sessions\`，每次运行使用独立会话目录。

## 修复来源与运行机制

DLL修复方案来自 **czietz** 于 **2022年12月24日** 发布在 exxos 论坛的帖子 *Xilinx Impact Suddenly Stopped Working*，附件名为 `xilinx-ise-win10-hang-hotfix.zip`。原作者说明，此补丁让网络共享枚举走失败路径，以避开涉及WSL共享目录的卡住问题，并提示从网络共享加载文件可能受影响。

[原作者说明](https://www.exxosforum.co.uk/forum/viewtopic.php?t=6052#p95891) · [原帖附件](https://www.exxosforum.co.uk/forum/download/file.php?id=29188)

本项目将该附件与本机官方安装文件进行二进制比对，提取固定修改规则。辅助在用户电脑上重现这份补丁：先核对官方DLL的SHA-256，在副本上应用固定修改，再核对生成文件的SHA-256。输出必须与已核对的原帖附件一致，才会备份并替换安装文件。运行时无需下载DLL，官方文件版本不匹配时停止修复。

补丁方法归于czietz；本项目负责修改规则的提取、本机生成、文件校验与备份，以及安装过程的自动处理。WebTalk和Version Equalizer的监视处理属于本项目辅助逻辑，并非该DLL附件提供的功能。

所核对原帖附件ZIP的SHA-256为 `9CF48F4E08E54194CB01F6751FADF59C442F3E2B88BB93891B50087258C54703`。以下为附件中两个DLL及本机生成结果的校验值：

| 文件 | SHA-256 |
| --- | --- |
| nt/libPortability.dll | `6B36659BDF3207271B33057E6C6E61E3B3D734AFFD6A7CFC80672B8B3A73B07B` |
| nt64/libPortability.dll | `F31D61BAE911A382DF552EE477B07F52729FC65B414F85617188591147BFA1E6` |

本地测试已确认生成文件与所核对附件逐字节一致，13处文件替换、重复执行和恢复通过。2026年11月1日的用户实操截图进一步确认：辅助处理WebTalk和Version Equalizer后，官方安装完成；退出安装器后，辅助自动生成修复副本，完成13处DLL替换及启动检查变量设置，随后ISE Project Navigator进入主界面。

下载文件仅包含本项目脚本，未捆绑第三方DLL、ISE、许可证或虚拟机。ISE安装包从AMD官网下载。
