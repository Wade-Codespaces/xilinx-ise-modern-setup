# Xilinx ISE 14.7 Modern Setup

[简体中文](README.md) | [English](README.en.md)

面向 **Windows 11** 和 **Apple Silicon Mac** 的 Xilinx ISE 14.7 安装指南，以逐步说明、实操截图和离线文件共享安装包，整理旧版开发工具在当前电脑上的使用流程。

## 为什么整理这套教程

一些课程和旧器件项目仍需使用 ISE。官方为新 Windows 提供的虚拟机方案需要额外运行一套 Linux 系统，会占用更多资源；Windows 教程采用配合兼容性修复的原生安装流程。

Mac 没有原生 ISE，Apple Silicon 的 ARM 架构也无法直接运行官方 x86_64 系统。本文采用 UTM 模拟官方虚拟机，并用 Netatalk 离线安装光盘解决 Finder 文件共享，形成从下载、转换到桌面启动和文件访问的完整教程。

## 选择平台

| 平台 | 方案 |
| --- | --- |
| [Apple Silicon Mac](docs/macos/README.md) | UTM 模拟官方 ISE VM，AFP 文件共享 |
| [Windows 11](docs/windows/README.md) | 原生安装与兼容性修复 |

## 参考与致谢

- Kevin Patterson：[Running the Xilinx ISE on an M1 MacBook Pro](https://www.youtube.com/watch?v=h4-FIYJfRUE)，2022。Mac 流程的主要视频参考。
- Dmitry Dovidenko：[Netatalk 3.1.7 on CentOS 6.6 x86_64](https://dovidenko.com/2015/359/howto-compiling-installing-configuring-netatalk-3-1-7-centos-6-6-x86_64-storage-time-machine.html)，2015。Netatalk 编译与配置参考。
- czietz：[Xilinx Impact Suddenly Stopped Working](https://www.exxosforum.co.uk/forum/viewtopic.php?t=6052#p95891)，2022 年 12 月 24 日。Windows DLL 修复方案的来源，通过调整网络共享枚举逻辑解决相关启动卡住问题。本项目的 Windows 安装辅助在本机重现该补丁，并进行文件校验与备份。

本教程在参考流程上采用压缩磁盘转换、现有 ise 账户和离线安装光盘，并补充 UTM 压缩与 Finder 连接步骤。第三方软件的来源与许可见 [NOTICE](NOTICE.md)。
