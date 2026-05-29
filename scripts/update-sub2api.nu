#!/usr/bin/env nu

# sub2api carries three fixed-output hashes (src, the pnpm frontend deps, and
# the Go vendor) that all change together on every release. nix-update does
# not reliably touch the pnpm hash nested in a let-bound derivation, so we
# bump the version and then let `nix build` tell us each correct hash: every
# mismatch prints the stale `specified:` value (which is what currently sits
# in the file) and the correct `got:` value, so a literal replace of one by
# the other fixes whichever FOD failed — no brittle position/anchor matching.

let pkg_file = "pkgs/sub2api/default.nix"

let latest_tag = (^gh api repos/Wei-Shaw/sub2api/releases/latest --jq '.tag_name' | str trim)
let new_ver = ($latest_tag | str replace --regex '^v' '')
let old_ver = (open $pkg_file --raw | parse -r 'version = "(?<v>[^"]+)";' | first | get v)

print $"[sub2api] current: ($old_ver), latest: ($new_ver)"

if $old_ver == $new_ver {
  print "[sub2api] up-to-date"
  exit 0
}

open $pkg_file --raw
| str replace --regex 'version = "[^"]+";' $'version = "($new_ver)";'
| save -f $pkg_file

mut iterations = 0
loop {
  if $iterations >= 6 {
    print -e "[sub2api] giving up after 6 hash iterations"
    exit 1
  }
  $iterations = $iterations + 1

  let res = (do { ^nix build '.#sub2api' --no-link } | complete)
  if $res.exit_code == 0 {
    print "[sub2api] build succeeded"
    break
  }

  let err = $res.stderr
  let specified = ($err | parse -r 'specified:\s+(?<h>sha256-[A-Za-z0-9+/=]+)')
  let got = ($err | parse -r 'got:\s+(?<h>sha256-[A-Za-z0-9+/=]+)')
  if ($specified | is-empty) or ($got | is-empty) {
    print -e $"[sub2api] build failed without a resolvable hash mismatch:\n($err)"
    exit 1
  }

  let stale = ($specified | first | get h)
  let fresh = ($got | first | get h)
  open $pkg_file --raw | str replace $stale $fresh | save -f $pkg_file
  print $"[sub2api] ($stale) -> ($fresh)"
}

print $"[sub2api] updated to ($new_ver)"
