# Aloys's Nix Packages Repository

个人 Nix 软件源仓库喵！包含自研工具与常用第三方软件。支持直接运行、系统集成以及 Cachix 二进制加速。

- **自研软件 (`pkgs/self/`)**：Quickflare、KomiraQuake、OtoMusic 等（在上游仓库发布时由 GitHub Actions 事件实时通知更新喵）。
- **第三方软件 (`pkgs/external/`)**：ChatGPT Desktop 等（通过 GitHub Actions 定时任务每天自动轮询上游发布并同步更新喵）。

---

## ⚡ 快速使用 (免安装直接运行)

### Quickflare

```bash
nix run github:Aloys233/nix-packages#quickflare
```

### KomiraQuake 地震预警

```bash
nix run github:Aloys233/nix-packages#komiraquake
```

> KomiraQuake 的语音播报依赖 speech-dispatcher，NixOS 上需开启：
> `services.speechd.enable = true;`

### OtoMusic 音乐播放器

专为 Navidrome / Subsonic 打造的桌面音乐播放器喵！内置 mpv 高音质解码支持与全平台托盘控制。

```bash
nix run github:Aloys233/nix-packages#otomusic
```

### ChatGPT Desktop (官方 Linux 客户端)

```bash
nix run github:Aloys233/nix-packages#chatgpt --impure
```

> ChatGPT 支持读取 `~/.config/chatgpt-flags.conf` 自定义启动参数（如 Wayland 标志）喵。此外也可用别名 `chatgpt-desktop`。

---

## 📦 集成到 NixOS 系统

> 下面示例用 `quickflare` 演示，把包名换成 `komiraquake` 即可安装地震预警客户端。

### 方式 A：作为 Flake Input 引入

在您的系统的 `flake.nix` 中：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    aloys-pkgs.url = "github:Aloys233/nix-packages";
  };

  outputs = { self, nixpkgs, aloys-pkgs, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            aloys-pkgs.packages.${pkgs.system}.quickflare
          ];
        })
      ];
    };
  };
}
```

### 方式 B：使用 Overlay (直接作为 pkgs 成员使用)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    aloys-pkgs.url = "github:Aloys233/nix-packages";
  };

  outputs = { self, nixpkgs, aloys-pkgs, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ aloys-pkgs.overlays.default ];

          environment.systemPackages = with pkgs; [
            quickflare
          ];
        })
      ];
    };
  };
}
```

---

## 🚀 Cachix 二进制加速

本仓库为自研工具配置了 Cachix 二进制缓存（`aloys23`），无需本地编译：

> 💡 **提示**：Cachix 缓存主要用于加速自研软件的编译产物喵。第三方应用（如 ChatGPT Desktop）直接解包官方 Release deb 并就地 patch，不推送到个人 Cachix 缓存中喵。

```bash
# 方式 1：CLI 一键启用
cachix use aloys23

# 方式 2：在 configuration.nix 中配置
nix.settings = {
  substituters = [ "https://aloys23.cachix.org" ];
  trusted-public-keys = [ "aloys23.cachix.org-1:COmV4eR1tSqvJ/e7tzDrpvG0RaB14pl3YgX9vH7YWNo=" ];
};
```
