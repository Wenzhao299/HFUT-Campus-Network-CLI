# HFUT Campus Network CLI

合肥工业大学校园网（Web 认证）命令行登录/注销脚本。

支持在接入校园网后通过命令行完成认证，无需下载客户端。

## 系统兼容性

- Linux：使用 `hfut-net`（Bash 统一入口）。
- macOS：使用 `hfut-net`（Bash 统一入口，已适配无 `ip` 命令环境）。
- Windows：使用 `hfut-net.ps1`（PowerShell 统一入口）。

## 功能

- `hfut-net login <username> <password>`：统一登录入口（推荐）。
- `hfut-net logout`：统一注销入口（推荐）。
- `hfut-net keep-online [username password]`：检查在线状态，掉线自动登录（适合配合定时任务）。
- `online <username> <password>`：登录校园网。
- `offline`：注销校园网。
- 登录认证入口：`http://210.45.240.150/`。
- 内置多种认证流程回退（drcom direct / legacy portal / eportal）。
- 强制直连认证地址（`--noproxy '*'`），避免本地代理干扰。
- 登录状态判断基于 IPv4 连通性检测，避免 IPv6 免认证场景误判。

## 文件说明

- `hfut-net`：Linux / macOS 统一入口（Bash）
- `hfut-net.ps1`：Windows 统一入口（PowerShell）
- `keep-online`：Linux / macOS 在线巡检脚本
- `keep-online.ps1`：Windows 在线巡检脚本
- `online`：登录脚本
- `offline`：注销脚本
- `online.ps1`：Windows PowerShell 登录脚本
- `offline.ps1`：Windows PowerShell 注销脚本

## 依赖

Linux / macOS（Bash）需要：

- `bash`
- `curl`
- `sed`

说明：`ip`（`iproute2`）不是强制依赖，会自动回退到 `route` / `ipconfig` / `ifconfig`。

Windows（PowerShell）需要：

- `PowerShell 5.1+` 或 `PowerShell 7+`
- `curl.exe`

## 快速开始

### Linux / macOS（Bash）

1. 赋予执行权限

```bash
chmod +x hfut-net keep-online online offline
```

2. 登录

```bash
./hfut-net login 学号 密码
```

3. 注销

```bash
./hfut-net logout
```

4. 掉线自动补登录（单次检查）

```bash
./hfut-net keep-online 学号 密码
```

### Windows（PowerShell）

1. 在仓库目录执行（当前会话临时允许本地脚本）

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

2. 登录

```powershell
.\hfut-net.ps1 login 学号 密码
```

3. 注销

```powershell
.\hfut-net.ps1 logout
```

4. 掉线自动补登录（单次检查）

```powershell
.\hfut-net.ps1 keep-online 学号 密码
```

## 注册为全局命令（Linux / macOS 软链接）

将统一入口链接到 `/usr/local/bin` 后，可直接使用 `hfut-net`：

```bash
sudo ln -sf YOUR_PATH/hfut-net /usr/local/bin/hfut-net
hash -r
```

验证：

```bash
command -v hfut-net
```

## 无 sudo 的用户级安装

```bash
mkdir -p ~/.local/bin
ln -sf YOUR_PATH/hfut-net ~/.local/bin/hfut-net
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Windows 快捷命令（可选）

将以下函数写入 `$PROFILE` 后，可在 PowerShell 中直接使用 `hfut-net`：

```powershell
function hfut-net { & "YOUR_PATH\hfut-net.ps1" @args }
```

## 每小时自动检查

`keep-online` / `keep-online.ps1` 每次执行只检查一次：已联网则直接退出，掉线则自动调用登录脚本。推荐交给系统定时任务每小时运行一次。

Linux / macOS `cron` 示例：

```bash
0 * * * * HFUT_NET_USERNAME=你的学号 HFUT_NET_PASSWORD=你的密码 /ABS/PATH/hfut-net keep-online >> "$HOME/.hfut-net-keep-online.log" 2>&1
```

Windows 任务计划程序可调用：

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\PATH\hfut-net.ps1" keep-online 学号 密码
```

说明：`keep-online` 支持两种传参方式。

- 命令参数：`hfut-net keep-online 学号 密码`
- 环境变量：`HFUT_NET_USERNAME` 和 `HFUT_NET_PASSWORD`

## 常见输出

- `online: login success (drcom direct)`：登录成功（drcom 流程）。
- `online: login success (legacy portal)`：登录成功（legacy 流程）。
- `online: login success (eportal)`：登录成功（eportal 流程）。
- `login request sent, but internet check failed`：已发送登录请求，但联网验证未通过。
- `no reachable auth page from campus gateway`：无法访问认证网关。
- `offline: logout request sent (drcom)`：drcom 注销请求已发送。
- `offline: logout request sent (eportal)`：eportal 注销请求已发送。
- `offline: no reachable auth server`：未找到可访问的注销服务。
- `keep-online: already online`：当前网络已在线，无需补登录。
- `keep-online: offline detected, trying login`：检测到掉线，正在自动登录。

## 注意事项

- 需先连接 HFUT 校园网（有线/无线），再执行脚本。
- 登录命令行会暴露明文密码在 shell 历史中，建议用临时会话或后续改为交互式输入。
- 校园网策略变更后，接口参数可能需要调整。
- 请仅用于本人或经授权账号的合法认证操作，不要用于绕过网络管理策略。

## 许可证

本项目使用 `MIT License`，详见 `LICENSE` 文件。
