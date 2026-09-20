# Aloys's Nix Packages Repository

个人 Nix 软件源仓库，包含 Quickflare 等自研工具喵。支持直接运行、系统集成以及 Cachix 二进制加速。

---

## ⚡ 快速使用 (免安装直接运行)

```bash
nix run github:Aloys233/nix-packages#quickflare
```

---

## 📦 集成到 NixOS 系统

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

本仓库已配置 Cachix 二进制缓存（`aloys23`），无需本地编译：

```bash
# 方式 1：CLI 一键启用
cachix use aloys23

# 方式 2：在 configuration.nix 中配置
nix.settings = {
  substituters = [ "https://aloys23.cachix.org" ];
  trusted-public-keys = [ "aloys23.cachix.org-1:COmV4eR1tSqvJ/e7tzDrpvG0RaB14pl3YgX9vH7YWNo=" ];
};
```
