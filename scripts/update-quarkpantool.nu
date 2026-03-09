#!/usr/bin/env nu

let pkg_file = "pkgs/quarkpantool/default.nix"
let api_url = "https://api.github.com/repos/ihmily/QuarkPanTool/releases/latest"

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

let src_url = $"https://github.com/ihmily/QuarkPanTool/archive/refs/tags/($latest_tag).tar.gz"
let new_hash = (nix-hash --to-sri --type sha256 (nix-prefetch-url --unpack $src_url | str trim) | str trim)

print $"Latest src hash: ($new_hash)"

open $pkg_file --raw
  | str replace $'version = "($old_version)";' $'version = "($latest_version)";'
  | str replace -r 'hash = "[^"]*";' $'hash = "($new_hash)";'
  | save -f $pkg_file

print $"Update complete. The Nix expression is now pointing to version ($latest_version)."
