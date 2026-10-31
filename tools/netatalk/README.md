# Netatalk disc tools / 光盘构建工具

## 使用 / Installation

安装只需 [正式 ISO](../../downloads/ISE_NETATALK_3.1.7.iso)，按[中文教程](../../docs/macos/README.md#开机后从光盘安装)或 [English guide](../../docs/macos/README.en.md#install-from-the-disc)操作。安装使用已有 ise 账户，共享 `/home/ise`，设置开机自启，并仅允许 UTM Shared Network 宿主 `192.168.64.1` 访问 TCP 548。

For installation, use the [ISO](../../downloads/ISE_NETATALK_3.1.7.iso). The installer uses the existing ise account, shares `/home/ise`, starts the service at boot, and permits TCP 548 from the UTM Shared Network host at `192.168.64.1`.

## 文件 / Files

| File | Purpose / 用途 |
| --- | --- |
| `install.sh` | Offline installation and configuration / 离线安装与配置 |
| `Install.desktop` | Desktop launcher / 桌面入口 |
| `DISC-README.txt` | Instructions included on the disc / 光盘说明 |
| `build-disc.py` | Assemble an ISO from the extracted disc materials / 从解包材料制作 ISO |
| `ise-netatalk.spec` | RPM files, dependencies, and lifecycle scripts / RPM 打包规则 |
| `rebuild-from-source.sh` | Rebuild upstream source in a compatible OL6 x86_64 environment / 从源码重建 |
| `prepare-rpm-inputs.py` | Select runtime files for packaging / 筛选打包文件 |
| `collect-environment.sh` | Optional build-environment inspection / 可选的构建环境采集 |

## 重建光盘 / Rebuild the disc

将正式 ISO 的全部内容复制到一个材料目录，保持 `packages/`、`source/`、`licenses/` 和其他文件结构。随后在 macOS 的仓库根目录运行：

Copy all files from the ISO into a materials directory, preserving its directory structure. From the repository root on macOS, run:

```sh
python3 tools/netatalk/build-disc.py /path/to/disc-materials /path/to/new-output
```

输出目录须尚未存在。脚本使用 macOS 自带的 `hdiutil` 创建 ISO，并生成新的 SHA-256 文件；替换脚本后重建的 ISO 校验值会变化。安装光盘本身不需要 Python。

The output directory must not already exist. The builder uses macOS `hdiutil` and generates a new SHA-256 file. Rebuilding with changed scripts changes the ISO checksum. Python is only used for building, not for installation.

源码 RPM 和 `source/upstream.tbz` 随 ISO 提供。`rebuild-from-source.sh` 在匹配的 OL6 x86_64 开发环境中编译并暂存文件；`ise-netatalk.spec` 的默认 `%build` 复用保留的编译产物。

The source RPM and `source/upstream.tbz` accompany the ISO. `rebuild-from-source.sh` compiles and stages files in a matching OL6 x86_64 development environment. The default `%build` in the RPM specification reuses retained build artifacts.

来源与许可见 [NOTICE](../../NOTICE.md)，具体文件清单及配置见[中文说明](../../docs/macos/netatalk-disc.md) / [English details](../../docs/macos/netatalk-disc.en.md)。
