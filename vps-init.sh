#!/usr/bin/env bash
# =============================================================================
# baiye VPS 一键初始化脚本
# 适用于 Ubuntu 20.04+、Debian 11+、CentOS/Rocky/AlmaLinux 8+、Fedora 36+
# 用法: curl -fsSL https://raw.githubusercontent.com/waysup/baiye-scripts/main/vps-init.sh | bash
# =============================================================================
set -euo pipefail

# ── 颜色 ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}▶${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC} $*"; }
die()     { echo -e "${RED}✗ 错误：${NC}$*" >&2; exit 1; }
section() { echo -e "\n${BOLD}── $* ──────────────────────────────${NC}"; }

[[ $EUID -ne 0 ]] && die "请用 root 或 sudo 运行"

# CI 模式：跳过 systemctl / ufw / swap / timedatectl 等在容器里无效的操作
IS_CI="${CI:-false}"
[[ "$IS_CI" == "true" ]] && warn "CI 模式：跳过服务管理和系统级配置"

# ── 发行版检测 ────────────────────────────────────────────────────────────────
if [[ ! -f /etc/os-release ]]; then
  die "无法识别系统，缺少 /etc/os-release"
fi
source /etc/os-release

case "$ID" in
  ubuntu|debian|linuxmint)
    DISTRO="debian"
    PKG_UPDATE="apt-get update -qq"
    PKG_UPGRADE="apt-get upgrade -y -qq"
    PKG_INSTALL="apt-get install -y -qq"
    ;;
  centos|rhel|rocky|almalinux|ol)
    DISTRO="rhel"
    PKG_UPDATE="dnf check-update -q || true"
    PKG_UPGRADE="dnf upgrade -y -q"
    PKG_INSTALL="dnf install -y -q"
    ;;
  fedora)
    DISTRO="fedora"
    PKG_UPDATE="dnf check-update -q || true"
    PKG_UPGRADE="dnf upgrade -y -q"
    PKG_INSTALL="dnf install -y -q"
    ;;
  arch|manjaro)
    DISTRO="arch"
    PKG_UPDATE="pacman -Sy --noconfirm --quiet"
    PKG_UPGRADE="pacman -Su --noconfirm --quiet"
    PKG_INSTALL="pacman -S --noconfirm --quiet"
    ;;
  *)
    die "不支持的发行版：$ID（支持 Ubuntu/Debian/CentOS/Rocky/AlmaLinux/Fedora/Arch）"
    ;;
esac

info "检测到系统：$PRETTY_NAME（$DISTRO 系）"

# ── SSH 公钥（可选） ─────────────────────────────────────────────────────────
if [[ "$IS_CI" != "true" ]]; then
  section "SSH 公钥配置"
  echo -e "请粘贴你的 SSH 公钥（留空跳过，确保已有其他方式登录）："
  read -r SSH_PUBKEY
else
  SSH_PUBKEY=""
fi

# ── 1. 系统更新 ──────────────────────────────────────────────────────────────
section "系统更新"
eval "$PKG_UPDATE" && eval "$PKG_UPGRADE"
success "系统已更新"

# ── 2. 基础工具 ──────────────────────────────────────────────────────────────
section "基础工具"

# RHEL 系需要先装 epel-release 才能装部分工具
if [[ "$DISTRO" == "rhel" ]]; then
  $PKG_INSTALL epel-release
  dnf config-manager --set-enabled crb 2>/dev/null || true  # RHEL 9
fi

# 公共包（所有发行版名称一致）
COMMON_PKGS="curl wget git unzip htop iotop ncdu tree mtr jq vim tmux zsh fail2ban ripgrep fzf"

case "$DISTRO" in
  debian)
    $PKG_INSTALL $COMMON_PKGS \
      build-essential dstat nload ufw fd-find bat
    # Ubuntu/Debian 二进制名不同，创建软链
    command -v fdfind &>/dev/null && [[ ! -f /usr/local/bin/fd  ]] && ln -sf "$(which fdfind)" /usr/local/bin/fd
    command -v batcat &>/dev/null && [[ ! -f /usr/local/bin/bat ]] && ln -sf "$(which batcat)" /usr/local/bin/bat
    ;;
  rhel|fedora)
    $PKG_INSTALL $COMMON_PKGS \
      fd-find bat sysstat nload ufw
    dnf groupinstall -y -q "Development Tools" 2>/dev/null || true
    # fd 在 RHEL/Fedora 二进制直接叫 fd
    command -v fdfind &>/dev/null && [[ ! -f /usr/local/bin/fd ]] && ln -sf "$(which fdfind)" /usr/local/bin/fd
    ;;
  arch)
    $PKG_INSTALL $COMMON_PKGS \
      base-devel fd bat dstat nload ufw
    ;;
