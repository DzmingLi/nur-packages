#!/usr/bin/env nu

let pkg_file = "pkgs/context7-mcp/default.nix"
let lock_file = "pkgs/context7-mcp/package-lock.json"
let repo_owner = "upstash"
let repo_name = "context7"

if not ($pkg_file | path exists) {
  print -e $"Package file not found: ($pkg_file)"
  exit 1
}

let content = open $pkg_file --raw

let current_version = ($content | lines
  | where { $in | str contains 'version = "' }
  | first
  | parse -r 'version = "([^"]+)"'
  | first
  | get capture0)

if ($current_version | is-empty) {
  print -e $"Failed to read current version from ($pkg_file)"
  exit 1
}

print $"Current version: ($current_version)"

let latest_version = (git ls-remote --tags $"https://github.com/($repo_owner)/($repo_name).git"
  | lines
  | parse -r '\trefs/tags/(.+)'
  | get capture0
  | where { ($in | str starts-with 'v') and (not ($in | str contains '^')) }
  | each { str replace -r '^v' '' }
  | sort --natural
  | last)

if ($latest_version | is-empty) {
  print -e "Failed to resolve latest version tag"
  exit 1
}

print $"Latest version:  ($latest_version)"

if $latest_version == $current_version {
  print "Already up-to-date."
  exit 0
}

open $pkg_file --raw
  | str replace $'version = "($current_version)";' $'version = "($latest_version)";'
  | save -f $pkg_file

let src_hash = (nix shell "nixpkgs#nix-prefetch-github" "nixpkgs#jq" -c bash -lc $"nix-prefetch-github ($repo_owner) ($repo_name) --rev v($latest_version) | jq -r .hash" | str trim)

if ($src_hash | is-empty) {
  print -e "Failed to fetch src hash"
  exit 1
}

print $"New src hash:   ($src_hash)"

let old_src_hash = (open $pkg_file --raw | lines
  | where { $in | str contains 'hash = "' }
  | first
  | parse -r 'hash = "([^"]+)"'
  | first
  | get capture0)

if ($old_src_hash | is-empty) {
  print -e "Failed to read existing src hash"
  exit 1
}

open $pkg_file --raw
  | str replace $'hash = "($old_src_hash)";' $'hash = "($src_hash)";'
  | save -f $pkg_file

# Clone repo and generate package-lock.json
let tmp_dir = (mktemp -d | str trim)

print "Updating package-lock.json..."
try {
  git clone --depth 1 --branch $"v($latest_version)" $"https://github.com/($repo_owner)/($repo_name).git" $tmp_dir
  nix shell "nixpkgs#nodejs" --command bash -lc $"cd \"($tmp_dir)\" && npm install --package-lock-only --ignore-scripts --no-fund --no-audit"

  if not ($"($tmp_dir)/package-lock.json" | path exists) {
    print -e "Failed to generate package-lock.json"
    rm -rf $tmp_dir
    exit 1
  }

  cp $"($tmp_dir)/package-lock.json" $lock_file
} catch {|e|
  rm -rf $tmp_dir
  print -e $"Failed during package-lock.json generation: ($e.msg)"
  exit 1
}
rm -rf $tmp_dir

let placeholder_hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

let old_npm_hash = (open $pkg_file --raw | lines
  | where { $in | str contains 'npmDepsHash = "' }
  | first
  | parse -r 'npmDepsHash = "([^"]+)"'
  | first
  | get capture0)

if ($old_npm_hash | is-empty) {
  print -e "Failed to read existing npmDepsHash"
  exit 1
}

open $pkg_file --raw
  | str replace $'npmDepsHash = "($old_npm_hash)";' $'npmDepsHash = "($placeholder_hash)";'
  | save -f $pkg_file

print "Calculating npmDepsHash..."
let build_result = (do { nix build .#context7-mcp } | complete)
let build_output = $build_result.stderr

let new_npm_hash = ($build_output | parse -r 'got:\s*(sha256-[A-Za-z0-9+/=]+)' | last | get capture0)

if ($new_npm_hash | is-empty) {
  print -e "Failed to determine npmDepsHash. Build output:"
  print -e $build_output
  exit 1
}

print $"New npmDepsHash: ($new_npm_hash)"

open $pkg_file --raw
  | str replace $'npmDepsHash = "($placeholder_hash)";' $'npmDepsHash = "($new_npm_hash)";'
  | save -f $pkg_file

if $build_result.exit_code != 0 {
  print "Rebuilding to verify..."
  nix build .#context7-mcp
}

print $"Update complete: ($pkg_file)"
