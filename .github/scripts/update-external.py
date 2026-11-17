#!/usr/bin/env python3
import argparse
import base64
import json
import os
import re
import subprocess
import urllib.request

USER_AGENT = "curl/7.88.1"


def hex_to_sri(hex_hash: str) -> str:
    """将 64 位十六进制 SHA256 哈希转换为 SRI 格式 (sha256-xxx=)"""
    b = bytes.fromhex(hex_hash.strip())
    return f"sha256-{base64.b64encode(b).decode()}"


def fetch_url(url: str, headers: dict | None = None) -> str:
    """请求指定 URL 并返回 UTF-8 文本内容"""
    req_headers = {"User-Agent": USER_AGENT}
    if headers:
        req_headers.update(headers)
    req = urllib.request.Request(url, headers=req_headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8")


def read_local_version(default_nix_path: str) -> str | None:
    """从 default.nix 中读取当前版本号"""
    with open(default_nix_path, "r", encoding="utf-8") as f:
        content = f.read()
    match = re.search(r'version\s*=\s*"([^"]+)";', content)
    return match.group(1) if match else None


def apply_nix_updates(default_nix_path: str, version: str, platform_hashes: dict[str, str]):
    """更新 default.nix 中的 version 与各平台 hash"""
    with open(default_nix_path, "r", encoding="utf-8") as f:
        content = f.read()

    content = re.sub(r'version\s*=\s*"[^"]*";', f'version = "{version}";', content, count=1)

    for platform, sri_hash in platform_hashes.items():
        pattern = rf'({re.escape(platform)}\s*=\s*\{{[\s\S]*?hash\s*=\s*")[^"]*(";)'
        updated_content, count = re.subn(pattern, rf'\g<1>{sri_hash}\g<2>', content, count=1)
        if count == 0:
            raise ValueError(f"未能在 {default_nix_path} 中找到平台 {platform} 的 hash 字段")
        content = updated_content

    with open(default_nix_path, "w", encoding="utf-8") as f:
        f.write(content)


def nix_prefetch_file(url: str) -> dict:
    """使用 nix store prefetch-file 下载文件并返回包含 hash 与 storePath 的字典"""
    result = subprocess.run(
        [
            "nix",
            "--extra-experimental-features",
            "nix-command",
            "store",
            "prefetch-file",
            "--json",
            "--hash-type",
            "sha256",
            url,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def parse_deb_packages(packages_content: str):
    """从 Debian Packages 文件中提取 Version 和 SHA256"""
    version_match = re.search(r"^Version:\s*([^\s]+)", packages_content, re.MULTILINE)
    sha256_match = re.search(r"^SHA256:\s*([0-9a-fA-F]{64})", packages_content, re.MULTILINE)

    if not version_match or not sha256_match:
        raise ValueError("无法在 Packages 清单中解析 Version 或 SHA256")

    return version_match.group(1), sha256_match.group(1)


def update_chatgpt(default_nix_path: str = "pkgs/external/chatgpt/default.nix", force: bool = False):
    """检查并更新 ChatGPT 客户端包"""
    print("Checking ChatGPT updates from official Debian repository...")
    amd64_url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages"
    arm64_url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-arm64/Packages"

    amd64_pkg = fetch_url(amd64_url)
    arm64_pkg = fetch_url(arm64_url)

    latest_version, amd64_sha256 = parse_deb_packages(amd64_pkg)
    _, arm64_sha256 = parse_deb_packages(arm64_pkg)

    amd64_sri = hex_to_sri(amd64_sha256)
    arm64_sri = hex_to_sri(arm64_sha256)

    print(f"Latest upstream ChatGPT version: {latest_version}")
    print(f"  amd64 SRI: {amd64_sri}")
    print(f"  arm64 SRI: {arm64_sri}")

    local_version = read_local_version(default_nix_path)
    print(f"Current local ChatGPT version: {local_version}")

    if not force and local_version == latest_version:
        print("ChatGPT is already up to date喵！")
        return False, latest_version

    print(f"Updating ChatGPT: {local_version} -> {latest_version}...")
    apply_nix_updates(
        default_nix_path,
        latest_version,
        {
            "x86_64-linux": amd64_sri,
            "aarch64-linux": arm64_sri,
        },
    )

    print(f"Successfully updated {default_nix_path}喵！")
    return True, latest_version


def update_osu_lazer_bin(
    default_nix_path: str = "pkgs/external/osu-lazer-bin/default.nix",
    force: bool = False,
):
    """检查并更新 osu-lazer-bin 包（x86_64-linux）"""
    print("Checking osu-lazer-bin updates from GitHub Releases...")
    headers = {"Accept": "application/vnd.github+json"}
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    release = json.loads(fetch_url("https://api.github.com/repos/ppy/osu/releases/latest", headers=headers))
    tag_name = release.get("tag_name") or release.get("name")
    if not tag_name or not tag_name.endswith("-lazer"):
        raise ValueError(f"无法解析 osu! lazer 发布标签: {tag_name}")

    latest_version = tag_name[: -len("-lazer")]
    local_version = read_local_version(default_nix_path)

    print(f"Latest upstream osu-lazer-bin version: {latest_version}")
    print(f"Current local osu-lazer-bin version: {local_version}")

    if not force and local_version == latest_version:
        print("osu-lazer-bin is already up to date喵！")
        return False, latest_version

    assets = {asset["name"]: asset for asset in release.get("assets", [])}
    linux_asset = assets.get("osu.AppImage")
    if not linux_asset:
        raise ValueError(f"Release {tag_name} 缺少 osu.AppImage")

    # x86_64-linux 使用 fetchurl，优先直接转换 GitHub API 返回的 sha256 digest
    digest = linux_asset.get("digest") or ""
    if digest.startswith("sha256:") and len(digest.split(":", 1)[1]) == 64:
        linux_sri = hex_to_sri(digest.split(":", 1)[1])
    else:
        linux_sri = nix_prefetch_file(linux_asset["browser_download_url"])["hash"]

    print(f"  x86_64-linux SRI: {linux_sri}")
    print(f"Updating osu-lazer-bin: {local_version} -> {latest_version}...")

    apply_nix_updates(
        default_nix_path,
        latest_version,
        {"x86_64-linux": linux_sri},
    )

    print(f"Successfully updated {default_nix_path}喵！")
    return True, latest_version


def main():
    parser = argparse.ArgumentParser(description="Check and update external packages")
    parser.add_argument(
        "--package",
        choices=["chatgpt", "osu-lazer-bin", "all"],
        default="all",
        help="Target package to check",
    )
    parser.add_argument("--force", action="store_true", help="Force update even if version matches")
    args = parser.parse_args()

    updated_packages = []

    if args.package in ["chatgpt", "all"]:
        updated, ver = update_chatgpt(force=args.force)
        if updated:
            updated_packages.append(f"chatgpt={ver}")

    if args.package in ["osu-lazer-bin", "all"]:
        updated, ver = update_osu_lazer_bin(force=args.force)
        if updated:
            updated_packages.append(f"osu-lazer-bin={ver}")

    gh_output = os.environ.get("GITHUB_OUTPUT")
    if gh_output:
        with open(gh_output, "a", encoding="utf-8") as f:
            if updated_packages:
                f.write("has_updates=true\n")
                f.write(f"updated_packages={','.join(updated_packages)}\n")
            else:
                f.write("has_updates=false\n")


if __name__ == "__main__":
    main()
