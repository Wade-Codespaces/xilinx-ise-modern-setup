# Install Xilinx ISE 14.7 Natively on Windows 11

[简体中文](README.md) | [English](README.en.md) · [Project overview](../../README.en.md)

This guide uses the original native Windows ISE 14.7 installer together with an installation helper to handle known compatibility issues during setup.

## Before you begin: download the installation helper

Download the [ISE installation helper](../../downloads/ISE-Helper.cmd).

Save the script somewhere convenient. Start it before running the official installer later in this guide.

For its components, operating principles, and patch sources, see the [ISE installation helper technical notes](helper.en.md).

## 1. Download the official native Windows installer

### Select Version 14.7

Open the [AMD ISE download page](https://www.amd.com/en/support/downloads/adaptive-socs-and-fpgas/legacy-ise/v2012_4---14_7.html). In the **Version** dropdown on the right, select **14.7**.

**14.7 Windows 10 and Windows 11** is the official VM package. This guide uses the original native Windows installer under **14.7**.

![Select 14.7 in the Version dropdown](../../assets/screenshots/windows/2026-11-01-user-amd-version-14-7.png)

### Expand the ISE Design Suite download section

Scroll down and expand **ISE Design Suite – 14.7 – Oct 23, 2013**. Click the blue **Full Installer for Windows 7/XP/Server** link indicated by the arrow below. This is the native Windows package used in this guide.

![Expand ISE Design Suite 14.7 and click Full Installer for Windows 7/XP/Server](../../assets/screenshots/windows/2026-11-01-user-amd-native-installer-download.png)

### Register or sign in to your AMD account

Clicking the download title takes you to the AMD sign-in page. Sign in with an existing account, or create an account if this is your first visit. Account registration is not covered here.

> Tip: AMD verifies the information supplied for downloads. Follow the site's requirements and check for any regional restrictions.

![AMD account sign-in page](../../assets/screenshots/windows/2026-11-01-user-amd-login.png)

### Complete name and address verification

After signing in, complete the **Download Center - Name and Address Verification** page. Fill in the required fields marked with a red asterisk `*`, including your name, company or institution, address, country or region, city, and job function. Check the prefilled email address.

> Tip: The information must pass the site's verification. Review its requirements and any regional restrictions before submitting.

![Name and address verification form](../../assets/screenshots/windows/2026-11-01-user-amd-address-verification.png)

### Check the package and start the download

Scroll to the bottom of the page. Confirm that **Filename does not contain `VM`**, so you are downloading the native Windows package, then click **Download**.

![Confirm that Filename does not contain VM, then click Download](../../assets/screenshots/windows/2026-11-01-user-amd-native-download-confirmation.png)

Wait for the download to finish before extracting the package.

## 2. Extract the package and locate the installer

Right-click the downloaded archive and extract it into a folder.

![The downloaded archive and its extracted folder](../../assets/screenshots/windows/2026-11-01-user-native-package-extracted.png)

Open the extracted folder and locate **xsetup.exe**, the official installer.

![Locate xsetup.exe in the extracted folder](../../assets/screenshots/windows/2026-11-01-user-native-xsetup-entry.png)

Locate this file first, then start the installation helper in the next step before running **xsetup.exe**.

## 3. Start the installation helper

Open **ISE-Helper.cmd**, downloaded earlier.

Double-click the script and allow administrator access when Windows prompts you. Wait until the helper is ready. Keep its window open, then double-click **xsetup.exe** to launch the official ISE installer. The helper automatically detects the installer and starts monitoring its progress, as shown below.

![The helper detects the official ISE installer and monitors installation progress](../../assets/screenshots/windows/2026-11-01-user-helper-installer-detected.png)

Once these messages appear, return to the ISE wizard and click **Next** to continue. Keep the helper window open.

Starting the helper before the official installer is recommended. If installation has already started, you can also open the helper and let it detect the running installer. Check its window for confirmation that it has identified the installer and installation folder.

## 4. Accept the agreements and choose an edition

Read the license agreements in the installation wizard. If you agree, select the acceptance checkbox and click **Next** until you reach **Select Products to Install**.

Choose the edition you need, then click **Next**.

This guide uses **System Edition**, which provides the broadest set of tools.

![Select Products to Install: edition selection](../../assets/screenshots/windows/2026-11-01-user-ise-edition-selection.png)

The options select different combinations of tools:

| Option | Main purpose and differences |
| --- | --- |
| **ISE WebPACK** | Free licensed tools for logic design, synthesis, implementation, and simulation, with a limited range of supported devices. Additional installed tools may require separate licenses. |
| **ISE Design Suite Logic Edition** | Logic design tools covering design entry, synthesis, implementation, and verification. The foundation of the other suite editions. |
| **ISE Design Suite Embedded Edition** | Adds embedded development tools and IP to Logic Edition, for processor systems such as MicroBlaze. |
| **ISE Design Suite DSP Edition** | Adds System Generator for DSP and related IP to Logic Edition, for digital signal processing designs. |
| **ISE Design Suite System Edition** | Combines the tools, technologies, and IP from Logic, Embedded, and DSP Editions. The most comprehensive suite option listed here. |
| **Lab Tools – Standalone Installation** | Installs laboratory programming, configuration, and debugging tools for working with existing designs on hardware, rather than the complete synthesis and implementation development flow. |

This comparison is based on the [official Xilinx ISE Design Suite 14 product sheet (2012)](https://www.xilinx.com/publications/prod_mktg/ISE_sellsheet.pdf) and the [ISE 14.7 installation and licensing guide, UG631 (2020 revision)](https://www.amd.com/content/dam/amd/en/documents/products/adaptive-socs-and-fpgas/fpga/6-series/irn.pdf). Installed components and licensed features are separate: access to individual tools and IP depends on your license.

## 5. Select installation options

On **Select Installation Options**, use the settings below: keep the multicore installation option enabled at the top, select **Install Cable Drivers** in the list, and clear the other three items.

![Keep multicore installation enabled and select only Install Cable Drivers in the list](../../assets/screenshots/windows/2026-11-01-user-installation-options.png)

| Option | Purpose and selection for this guide |
| --- | --- |
| **Use multiple CPU cores for faster installation** | Uses multiple CPU cores during setup. Leave selected. |
| **Acquire or Manage a License Key** | Opens the license manager automatically after installation. Clear this option so DLL repair finishes before configuring the license. |
| **Install WinPcap for Ethernet Hardware Co-simulation** | Used for Ethernet hardware co-simulation. WinPcap is no longer supported, and its official site notes possible compatibility issues with newer Windows versions. Ordinary HDL design, software simulation, and USB programming do not require it. Clear this option. |
| **Install Cable Drivers** | Installs drivers for connecting programming cables and configuring devices. Leave selected. Disconnect Xilinx programming cables before driver installation. |
| **Enable WebTalk…** | May hold up installation. Clear it when possible; otherwise, the helper handles the related processes during installation. It is unrelated to simulation computation, so this guide leaves it unchecked. |

See the [WinPcap download page](https://www.winpcap.org/install/) for its compatibility information.

Click **Next** after checking the options.

## 6. Choose the installation location and Start menu name

On **Select Destination Directory**, click **Browse…** to choose a suitable location with enough space. ISE is a large installation; compare the required and available disk space shown on this page.

Leave **Create Start Menu and Desktop Icons** selected. **Select a Program Folder** sets the name in the Start menu's Programs list. Here, the name is changed to **Xilinx ISE Design Tools**, adding **ISE** to distinguish it from Vivado.

![Choose the installation location and name the Start menu folder Xilinx ISE Design Tools](../../assets/screenshots/windows/2026-11-01-user-destination-directory.png)

Click **Next** to continue.

## 7. Review the installation summary

**Options Summary** lists the components, options, and destination paths. Review them, then click **Install** and keep the helper window open.

![Options Summary includes System Generator and Version Equalizer](../../assets/screenshots/windows/2026-11-01-user-installation-summary.png)

The selected System Edition includes **System Generator**, which integrates with MATLAB. Because ISE is an older release, compatibility with your MATLAB version needs to be checked; this guide skips the MATLAB association. The **Version Equalizer** installation stage can also stall. The helper automatically detects and handles that stalled task so installation can continue.

## 8. Complete installation and automatic repair

Wait for installation to progress while keeping the helper open. It automatically handles the common WebTalk installation stall and reports its actions in the helper window.

At **Install Cable Drivers**, a **Cable Driver Installer** prompt appears. Disconnect Xilinx USB programming cables or development-board JTAG connections from the computer, then manually click **OK** to continue.

![The helper has handled WebTalk; click OK in the Cable Driver Installer prompt](../../assets/screenshots/windows/2026-11-01-user-cable-driver-confirmation.png)

A System Generator MATLAB association window may appear next. Although it detects the installed MATLAB version, we have not verified that these two versions work together, and this feature is not currently needed. Leave the checkbox clear and click **×** in the window's upper-right corner to close it and continue installation.

![MATLAB is detected; leave it unchecked and close the association window with ×](../../assets/screenshots/windows/2026-11-01-user-matlab-association.png)

After closing the MATLAB association window, keep waiting. The helper detects and handles the stalled **Version Equalizer** task. Installation then proceeds to **Install Completed**.

Click **Finish** at the bottom right to exit the official installer. Keep the helper open.

![Version Equalizer has been handled; click Finish on the completed installer](../../assets/screenshots/windows/2026-11-01-user-installation-finish.png)

Once the installer closes, the helper checks the installation result, generates repair copies, backs up and replaces DLLs, and sets the user environment variable required for the startup check. If ISE or the license manager opens automatically, close it so the helper can continue.

| Automatic DLL checks and replacement | Repair complete |
| --- | --- |
| ![After the installer closes, the helper checks, backs up, and replaces DLLs](../../assets/screenshots/windows/2026-11-01-user-dll-repair-progress.png) | ![All 13 DLL repairs and the startup check variable are complete; press Enter to exit](../../assets/screenshots/windows/2026-11-01-user-dll-repair-complete.png) |

The helper displays a completion message after all repairs finish. Press **Enter** to exit, then start ISE.

## 9. Start ISE and configure your license

Double-click the ISE desktop shortcut to open **ISE Project Navigator**. After repair, it should reach the main window without a VC runtime environment check error.

![ISE Project Navigator opens after repair](../../assets/screenshots/windows/2026-11-01-user-ise-first-launch.png)

Import your license as usual, then begin using ISE.
