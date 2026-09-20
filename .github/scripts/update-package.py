#!/usr/bin/env python3
import argparse
import re
import sys

def main():
    parser = argparse.ArgumentParser(description="Update Quickflare package definition in default.nix")
    parser.add_argument("--version", help="Package version (without 'v' prefix)")
    parser.add_argument("--src-hash", help="Source tarball SRI hash")
    parser.add_argument("--pnpm-hash", help="pnpmDeps SRI hash")
    parser.add_argument("--cargo-hash", help="cargoHash SRI hash")
    parser.add_argument("--file", default="pkgs/quickflare/default.nix", help="Path to default.nix")

    args = parser.parse_args()

    with open(args.file, "r", encoding="utf-8") as f:
        content = f.read()

    # 更新版本号
    if args.version:
        content = re.sub(r'version = "[^"]*";', f'version = "{args.version}";', content, count=1)

    # 更新 src hash
    if args.src_hash:
        content = re.sub(
            r'(src = fetchFromGitHub \{[\s\S]*?hash = ")[^"]*(";)',
            rf'\g<1>{args.src_hash}\g<2>',
            content
        )

    # 更新 pnpmDeps hash
    if args.pnpm_hash:
        content = re.sub(
            r'(pnpmDeps = fetchPnpmDeps \{[\s\S]*?hash = ")[^"]*(";)',
            rf'\g<1>{args.pnpm_hash}\g<2>',
            content
        )

    # 更新 cargoHash
    if args.cargo_hash:
        content = re.sub(
            r'cargoHash = "[^"]*";',
            f'cargoHash = "{args.cargo_hash}";',
            content
        )

    with open(args.file, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Updated {args.file} successfully!")

if __name__ == "__main__":
    main()
