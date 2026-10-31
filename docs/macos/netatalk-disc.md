# Netatalk 离线光盘说明

[简体中文](netatalk-disc.md) | [English](netatalk-disc.en.md) · [返回教程](README.md)

本文补充[Mac 安装教程](README.md#7-安装-netatalk-文件共享包)中的光盘内容、安装操作与配置细节。

## 用途与适用环境

`ISE_NETATALK_3.1.7.iso` 是本项目制作的 Netatalk 离线安装介质，约 **6.8 MB**，用于官方 ISE VM 的 **Oracle Linux 6.4 x86_64**，网络采用 UTM **Shared Network**。基础镜像已具备所需运行库，安装时使用编译好的 RPM。

[下载光盘](../../downloads/ISE_NETATALK_3.1.7.iso) · [SHA-256](../../downloads/ISE_NETATALK_3.1.7.iso.sha256)

## 光盘文件清单

```text
ISE_NETATALK/
├── install.desktop       桌面安装入口
├── install.sh            安装脚本，可用文本编辑器查看
├── readme.txt            使用说明和参考来源
├── sha256sums            文件校验清单
├── packages/
│   └── netatalk.rpm      编译好的 Netatalk 运行包
├── licenses/
│   ├── authors.txt       原作者信息
│   ├── copying.txt       GPL 许可证
│   └── copyright.txt     版权与许可声明
└── source/
    ├── netatalk.rpm      对应源码 RPM
    ├── upstream.tbz      Netatalk 3.1.7 原源码
    ├── runtime.tgz       打包用的运行文件
    ├── netatalk.spec     RPM 打包配方
    ├── configure.txt     原编译参数
    ├── comparison.txt    源码比对记录
    ├── prepare.py        制作运行包的 Python 工具
    └── rebuild.sh        源码重建脚本
```

安装入口运行 `install.sh`，使用 `packages/netatalk.rpm` 安装程序。`source/` 用于查看源码和复现打包，使用者无需安装 Python 或编译环境。光盘未包含 ISE 软件、完整系统镜像或之前的证书更新包。

## 安装器执行的操作

1. 显示共享目录、网络范围及服务自启设置，等待用户确认。
2. 获取管理员权限，检查系统版本、架构、现有账户和文件校验值。
3. 检查 Shared Network 的默认网关为 `192.168.64.1`，并识别活动网卡。
4. 检查 RPM 依赖并安装 Netatalk 3.1.7，写入共享配置和服务脚本。
5. 设置 Netatalk 开机自启，配置防火墙访问并启动服务。
6. 显示服务状态和 Finder 使用的 `afp://…` 地址。

程序包括 AFP 服务、DHX2 认证模块及 CNID 数据库服务。RPM 创建 `/usr/local/var/netatalk/CNID` 状态目录，运行后生成该虚拟机自己的服务状态文件。

## 共享配置

共享使用镜像现有的 `ise` 账户与当前密码，名称为 `ise share`，路径为 `/home/ise`。`/usr/local/etc/afp.conf` 内容如下：

```ini
[Global]
uam list = uams_dhx2.so

[ise share]
path = /home/ise
valid users = ise
```

## 防火墙与开机启动

当 iptables 服务运行时，安装器在 INPUT 链开头加入以下规则；已有同一规则时跳过添加。网卡名由默认路由读取，以下以 `eth1` 为例：

```sh
iptables -I INPUT 1 -i eth1 -s 192.168.64.1/32 \
  -p tcp --dport 548 -m state --state NEW -j ACCEPT
service iptables save
```

规则允许 Mac 宿主 `192.168.64.1` 通过活动网卡访问 AFP 的 TCP 548，并保存到 `/etc/sysconfig/iptables`。

服务注册及启动使用：

```sh
chkconfig --add netatalk
chkconfig netatalk on
service netatalk start
```

## 源码、构建与验证记录

可直接查看[安装脚本](../../tools/netatalk/install.sh)、[RPM 文件清单与安装规则](../../tools/netatalk/ise-netatalk.spec)和[光盘制作工具](../../tools/netatalk/build-disc.py)。源码 RPM 包含原源码、保留的编译产物和重建脚本，具体构建方式见[打包说明](../../tools/netatalk/README.md)。

已在新官方镜像验证 RPM 安装、AFP 认证、双向文本传输、重启自启和重新挂载。最终光盘的 15 个文件校验值及脚本语法检查通过，并完成桌面双击安装和 Finder 连接，见[教程中的安装截图](README.md#开机后从光盘安装)。

源码安装过程参考 Kevin Patterson 的 [YouTube 视频](https://www.youtube.com/watch?v=h4-FIYJfRUE)（2022）及 Dmitry Dovidenko 的 [Netatalk 3.1.7 教程](https://dovidenko.com/2015/359/howto-compiling-installing-configuring-netatalk-3-1-7-centos-6-6-x86_64-storage-time-machine.html)（2015）。
