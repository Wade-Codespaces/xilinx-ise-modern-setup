# Windows 安装辅助：开发维护

用户文档见 [安装教程](../../docs/windows/README.md) 和 [安装辅助说明](../../docs/windows/helper.md)。下载入口为 [ISE-Helper.cmd](../../downloads/ISE-Helper.cmd)。

## 源码与构建

- `Single-Helper.Main.ps1`：单窗口主流程、中英文提示和离线修复副本生成。仅接受固定SHA-256的官方输入，生成结果须与czietz原帖附件的固定哈希一致；发布载荷不含下载调用。
- `Installer.Core.psm1`、`WebTalk.Core.psm1`：安装识别、目录及进程判断。
- `Repair-ISE.ps1`、`Watch-ISE-WebTalk.ps1`：构建使用的DLL修复与监视实现。
- `build_single.py`：合并核心实现，生成安装辅助；用户运行时不依赖这些源码文件。

在项目根目录运行 `python tools/windows/build_single.py`。测试载荷写入 `local/windows-single-build/`，发布脚本写入 `downloads/ISE-Helper.cmd`。

## DLL补丁复现规则

出处、原附件标识和输出哈希见[安装辅助说明](../../docs/windows/helper.md#修复来源与运行机制)。以下规则由官方文件与czietz原附件比对得出；保留原作者归属，不将方法标为本项目原创。

| 官方输入文件（相对ISE_DS） | 输入SHA-256 | 文件偏移及替换字节 |
| --- | --- | --- |
| `ISE/lib/nt/libPortability.dll` | `F262130EE8493AA1E50EA4A5111CF2BFFD316745DB76FEE92A0CB609831E33D2` | `0x17F30`：`F8` → `FE` |
| `ISE/lib/nt64/libPortabilityNOSH.dll` | `259844305A4F010E202BAB4A5AF1C08440F6C7503BEBBBD5127A40F88A63F5D8` | `0x1AB30`：`8B F8 BB 60 09 00 00 48 8B CB` → `BB 60 09 00 00 48 8B CB 8B F9` |

64位替换区间长10字节，其中9字节改变。输入也可为已匹配输出哈希的修复文件，支持重复运行。两份输出全部校验通过后才交给文件替换流程。文件一致性验证和安装联动实测分别记录，不以来源引用代替运行验证。

## 验证

- `python tools/windows/test_single.py`：英文发布载荷的操作提示、检查/替换/重复/恢复及单文件发布检查。
- `python tools/windows/test_offline.py`：使用`local/`保留的官方DLL备份和原作者附件，验证离线生成逐字节一致、13处替换/重复/恢复，以及未知输入拒绝；需要本地验证材料，不联网、不加载DLL。
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools/windows/test_installer.ps1`：安装识别、完成判定和备份归档。
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools/windows/test_webtalk.ps1`：进程归属、目录发现和Version Equalizer筛选。
- `python tools/windows/test_repair.py`：模块化DLL修复的隔离回归。

研究、试跑与历史交接记录统一在 `local/archive/windows/`；补丁来源、官方DLL基线与验证结果保留在 `local/` 下，不混入用户文档。临时安装测试目录、生成载荷和一次性恢复脚本可在测试后删除，生成载荷可由构建脚本重建。
