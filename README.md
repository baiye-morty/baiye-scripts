# baiye-scripts

[![Test vps-init.sh](https://github.com/baiye-morty/baiye-scripts/actions/workflows/test.yml/badge.svg)](https://github.com/baiye-morty/baiye-scripts/actions/workflows/test.yml)

[白夜](https://baiye.dev) 配套脚本仓库。文章里提到的工具、配置文件、初始化脚本都在这里。

## VPS 一键初始化

```bash
curl -fsSL https://raw.githubusercontent.com/baiye-morty/baiye-scripts/main/vps-init.sh | bash
```

> 需要 root 权限。运行时会提示粘贴 SSH 公钥，留空跳过。

适用于主流 Linux 发行版：

| 发行版 | 版本 | 状态 |
|--------|------|------|
| Ubuntu | 22.04 / 24.04 | ✅ CI 验证 |
| Debian | 12 | ✅ CI 验证 |
| Rocky Linux | 9 | ✅ CI 验证 |
| Fedora | latest | ✅ CI 验证 |
| CentOS / AlmaLinux | 8 / 9 | 兼容（未 CI 验证） |
| Arch Linux | 滚动更新 | 兼容（未 CI 验证） |

### 包含内容

| 类别 | 工具 |
|------|------|
| 安全 | UFW / firewalld、fail2ban、禁用 SSH 密码登录 |
| 系统 | 时区（Asia/Shanghai）、Swap |
| 基础工具 | curl、wget、git、unzip、htop、ncdu、tree、mtr、jq |
| 现代 CLI | bat、fd、fzf、ripgrep、zoxide、duf、tldr |
| 运维效率 | lazydocker |
| 开发环境 | Docker、vim、tmux、zsh + oh-my-zsh |

## 相关文章

- [新 VPS 到手第一件事：一键初始化脚本](https://baiye.dev/articles/vps-init-script)
- [用 $6 VPS 搭建你的第一个服务器](https://baiye.dev/articles/vultr-vps-setup)

## License

MIT
