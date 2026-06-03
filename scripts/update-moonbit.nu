#!/usr/bin/env nu

let pkg_file = "pkgs/moonbit-nightly/default.nix"
let core_url = "https://cli.moonbitlang.com/cores/core-nightly.tar.gz"
let binaries = [
  { url: "https://cli.moonbitlang.com/binaries/nightly/moonbit-linux-x86_64.tar.gz" }
  { url: "https://cli.moonbitlang.com/binaries/nightly/moonbit-darwin-aarch64.tar.gz" }
]

def fetch-sri [url: string] {
  ^nix-hash --to-sri --type sha256 (^nix-prefetch-url --unpack $url | str trim) | str trim
}

def find-hash-near-url [content: string, url: string]: nothing -> string {
  $content | lines
    | window 2
    | where { ($in.0 | str contains $url) and ($in.1 | str contains "sha256") }
    | first
    | get 1
    | parse -r 'sha256 = "([^"]+)"'
    | first
    | get capture0
}

mut content = open $pkg_file --raw
let old_core_hash = (find-hash-near-url $content $core_url)
let new_core_hash = (fetch-sri $core_url)
print $"core: ($old_core_hash) -> ($new_core_hash)"

mut updates = [
  { label: "core", url: $core_url, old: $old_core_hash, new: $new_core_hash }
]

for bin in $binaries {
  let old = (find-hash-near-url $content $bin.url)
  let new_hash = (fetch-sri $bin.url)
  let label = ($bin.url | path basename)
  print $"($label): ($old) -> ($new_hash)"
  $updates = ($updates | append { label: $label, url: $bin.url, old: $old, new: $new_hash })
}

let dirty = ($updates | any { |u| $u.old != $u.new })
if not $dirty {
  print "Package is already up-to-date. No changes needed."
  exit 0
}

for u in $updates {
  if $u.old != $u.new {
    $content = ($content | str replace $'sha256 = "($u.old)";' $'sha256 = "($u.new)";')
  }
}
$content | save -f $pkg_file
print $"Updated ($pkg_file)."
