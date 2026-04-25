{
  lib,
  meson,
  ninja,
  pkg-config,
  boost,
  capnproto,
  howard-hinnant-date,
  lix,
  nlohmann_json,
  fetchpijul,
}:
# Lix is built with clangStdenv; its C++ headers don't compile under
# gcc (we hit a GCC ICE on `repo.cpp` when trying default stdenv).
# Borrow lix.stdenv so the plugin uses the same compiler lix itself uses.
lix.stdenv.mkDerivation {
  pname = "lix-pijul-plugin";
  version = "0.1.6-lix";

  src = fetchpijul {
    url = "https://knot.dzming.li/did:web:dzming.li/lix-plugin-pijul";
    hash = "sha256-L6o0N6t4H9JsH63cJVpYiD1e/ggEPxysrd/ipOse1DQ=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    boost
    capnproto
    howard-hinnant-date
    lix
    nlohmann_json
  ];

  meta = with lib; {
    description = "Lix plugin adding Pijul fetcher support";
    homepage = "https://pijangle.dzming.li/dzming.li/lix-plugin-pijul";
    license = licenses.lgpl3Only;
  };
}
