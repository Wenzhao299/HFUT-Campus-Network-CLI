# HFUT Campus Network CLI

合肥工业大学校园网（Web 认证）命令行登录/注销脚本。

支持在接入校园网后通过命令行完成认证，无需下载客户端。

## 功能

- `online <username> <password>`：登录校园网。
- `offline`：注销校园网。
- 自动兼容多个认证入口：`172.16.200.11`、`172.16.200.12`、`192.168.4.1`。
- 内置多种认证流程回退（drcom direct / legacy portal / eportal）。
- 强制直连认证地址（`--noproxy '*'`），避免本地代理干扰。
- 登录状态判断基于 IPv4 连通性检测，避免 IPv6 免认证场景误判。

## 文件说明

- `online`：登录脚本
- `offline`：注销脚本

## 依赖

需要系统中可用以下命令：

- `bash`
- `curl`
- `ip`（`iproute2`）
- `sed`

## 快速开始

1. 赋予执行权限

```bash
chmod +x online offline
```

2. 登录

```bash
./online 学号 密码
```

3. 注销

```bash
./offline
```

## 注册为全局命令（软链接）

将脚本链接到 `/usr/local/bin` 后，可直接使用 `online` / `offline`：

```bash
sudo ln -sf YOUR_PATH/online /usr/local/bin/online
sudo ln -sf YOUR_PATH/offline /usr/local/bin/offline
hash -r
```

验证：

```bash
command -v online offline
```

## 无 sudo 的用户级安装

```bash
mkdir -p ~/.local/bin
ln -sf YOUR_PATH/online ~/.local/bin/online
ln -sf YOUR_PATH/offline ~/.local/bin/offline
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 常见输出

- `online: login success (drcom direct)`：登录成功（drcom 流程）。
- `online: login success (legacy portal)`：登录成功（legacy 流程）。
- `online: login success (eportal)`：登录成功（eportal 流程）。
- `login request sent, but internet check failed`：已发送登录请求，但联网验证未通过。
- `no reachable auth page from campus gateway`：无法访问认证网关。
- `offline: logout request sent (drcom)`：drcom 注销请求已发送。
- `offline: logout request sent (eportal)`：eportal 注销请求已发送。
- `offline: no reachable auth server`：未找到可访问的注销服务。

## 注意事项

- 需先连接 HFUT 校园网（有线/无线），再执行脚本。
- 登录命令行会暴露明文密码在 shell 历史中，建议用临时会话或后续改为交互式输入。
- 校园网策略变更后，接口参数可能需要调整。
- 请仅用于本人或经授权账号的合法认证操作，不要用于绕过网络管理策略。

## 许可证

本项目使用 `MIT License`，详见 `LICENSE` 文件。
