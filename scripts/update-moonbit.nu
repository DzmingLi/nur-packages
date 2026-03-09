#!/usr/bin/env nu

let pkg_file = "pkgs/moonbit/default.nix"
let binary_url = "https://cli.moonbitlang.com/binaries/latest/moonbit-linux-x86_64.tar.gz"
let core_url = "https://cli.moonbitlang.com/cores/core-latest.tar.gz"

let content = open $pkg_file --raw

let old_binary_hash = ($content | lines
  | window 2
  | where { ($in.0 | str contains $binary_url) and ($in.1 | str contains "sha256") }
  | first
  | get 1
  | parse -r 'sha256 = "([^"]+)"'
  | first
  | get capture0)

let old_core_hash = ($content | lines
  | window 2
  | where { ($in.0 | str contains $core_url) and ($in.1 | str contains "sha256") }
  | first
  | get 1
  | parse -r 'sha256 = "([^"]+)"'
  | first
  | get capture0)

print $"Current binary hash: ($old_binary_hash)"
print $"Current core hash:   ($old_core_hash)"

let new_binary_hash = (nix-hash --to-sri --type sha256 (nix-prefetch-url --unpack $binary_url | str trim))
let new_core_hash = (nix-hash --to-sri --type sha256 (nix-prefetch-url --unpack $core_url | str trim))

print $"Latest binary hash: ($new_binary_hash)"
print $"Latest core hash:   ($new_core_hash)"

if $old_binary_hash != $new_binary_hash or $old_core_hash != $new_core_hash {
  print $"New version found! Updating ($pkg_file)..."
  let updated = ($content
    | str replace $'sha256 = "($old_binary_hash)";' $'sha256 = "($new_binary_hash)";'
    | str replace $'sha256 = "($old_core_hash)";' $'sha256 = "($new_core_hash)";')
  $updated | save -f $pkg_file
  print "Update complete. The Nix expression is now pointing to the latest version."
} else {
  print "Package is already up-to-date. No changes needed."
}