esac

success "基础工具安装完成"

# ── 3. 现代系统工具 ──────────────────────────────────────────────────────────
section "duf / tldr / lazydocker"

# duf（现代 df）
if ! command -v duf &>/dev/null; then
  DUF_VER=$(curl -fsSL https://api.github.com/repos/muesli/duf/releases/latest | jq -r '.tag_name' | tr -d 'v')
  curl -fsSL "https://github.com/muesli/duf/releases/latest/download/duf_${DUF_VER}_linux_amd64.deb" -o /tmp/duf.deb
  dpkg -i /tmp/duf.deb && rm /tmp/duf.deb
  success "duf 安装完成"
fi

# tldr（简明命令手册）
if ! command -v tldr &>/dev/null; then
  curl -fsSL https://github.com/dbrgn/tealdeer/releases/latest/download/tealdeer-linux-x86_64-musl \
    -o /usr/local/bin/tldr && chmod +x /usr/local/bin/tldr
  tldr --update 2>/dev/null || true
  success "tldr 安装完成"
fi

# lazydocker（Docker TUI）
if ! command -v lazydocker &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
  mv ~/.local/bin/lazydocker /usr/local/bin/lazydocker 2>/dev/null || true
  success "lazydocker 安装完成"
fi

# ── 4. zoxide ────────────────────────────────────────────────────────────────
section "zoxide（智能 cd）"
if ! command -v zoxide &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
  mv ~/.local/bin/zoxide /usr/local/bin/zoxide 2>/dev/null || true
fi
success "zoxide 安装完成"

# ── 5. Docker ────────────────────────────────────────────────────────────────
section "Docker"
if [[ "$IS_CI" == "true" ]]; then
  warn "CI 模式：跳过 Docker 安装"
elif ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
  if [[ -n "${SUDO_USER:-}" ]]; then
    usermod -aG docker "$SUDO_USER"
    info "已将 $SUDO_USER 加入 docker 组，重新登录后生效"
  fi
  success "Docker $(docker --version | awk '{print $3}' | tr -d ',')"
else
  success "Docker $(docker --version | awk '{print $3}' | tr -d ',')"
fi

# ── 5. 时区 ──────────────────────────────────────────────────────────────────
section "时区"
if [[ "$IS_CI" == "true" ]]; then
  warn "CI 模式：跳过时区设置"
else
  timedatectl set-timezone Asia/Shanghai
  success "时区设置为 Asia/Shanghai"
fi

# ── 6. Swap（1GB 内存 VPS 必备） ─────────────────────────────────────────────
section "Swap"
if [[ "$IS_CI" == "true" ]]; then
  warn "CI 模式：跳过 Swap 配置"
elif [[ ! -f /swapfile ]]; then
  RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
  if [[ $RAM_MB -lt 2048 ]]; then
    SWAP_SIZE="2G"
  else
    SWAP_SIZE="1G"
  fi
  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo 'vm.swappiness=10' >> /etc/sysctl.conf
  sysctl -p -q
  success "Swap 已创建：$SWAP_SIZE"
elif [[ "$IS_CI" != "true" ]]; then
  warn "Swap 已存在，跳过"
fi

# ── 7. 防火墙 ────────────────────────────────────────────────────────────────
section "防火墙"
if [[ "$IS_CI" == "true" ]]; then
  warn "CI 模式：跳过防火墙配置"
elif [[ "$DISTRO" == "rhel" || "$DISTRO" == "fedora" ]] && command -v firewall-cmd &>/dev/null; then
  # RHEL 系使用 firewalld
  systemctl enable --now firewalld
  firewall-cmd --permanent --set-default-zone=drop
  firewall-cmd --permanent --add-service=ssh
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --reload
  success "firewalld 已配置：只开放 22/80/443"
else
  # Debian/Ubuntu/Arch 使用 ufw
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp comment 'SSH'
  ufw allow 80/tcp comment 'HTTP'
  ufw allow 443/tcp comment 'HTTPS'
  ufw --force enable
  success "UFW 已配置：只开放 22/80/443"
fi

# ── 8. SSH 加固 ──────────────────────────────────────────────────────────────
section "SSH 加固"

# 写入 SSH 公钥
if [[ -n "$SSH_PUBKEY" ]]; then
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  echo "$SSH_PUBKEY" >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  success "SSH 公钥已添加"
fi

# 禁用密码登录
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
# 禁止 root 密码登录（保留密钥登录）
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl reload sshd
success "SSH 密码登录已禁用"

# ── 9. fail2ban ──────────────────────────────────────────────────────────────
section "fail2ban"
cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled  = true
port     = 22
maxretry = 5
findtime = 600
bantime  = 3600
EOF
systemctl enable --now fail2ban
success "fail2ban 已启动，SSH 10分钟内失败5次封禁1小时"

# ── 10. zsh 配置 ─────────────────────────────────────────────────────────────
section "zsh 配置"

# oh-my-zsh（非交互模式）
if [[ ! -d ~/.oh-my-zsh ]]; then
  RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# zsh-autosuggestions
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions" -q
fi

# zsh-syntax-highlighting
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" -q
fi

# 写入 .zshrc
cat > ~/.zshrc << 'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf)
source $ZSH/oh-my-zsh.sh

# 现代工具别名
alias ls='ls --color=auto'
alias ll='ls -lah'
alias cat='bat --paging=never'
alias grep='rg'
alias find='fd'
alias vim='vim'

# fzf
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# zoxide（智能 cd）
eval "$(zoxide init zsh)"

# tmux 自动启动（SSH 登录时）
if [[ -z "$TMUX" ]] && [[ -n "$SSH_CONNECTION" ]]; then
  tmux attach-session -t main 2>/dev/null || tmux new-session -s main
fi
ZSHRC

# 设置默认 shell 为 zsh
chsh -s "$(which zsh)" root
success "zsh 配置完成"

# ── 11. tmux 配置 ────────────────────────────────────────────────────────────
section "tmux 配置"
cat > ~/.tmux.conf << 'TMUX'
# 前缀键改为 Ctrl+a（更顺手）
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# 分屏快捷键
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"

# 鼠标支持
set -g mouse on

# 状态栏
set -g status-style bg=colour235,fg=colour250
set -g status-left "#[fg=colour214,bold] #S "
set -g status-right "#[fg=colour246] %Y-%m-%d %H:%M "
set -g status-right-length 50

# 256色
set -g default-terminal "screen-256color"

# 窗口编号从 1 开始
set -g base-index 1
setw -g pane-base-index 1

# 减少 ESC 延迟（vim 用户必须）
set -sg escape-time 10
TMUX
success "tmux 配置完成"

# ── 12. vim 配置 ─────────────────────────────────────────────────────────────
section "vim 配置"
cat > ~/.vimrc << 'VIMRC'
syntax on
set number relativenumber
set tabstop=4 shiftwidth=4 expandtab
set smartindent
set hlsearch incsearch ignorecase smartcase
set clipboard=unnamedplus
set mouse=a
set cursorline
set scrolloff=8
set nowrap
set encoding=utf-8
set backspace=indent,eol,start
colorscheme desert
VIMRC
success "vim 配置完成"

# ── 完成 ─────────────────────────────────────────────────────────────────────
section "完成"
echo -e "
${GREEN}${BOLD}初始化完成！${NC}

已完成：
  ✓ 系统更新
  ✓ 基础工具（htop / ncdu / tree / mtr / jq）
  ✓ 现代 CLI（bat / fd / fzf / rg / zoxide / duf / tldr / lazydocker）
  ✓ Docker
  ✓ Swap $(if [[ -f /swapfile ]]; then echo "已配置"; else echo "已存在"; fi)
  ✓ UFW（22/80/443）
  ✓ SSH 密码登录已禁用
  ✓ fail2ban SSH 防暴力破解
  ✓ zsh + oh-my-zsh + 插件
  ✓ tmux 配置
  ✓ vim 配置

${YELLOW}重新登录后 shell 自动切换为 zsh${NC}
"
