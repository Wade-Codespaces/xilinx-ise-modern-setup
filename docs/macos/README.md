# 在 Apple Silicon Mac 上运行 Xilinx ISE 14.7

[简体中文](README.md) | [English](README.en.md) · [项目总览](../../README.md)

Xilinx ISE 14.7 提供 Windows 和 Linux 版本，没有原生 macOS 版本。官方还提供预装 ISE 的 Linux 虚拟机，原配套方案是在 Windows 上通过 VirtualBox 运行。

Apple Silicon Mac 使用 ARM 架构，而这份官方虚拟机采用 x86_64 架构。[VirtualBox 官方手册](https://www.virtualbox.org/manual/ch01.html#hostossupport)将 Apple Silicon 上的 x86/x64 模拟列为 Developer Preview（开发者预览），仍在开发中，性能有限，也可能遇到兼容性或稳定性问题。因此，本文选择 UTM 模拟 x86_64，运行从官方发行包中提取的虚拟机磁盘。

教程涵盖镜像下载与转换、UTM 配置，以及通过 Netatalk 在 Mac Finder 中访问 Linux 文件的完整流程。

本文环境：M1 Pro、UTM 5.0.8、Oracle Linux 6.4 x86_64、Netatalk 3.1.7。更新：2026-10-31（UTC+8）。

## 1. 下载官方虚拟机

### 选择虚拟机版本

打开 [AMD 官方 ISE 下载页](https://www.amd.com/en/support/downloads/adaptive-socs-and-fpgas/legacy-ise/14_7-windows.html)。在页面的 **Version** 下拉菜单中，选择 **14.7 Windows 10 and Windows 11**。

本文需要从官方预装虚拟机中提取磁盘，因此请选择这一版本。菜单中的 **14.7** 是常规安装版本，不包含本文所需的预装虚拟机。

![在 Version 中选择 14.7 Windows 10 and Windows 11](../../assets/screenshots/2026-10-31-user-amd-version-selection.png)

### 进入下载页面

确认版本后，向下滚动到下载区域，点击 **Title** 下方蓝色的 **14.7 Windows 10 and Windows 11** 链接，进入下载页面。

![点击页面下方的蓝色下载标题](../../assets/screenshots/2026-10-31-user-amd-download-title.png)

### 注册和登录 AMD 账号

点击下载标题后，页面会跳转到 AMD 账号登录界面。使用已有账号登录；首次使用需先创建账号，本文省略具体注册流程。

> 提示：平台会对下载资料进行验证，请注意填入的资料需符合其要求，可能对地区有一定限制。

![AMD 账号登录界面](../../assets/screenshots/2026-10-31-user-amd-login.png)

### 完成姓名和地址验证

登录后进入 **Download Center - Name and Address Verification** 页面，填写带红色星号 `*` 的必填项，包括姓名、公司或机构、地址、国家或地区、城市和职能，并核对预填的邮箱。

> 提示：本页资料需通过平台验证，填写前请留意其要求及可能的地区限制。

![姓名和地址验证页面及填写要求](../../assets/screenshots/2026-10-31-user-amd-address-verification.png)

### 开始下载

填写完成后，滚动到页面底部，检查 **Filename** 中是否包含 **`VM`** 字段，确认下载的是虚拟机版本，再点击 **Download** 开始下载。

![核对文件名并点击 Download](../../assets/screenshots/2026-10-31-user-amd-download-button.png)

等待下载完成，后续从下载包中提取虚拟机磁盘。

## 2. 安装 Homebrew、QEMU 和 UTM

本节命令在 **Mac Terminal** 中执行。

### Homebrew

Homebrew 是 Mac 上的软件包管理工具。本文用它安装 **QEMU**，后续通过 QEMU 的 `qemu-img` 将官方虚拟机磁盘转换为 UTM 使用的格式。

#### 检查是否已安装

打开 Mac Terminal，运行：

```sh
brew --version
```

如果显示版本号，例如下面这样，说明 Homebrew 已可用，可以继续安装 QEMU：

```text
Homebrew x.y.z
```

如果没有显示 Homebrew 版本号，例如提示 `command not found: brew`，说明可能尚未安装；已安装过的用户可先检查终端的 PATH 设置。

#### 从官网安装

打开 [Homebrew 官网](https://brew.sh/)，找到 **Install Homebrew**。点击下图红框内右侧的复制按钮，将官网当前提供的安装命令粘贴到 Mac Terminal 中并运行。

![复制 Homebrew 官网当前的安装命令](../../assets/screenshots/2026-10-31-user-homebrew-copy-command.png)

安装过程中按终端提示操作。常见提示示例如下：

```text
==> Checking for `sudo` access (which may request your password)...
==> This script will install:
...
Press RETURN/ENTER to continue or any other key to abort:
```

安装时可能需要输入 Mac 管理员密码进行授权。出现上述确认提示时，按 **Return / Enter** 继续，等待安装完成。

安装成功后，会看到类似提示：

```text
==> Installation successful!
...
==> Next steps:
```

接着执行终端 **Next steps** 中列出的命令，将 Homebrew 加入 PATH。完成后再次运行：

```sh
brew --version
```

显示 Homebrew 版本号后，继续下一步。以上提示摘自[官方安装脚本](https://github.com/Homebrew/install/blob/HEAD/install.sh)，具体输出随版本和本机环境变化。

### QEMU

QEMU 提供磁盘转换工具 `qemu-img`。先检查是否已可用：

```sh
qemu-img --version
```

如果显示版本信息，说明工具已可用，直接进入下一步。

如果提示找不到命令，先通过 Homebrew 安装，再检查版本：

```sh
brew install qemu
qemu-img --version
```

### UTM

打开 [UTM 官网](https://mac.getutm.app/)，点击下图红框中的 **Download for Mac**，下载 DMG 安装包。

![点击 Download for Mac 下载 UTM](../../assets/screenshots/2026-10-31-user-utm-download.png)

下载完成后，打开 DMG，将 UTM 拖入 **Applications（应用程序）** 文件夹，再从应用程序中打开 UTM。

## 3. 提取 VMDK

### 解压下载包并找到 OVA 文件

官方下载包下载完成后，双击 ZIP 文件解压。打开解压后的文件夹，进入 **`ova`** 文件夹，找到 **`14.7_VM.ova`**。

![解压下载包后，在 ova 文件夹中找到 14.7_VM.ova](../../assets/screenshots/2026-10-31-user-official-extracted-ova.png)

> 空间提示：安装包体积较大，完全解压后，可删除原 ZIP 下载包，并清空废纸篓中的该文件以释放空间。下一步还需再次解压 OVA，提前清理可减少磁盘空间压力。

### 再次解包并保留 VMDK

将 `14.7_VM.ova` 重命名为 **`14.7_VM.ova.tar`**，再双击解包。OVA 本身采用 TAR 归档格式，macOS 自带的归档实用工具即可打开。

打开解包后的文件夹，找到 **`14.7_VM-disk001.vmdk`**。这就是下一步转换所需的虚拟机磁盘。

![再次解包后找到 VMDK 磁盘文件](../../assets/screenshots/2026-10-31-user-extracted-vmdk.png)

将 VMDK 移到你选择的合适文件夹中。移出后即可删除原来的整套解包目录，包括 TAR、OVF 和其余安装文件，并清空废纸篓中的这些文件，释放空间。

## 4. 转换为压缩 QCOW2

打开 Mac Terminal，输入 `cd` 并加一个空格，然后将存放 VMDK 的文件夹从 Finder 拖入终端，按 **Return / Enter**。终端会切换到该文件夹；拖入路径的方式也能处理文件夹名称中的空格。

接着执行转换：

```sh
qemu-img convert -p -f vmdk -O qcow2 -c \
  "14.7_VM-disk001.vmdk" "ISE_14.7_VM.qcow2"
```

执行后，终端会持续更新转换进度，例如：

```text
    (2.00/100%)
```

等待进度达到 **100%**、命令正常结束并返回终端提示符，当前文件夹中就会生成 **`ISE_14.7_VM.qcow2`**。转换期间保持终端窗口打开。

| 参数 | 用途 |
| --- | --- |
| `-p` | 显示进度 |
| `-f vmdk` | 输入格式 |
| `-O qcow2` | 输出格式 |
| `-c` | 压缩输出数据 |

转换完成后，检查 QCOW2 镜像结构：

```sh
qemu-img check -f qcow2 "ISE_14.7_VM.qcow2"
```

输出 **`No errors were found on the image.`**，说明镜像结构检查通过，可以继续导入 UTM。检查时保持虚拟机关机。

VMDK 原本也可能经过压缩，转换后的 QCOW2 文件大小不一定更小。虚拟容量是客户机可使用的上限；Mac 的实际占用随文件内容和压缩状态变化。

结构检查通过后，保留生成的 **`ISE_14.7_VM.qcow2`**，下一步将它导入 UTM。

![转换完成后生成 QCOW2 镜像](../../assets/screenshots/2026-10-31-user-converted-qcow2.png)

此时可以删除原来的 **VMDK**，并清空废纸篓中的该文件，释放磁盘空间。

## 5. 创建 UTM 虚拟机

### 模拟模式和架构

打开 UTM，点击窗口上方的 **＋**，选择 **Emulate**。在操作系统页选择 **Linux**。

![新建虚拟机并选择 Emulate](../../assets/screenshots/2026-10-31-user-utm-create-emulate.png)

### 硬件配置与磁盘导入

在 **Hardware** 页按左图配置，然后点击 **Continue**，按右图选择 **Import existing drive → Browse…**，选中刚才转换完成的 `ISE_14.7_VM.qcow2`。

- 内存按图设置为 **1024 MiB（1 GiB）**，用于基本操作；较大的工程可按需增加。
- 本文使用 **8 核版 M1 Pro**，为虚拟机分配 **6 核**；其他 Mac 可根据自身资源调整。
- 本教程使用 **qxl-vga** 显卡，OpenGL 加速保持关闭。[UTM 显示设置说明](https://docs.getutm.app/settings-qemu/devices/display/)

| 硬件配置 | 导入已有磁盘 |
| :---: | :---: |
| <img src="../../assets/screenshots/2026-10-31-user-utm-hardware-opengl-off.png" alt="x86_64、1024 MiB、6 核，关闭 OpenGL 加速" width="400"> | <img src="../../assets/screenshots/2026-10-31-user-utm-import-qcow2.png" alt="选择 Import existing drive，点击 Browse 导入 QCOW2" width="400"> |

### 共享文件夹与配置确认

在 **Shared Directory** 页保持路径为空，直接点击 **Continue**。这份旧系统镜像无法直接使用此处的共享文件夹功能，后续通过 Netatalk 传输文件。

在 **Summary** 页顶部为虚拟机命名，例如 `ISE 14.7 VM`，然后检查 **Architecture、System、RAM、CPU、Storage**，以及 **Hardware OpenGL Acceleration** 是否与前面的设置一致。

本镜像的 **Storage** 应显示 **64 GB**，表示 UTM 已读取到导入磁盘的虚拟容量；镜像在 Mac 上的实际占用会小于这个容量。确认后点击 **Save**。

| 跳过共享文件夹 | 命名并确认配置 |
| :---: | :---: |
| <img src="../../assets/screenshots/2026-10-31-user-utm-shared-directory.png" alt="Shared Directory 路径留空，点击 Continue" width="400"> | <img src="../../assets/screenshots/2026-10-31-user-utm-summary.png" alt="Summary 页命名并检查配置，Storage 显示 64 GB，OpenGL 关闭" width="400"> |

点击 **Save** 后，UTM 会显示转圈的加载图标，此时正在将磁盘文件复制到虚拟机自己的目录中。

### 打开虚拟机设置

等待转圈图标消失，UTM 主界面会显示新建的虚拟机。右键点击这台虚拟机，选择 **Edit**，进入设置界面，按下文确认多核、启动方式和显示驱动，并调整滚轮方向。

![右键点击虚拟机，选择 Edit](../../assets/screenshots/2026-10-31-user-utm-edit-menu.png)

导入后的磁盘副本可能比转换时的压缩镜像更大。本次 Finder 显示 `.utm` 包大小为 **41.45 GB**；完成配置后，按第 6 节再次压缩，减少磁盘占用。

导入完成后，UTM 使用自己目录中的磁盘副本，原来的外部 **QCOW2** 已无需保留。如果磁盘空间紧张，可以删除导入前的 QCOW2 镜像，并清空废纸篓中的该文件，释放空间。

![导入后 Finder 显示虚拟机包为 41.45 GB](../../assets/screenshots/2026-10-31-user-utm-imported-size.png)

### CPU 多核设置

进入 **System** 页，勾选默认关闭的 **Force Multicore**，让前面分配的多个虚拟 CPU 并行模拟，改善运行性能。CPU 和 JIT Cache 保持 **Default**。[UTM CPU 设置](https://docs.getutm.app/settings-qemu/system/)

![在 System 中开启 Force Multicore](../../assets/screenshots/2026-10-31-user-utm-force-multicore.png)

### 启动方式

进入 **QEMU** 页，取消勾选 **UEFI Boot**。这份官方镜像按传统 BIOS 方式启动。

![在 QEMU 中关闭 UEFI Boot](../../assets/screenshots/2026-10-31-user-utm-uefi-off.png)

### 显示设备

进入 **Display** 页，在 **Emulated Display Card** 中选择与这份旧系统兼容的：

**Spice QXL GPU (primary, vga compatible) (qxl-vga)**

![在 Display 中选择 qxl-vga](../../assets/screenshots/2026-10-31-user-utm-qxl-vga.png)

其余缩放选项保持默认。窗口自适应分辨率和剪贴板功能需要客户机的 SPICE 支持。

### 磁盘和网络

系统盘使用 **IDE** 接口，网络使用 **Shared Network / e1000**，系统盘排在启动顺序首位。保存配置后，继续压缩磁盘并挂载 Netatalk 光盘。

## 6. 在 UTM 中再次压缩

导入系统盘时，UTM 会在 `.utm` 包内保存磁盘副本。**先保存导入设置，再重新打开磁盘设置执行压缩。**

虚拟机保持 **Stopped** 状态；若已启动，先在 Linux 中正常关机。

**压缩期间需要临时磁盘空间。** 可以先清理前面已用完的下载包、解压文件及导入前的外部 QCOW2，并清空废纸篓中的对应文件，为压缩留出空间。

1. 在设置左侧选择系统盘对应的 **IDE Drive**。
2. 点击 **Compress**，在弹出的确认窗口中点击 **Reclaim**。
3. 等待进度条完成，查看压缩后的 **Size**，然后保存设置。

![在 IDE Drive 中点击 Compress](../../assets/screenshots/2026-10-31-user-utm-compress-drive.png)

**Reclaim Space** 用于回收空间，**Compress** 用于回收并压缩，**Resize** 用于扩容；这里选择 **Compress**。完成后继续添加 Netatalk 光盘。

## 7. 安装 Netatalk 文件共享包

### 光盘用途

本节用于配置 Mac 与虚拟机之间的文件共享，可按需安装。[下载 Netatalk 离线光盘](../../downloads/ISE_NETATALK_3.1.7.iso)（约 6.8 MB）。

官方镜像原配套的文件共享方案依赖 VirtualBox 的共享文件夹机制，无法直接用于 UTM，因此虚拟机与 Mac 之间传输文件需要另行配置。本文选择 Netatalk，让 Mac 通过 AFP 在 Finder 中访问虚拟机文件。

为简化安装，本项目将 Netatalk 整理为离线光盘包，省去开发工具安装和源码编译。安装器使用现有的 **ise** 账户，配置共享并放行所需的防火墙访问。

光盘文件、共享配置及防火墙规则的详细说明见[Netatalk 离线光盘说明](netatalk-disc.md)。

### 添加 Netatalk 光盘

压缩完成后，按以下步骤挂载光盘：

1. 点击设置左侧 **Drives** 下的 **New…（＋）**，勾选 **Removable**，接口选择 **IDE**。以可移除光盘方式挂载 ISO，直接引用原文件，省去导入为固定磁盘时的副本。
2. 点击 **Browse…**，选中 `ISE_NETATALK_3.1.7.iso`。

![点击 New，勾选 Removable，选择 IDE 并点击 Browse](../../assets/screenshots/2026-10-31-user-utm-add-removable.png)

确认左侧已新增一个驱动器，右侧 **Path** 为该 ISO，**Image Type** 为 **CD/DVD (ISO) Image**，且 **Removable Drive** 已勾选。保持系统盘在启动顺序首位，点击 **Save**，完成虚拟机配置。

![确认 Netatalk ISO 已作为可移除 CD/DVD 添加，点击 Save](../../assets/screenshots/2026-10-31-user-utm-netatalk-disc-added.png)

挂载期间保留 ISO 在所选位置，供虚拟机读取。

### 滚轮方向

保存虚拟机配置后，推荐调整滚轮方向，让虚拟机的滚动响应更符合 Mac 的自然滚动习惯。

点击屏幕左上角菜单栏的 **UTM → Settings…**。

![从 UTM 菜单打开 Settings](../../assets/screenshots/2026-10-31-user-utm-settings-menu.png)

选择 **Input**，在 **QEMU Pointer** 下勾选 **Invert scrolling**。

![在 Input 中开启 Invert scrolling](../../assets/screenshots/2026-10-31-user-utm-invert-scrolling.png)

### 启动虚拟机

配置完成后，回到 UTM 主界面，选中虚拟机并点击启动按钮。出现 Oracle Linux 启动进度画面后，耐心等待系统进入桌面。

| 启动过程中 | 进入桌面 |
| :---: | :---: |
| <img src="../../assets/screenshots/2026-10-31-user-utm-boot-progress.png" alt="Oracle Linux Server 6.4 启动进度" width="400"> | <img src="../../assets/screenshots/2026-10-31-user-utm-linux-desktop.png" alt="Oracle Linux 桌面及 ISE_NETATALK 光盘图标" width="400"> |

出现右图所示的桌面，即表示虚拟机已成功开机。

### 开机后从光盘安装

双击桌面上的 **ISE_NETATALK** 光盘图标，再双击光盘内的 **Install Netatalk**，即可打开安装程序。

![打开光盘并双击 Install Netatalk](../../assets/screenshots/2026-10-31-user-netatalk-launcher.png)

核对共享目录、账户和网络范围，确认后按 **Enter** 开始安装；出现认证提示时输入当前 ise 密码。看到 **Installation complete** 后，记下显示的 `afp://…` 地址，再按 **Enter** 关闭安装窗口。

| 确认并开始安装 | 安装完成并显示连接地址 |
| :---: | :---: |
| <img src="../../assets/screenshots/2026-10-31-user-netatalk-install-confirm.png" alt="核对安装配置并按 Enter 开始" width="400"> | <img src="../../assets/screenshots/2026-10-31-user-netatalk-install-complete.png" alt="Installation complete，显示 AFP 地址，按 Enter 关闭" width="400"> |

安装完成后，服务会自动启动，并随虚拟机开机运行。若忘记连接地址，可打开 **Terminal**，按下一节的方法用 `ifconfig` 查询虚拟机 IP。

## 8. 查找 VM 地址并连接 AFP

### 在 Linux 查 IP

在虚拟机左上角的 **Applications → System Tools → Terminal** 打开终端，输入 `ifconfig` 即可查询 IP 地址。

![从 Applications → System Tools 打开 Terminal](../../assets/screenshots/2026-10-31-user-linux-terminal-menu.png)

### 在 Finder 连接

回到 Mac，打开访达（Finder），在顶部菜单中选择 **前往 → 连接服务器…（Go → Connect to Server…）**，也可以按 **Command+K**。

![从 Finder 的 Go 菜单选择 Connect to Server](../../assets/screenshots/2026-10-31-user-finder-connect-menu.png)

输入 `afp://` 加上刚才的虚拟机 IP，例如图中的 `afp://192.168.64.4`。可点击左下角 **＋** 收藏地址，下次直接选中即可，然后点击 **连接（Connect）**。

![输入 AFP 地址并点击加号收藏](../../assets/screenshots/2026-10-31-user-finder-afp-address.png)

在登录窗口输入用户名 **`ise`**。如果没有修改 Linux 密码，使用默认密码 **`xilinx`（全小写）**；已修改则使用当前密码。可勾选 **在我的钥匙串中记住此密码（Remember this password in my keychain）**，再点击 **连接（Connect）**。[官方默认账户说明](https://docs.amd.com/r/en-US/ug1227-ise-vm-windows10/ISE-Virtual-Machine-Login-and-Permissions)

![输入 ise 账户和密码，可勾选记住密码](../../assets/screenshots/2026-10-31-user-finder-afp-login.png)

Finder 打开 **ise share** 并显示其中的文件夹，即表示连接成功。该共享对应虚拟机的 `/home/ise`，现在可以在 Mac 与虚拟机之间拖放或复制文件。

![Finder 成功打开 ise share 共享目录](../../assets/screenshots/2026-10-31-user-finder-ise-share.png)

### 验证传输

从 Mac 复制一个测试文件到共享目录，再从 Linux 创建另一个文件复制回 Mac，分别确认内容。ISE 工程放在 Linux 本地目录中编译。

连接异常时依次检查 IP、服务状态和 AFP 的 TCP 548 访问：

```sh
sudo service netatalk status
/usr/local/sbin/afpd -V
```

## 9. 启动 ISE

在虚拟机桌面双击 **Project Navigator**，等待 **ISE Project Navigator** 主窗口出现。首次启动时会显示 **Tip of the Day**，点击 **OK** 关闭即可；可取消勾选 **Show Tips at Startup**，下次启动时不再显示。

![在 UTM 虚拟机中成功打开 ISE Project Navigator](../../assets/screenshots/2026-11-01-user-macos-ise-project-navigator.png)

## 参考

- Kevin Patterson：[Running the Xilinx ISE on an M1 MacBook Pro](https://www.youtube.com/watch?v=h4-FIYJfRUE)，2022。本文的主要流程参考。
- Dmitry Dovidenko：[Netatalk 3.1.7 on CentOS 6.6 x86_64](https://dovidenko.com/2015/359/howto-compiling-installing-configuring-netatalk-3-1-7-centos-6-6-x86_64-storage-time-machine.html)，2015。编译与服务配置参考。
