#!/usr/bin/env nu

let pkg_file = "pkgs/baidupcs-go/default.nix"
let api_url = "https://api.github.com/repos/qjfoidnh/BaiduPCS-Go/releases/latest"

let release_data = (http get $api_url)
let latest_tag = ($release_data | get tag_name)

if ($latest_tag | is-empty) {
  print -e "Failed to fetch latest release tag."
  exit 1
}

let latest_version = ($latest_tag | str replace -r '^v' '')
let old_version = (open $pkg_file --raw | lines
  | where { $in | str contains 'version = "' }
  | first
  | parse -r 'version = "([^"]+)"'
  | first
  | get capture0)

print $"Current version: ($old_version)"
print $"Latest version:  ($latest_version)"

if $latest_version == $old_version {
  print "Package is already up-to-date. No changes needed."
  exit 0
}

let src_url = $"https://github.com/qjfoidnh/BaiduPCS-Go/archive/refs/tags/($latest_tag).tar.gz"
let new_hash = (nix-hash --to-sri --type sha256 (nix-prefetch-url --unpack $src_url | str trim) | str trim)

print $"Latest src hash: ($new_hash)"

let placeholder_vendor_hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

open $pkg_file --raw
  | str replace $'version = "($old_version)";' $'version = "($latest_version)";'
  | str replace -r 'hash = "[^"]*";' $'hash = "($new_hash)";'
  | str replace -r 'vendorHash = "[^"]*";' $'vendorHash = "($placeholder_vendor_hash)";'
  | save -f $pkg_file

print "Calculating vendorHash..."
let build_output = (do { nix build .#baidupcs-go --no-link } | complete | get stderr)
let parsed = ($build_output | parse -r 'got:\s+(sha256-[A-Za-z0-9+/=]+)')

if ($parsed | is-empty) {
  print -e "Failed to determine vendorHash. Build output:"
  print -e $build_output
  exit 1
}

let vendor_hash = ($parsed | first | get capture0)

open $pkg_file --raw
  | str replace $'vendorHash = "($placeholder_vendor_hash)";' $'vendorHash = "($vendor_hash)";'
  | save -f $pkg_file

print $"Updated vendorHash: ($vendor_hash)"
