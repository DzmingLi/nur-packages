#!/usr/bin/env nu

let pkg_file = "pkgs/wechat/default.nix"
let appimage_urls = [
  "https://dldir1.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage"
  "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage"
]

let old_hash = (open $pkg_file --raw | lines
  | where { $in | str contains 'hash = "' }
  | first
  | parse -r 'hash = "([^"]+)"'
  | first
  | get capture0)

print $"Current hash: ($old_hash)"

mut new_hash = ""
mut used_url = ""
for url in $appimage_urls {
  let result = try {
    let prefetch_path = (nix-prefetch-url $url | str trim)
    let hash = (nix-hash --to-sri --type sha256 $prefetch_path | str trim)
    { hash: $hash, url: $url }
  } catch {
    null
  }
  if $result != null {
    $new_hash = $result.hash
    $used_url = $result.url
    break
  }
}

if $new_hash == "" {
  print -e "Failed to download WeChat AppImage from all URLs."
  exit 1
}

print $"Using URL:   ($used_url)"
print $"Latest hash:  ($new_hash)"

if $old_hash != $new_hash {
  print $"New version found! Updating ($pkg_file)..."
  open $pkg_file --raw
    | str replace $'hash = "($old_hash)";' $'hash = "($new_hash)";'
    | save -f $pkg_file
  print "Update complete. The Nix expression is now pointing to the latest version."
} else {
  print "Package is already up-to-date. No changes needed."
}
