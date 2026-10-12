#!/usr/bin/env python3
import argparse
import base64
import os
import re
import sys
import urllib.request

USER_AGENT = "curl/7.88.1"

def hex_to_sri(hex_hash: str) -> str:
    """将 64 位十六进制 SHA256 哈希转换为 SRI 格式 (sha256-xxx=)"""
    b = bytes.fromhex(hex_hash.strip())
    return f"sha256-{base64.b64encode(b).decode()}"

def fetch_url(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8")

def parse_deb_packages(packages_content: str):
    """从 Debian Packages 文件中提取 Version 和 SHA256"""
    version_match = re.search(r"^Version:\s*([^\s]+)", packages_content, re.MULTILINE)
    sha256_match = re.search(r"^SHA256:\s*([0-9a-fA-F]{64})", packages_content, re.MULTILINE)

    if not version_match or not sha256_match:
        raise ValueError("无法在 Packages 清单中解析 Version 或 SHA256")

    return version_match.group(1), sha256_match.group(1)

def update_chatgpt(default_nix_path: str = "pkgs/external/chatgpt/default.nix", force: bool = False):
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

    with open(default_nix_path, "r", encoding="utf-8") as f:
        content = f.read()

    local_version_match = re.search(r'version\s*=\s*"([^"]+)";', content)
    local_version = local_version_match.group(1) if local_version_match else None
    print(f"Current local ChatGPT version: {local_version}")

    if not force and local_version == latest_version:
        print("ChatGPT is already up to date喵！")
        return False, latest_version

    print(f"Updating ChatGPT: {local_version} -> {latest_version}...")

    # 更新 version
    content = re.sub(r'version\s*=\s*"[^"]*";', f'version = "{latest_version}";', content, count=1)

    # 更新 x86_64-linux hash
    content = re.sub(
        r'(x86_64-linux\s*=\s*\{[\s\S]*?hash\s*=\s*")[^"]*(";)',
        rf'\g<1>{amd64_sri}\g<2>',
        content
    )

    # 更新 aarch64-linux hash
    content = re.sub(
        r'(aarch64-linux\s*=\s*\{[\s\S]*?hash\s*=\s*")[^"]*(";)',
        rf'\g<1>{arm64_sri}\g<2>',
        content
    )

    with open(default_nix_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Successfully updated {default_nix_path}喵！")
    return True, latest_version

def main():
    parser = argparse.ArgumentParser(description="Check and update external packages")
    parser.add_argument("--package", choices=["chatgpt", "all"], default="all", help="Target package to check")
    parser.add_argument("--force", action="store_true", help="Force update even if version matches")
    args = parser.parse_args()

    updated_packages = []

    if args.package in ["chatgpt", "all"]:
        updated, ver = update_chatgpt(force=args.force)
        if updated:
            updated_packages.append(f"chatgpt={ver}")

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
