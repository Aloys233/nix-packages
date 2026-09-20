#!/usr/bin/env python3
import re
import sys

def main():
    if len(sys.argv) < 3:
        print("Usage: update-package.py <version> <src_hash> [pnpm_hash] [cargo_hash]")
        sys.exit(1)

    version = sys.argv[1]
    src_hash = sys.argv[2]
    pnpm_hash = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else None
    cargo_hash = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else None

    target_file = "pkgs/quickflare/default.nix"
    with open(target_file, "r") as f:
        content = f.read()

    # 更新版本号
    content = re.sub(r'version = "[^"]*";', f'version = "{version}";', content, count=1)

    # 更新 src hash
    content = re.sub(
        r'(src = fetchFromGitHub \{[\s\S]*?hash = ")[^"]*(";)',
        rf'\g<1>{src_hash}\g<2>',
        content
    )

    # 更新 pnpmDeps hash
    if pnpm_hash:
        content = re.sub(
            r'(pnpmDeps = fetchPnpmDeps \{[\s\S]*?hash = ")[^"]*(";)',
            rf'\g<1>{pnpm_hash}\g<2>',
            content
        )

    # 更新 cargoHash
    if cargo_hash:
        content = re.sub(
            r'cargoHash = "[^"]*";',
            f'cargoHash = "{cargo_hash}";',
            content
        )

    with open(target_file, "w") as f:
        f.write(content)

    print(f"Updated {target_file} successfully!")

if __name__ == "__main__":
    main()
