# baiye-scripts

[白夜](https://baiye.dev) 配套脚本仓库。文章里提到的工具、配置文件、初始化脚本都在这里。

## VPS 一键初始化

适用于主流 Linux 发行版：

| 发行版 | 版本 | 状态 |
|--------|------|------|
| Ubuntu | 20.04 / 22.04 / 24.04 | ✅ 测试通过 |
| Debian | 11 / 12 | ✅ 支持 |
| CentOS / Rocky / AlmaLinux | 8 / 9 | ✅ 支持 |
| Fedora | 36+ | ✅ 支持 |
| Arch Linux | 滚动更新 | ✅ 支持 |

```bash
curl -fsSL https://raw.githubusercontent.com/waysup/baiye-scripts/main/vps-init.sh | bash
```

### 包含内容

| 类别 | 工具 |
|------|------|
| 安全 | UFW、fail2ban、禁用 SSH 密码登录 |
| 系统 | 时区（Asia/Shanghai）、Swap |
| 基础工具 | curl、wget、git、unzip、htop、ncdu、tree、mtr、jq |
| 现代 CLI | bat、fd、fzf、ripgrep、zoxide、duf、tldr |
| 运维效率 | lazydocker |
| 开发环境 | Docker、vim、tmux、zsh + oh-my-zsh |

## 相关文章

- [用 $6 VPS 搭建你的第一个服务器](https://baiye.dev/articles/vultr-vps-setup)

## License

MIT
