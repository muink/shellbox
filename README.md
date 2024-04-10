<h1 align="center">
<pre>
 ___ _        _ _ ___        　
/ __| |_  ___| | | _ ) _____ __
\__ \ ' \/ -_) | | _ \/ _ \ \ /
|___/_||_\___|_|_|___/\___/_\_\
</pre>
</h1>

![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat-square&logo=linux&logoColor=black)
![Windows](https://img.shields.io/badge/Windows-0078D6?style=flat-square&logo=windows&logoColor=white)
![macOS](https://img.shields.io/badge/mac%20os-000000?style=flat-square&logo=macos&logoColor=F0F0F0)<br/>
[![Releases](https://img.shields.io/github/release/muink/shellbox.svg?style=flat-square&label=shellbox&colorB=green)](https://github.com/muink/shellbox/releases)
[![Releases](https://img.shields.io/badge/Documentation-8A2BE2?style=flat-square)](./docs/README.md)
[![Releases](https://img.shields.io/github/license/muink/shellbox?style=flat-square&colorB=blue)](./LICENSE)

This project is a simple sing-box client running on Linux, Windows and MacOS.

## Features

+ Use management script to use sing-box in a shell environment
+ Automatically import subscriptions nodes (v2ray format only)
+ Generate complete sing-box config file from templates
+ Online upgrade
+ Install service or auto-start
+ Create Shortcut

## Manual

### First running

**NOTE:** May not work properly when path contains spaces and special characters

1. Initialize environment
   + 🐧`Linux`: Run `./tool.sh`, and follow the prompts to install missing dependencies.
   + 🍎`MacOS`: Install [Homebrew][], then run `./tool.sh`, and follow the prompts to install missing dependencies.
   + 🪟`Windows`: Install [Cygwin][] or [MinGW64][] or [Git4windows][], then run `./tool.sh`, and follow the prompts to install missing dependencies.
2. Download core
   + Run `./tool.sh`, type **5** to Upgrade core.
3. Installation dashboard (Optional)
   + Put dashboard assets into `./resources/ui/`.

### How to configure it

See [Readme](./docs/README.md).

### Generate config and setup sing-box

1. Exec `./tool.sh -ug --setup`
2. User mode
   + 🐧`Linux`: Run `./shellbox.desktop`.
   + 🍎`MacOS`: Run `./shellbox.command`.
   + 🪟`Windows`: Run `./shellbox.bat`.
3. Service mode control

### How to safely uninstall service or auto-start

1. Automatically
   + Disable `service_mode`, `start_at_boot` in `settings.json`
   + Run `./tool.sh --setup`
2. Manually
   + Service
      + 🐧`Linux`:
         + systemd: Run `sudo systemctl stop shellbox; sudo systemctl disable shellbox; sudo rm -f /etc/systemd/system/shellbox.service`
      + 🍎`MacOS`: Run `cd /Library/LaunchDaemons; sudo launchctl unload shellbox.service.plist; sudo rm -f shellbox.service.plist`.
      + 🪟`Windows`: Open Windows schedule, remove `ShellBox` task.
   + Auto-start
      + 🐧`Linux`: Remove the line containing `shellbox_core` from `/etc/crontab`.
      + 🍎`MacOS`: Remove `shellbox.command` from [Login items][].
      + 🪟`Windows`: Enter `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup` directory, remove `shellbox.bat`.

## Usage

**Command line mode:**

``` shell
Usage: tool.sh [OPTION]...

  e.g. tool.sh -g          -- Rebuild configs
  e.g. tool.sh -V          -- Returns version

Options:
  -e                       -- Redirect error message to log file
  -g, --generate           -- Rebuild configs
  -u, --update             -- Update subscriptions
  --setup                  -- Setup sing-box
  -V, --version            -- Returns version
  -h, --help               -- Returns help info
```

**Interactive mode:**

``` shell
                     [Menu]

        1. Rebuild configs
        2. Update subscriptions
        3. Check update
        4. Upgrade shellbox
        5. Upgrade core
      ------------------------------
        a. Setup sing-box with current config
        b. Start service
        c. Stop service
        x. Exit
```


[Homebrew]: https://brew.sh/
[Cygwin]: https://www.cygwin.com/
[MinGW64]: https://www.mingw-w64.org/
[Git4windows]: https://git-scm.com/
[Login items]: https://support.apple.com/guide/mac-help/remove-login-items-resolve-startup-problems-mh21210/mac
