{
  stdenv,
  qq,
  makeWrapper,
}:

let
  x11BlockHook = stdenv.mkDerivation {
    pname = "qq-x11-block-hook";
    version = "1.0";
    src = builtins.toFile "block.c" ''
      #define _GNU_SOURCE

      #include <dlfcn.h>
      #include <pthread.h>
      #include <stdint.h>
      #include <stdio.h>
      #include <stdlib.h>
      #include <string.h>

      typedef struct _XDisplay Display;

      static pthread_once_t init_once = PTHREAD_ONCE_INIT;
      static __thread int in_hook = 0;

      static Display *(*real_XOpenDisplay)(const char *name) = NULL;
      static const char *target_suffix = "/wrapper.node";

      static void init_hook(void) {
        real_XOpenDisplay = dlsym(RTLD_NEXT, "XOpenDisplay");

        const char *suffix_env = getenv("QQ_X11_TARGET_MODULE_SUFFIX");
        if (suffix_env && *suffix_env) {
          target_suffix = suffix_env;
        }
      }

      static int path_matches(const char *path) {
        if (!path) return 0;
        size_t path_len = strlen(path);
        size_t want_len = strlen(target_suffix);
        return path_len >= want_len && strcmp(path + path_len - want_len, target_suffix) == 0;
      }

      static int is_target_caller(void *retaddr) {
        Dl_info info = {0};
        if (!retaddr || !dladdr(retaddr, &info) || !info.dli_fname || !info.dli_fbase) {
          return 0;
        }
        return path_matches(info.dli_fname);
      }

      Display *XOpenDisplay(const char *name) {
        pthread_once(&init_once, init_hook);
        if (!real_XOpenDisplay) return NULL;
        if (in_hook) return real_XOpenDisplay(name);

        in_hook = 1;

        void *retaddr = __builtin_return_address(0);
        if (is_target_caller(retaddr)) {
          in_hook = 0;
          return NULL;
        }

        Display *display = real_XOpenDisplay(name);
        in_hook = 0;
        return display;
      }
    '';
    dontUnpack = true;
    dontConfigure = true;
    dontFixup = true;
    nativeBuildInputs = [ stdenv.cc ];
    buildPhase = ''
      $CC -shared -fPIC -O2 -Wall -o libx11block.so $src -ldl -lpthread
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp libx11block.so $out/lib/
    '';
  };
in
stdenv.mkDerivation {
  pname = "qq";
  inherit (qq) version;

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib $out/share
    cp ${x11BlockHook}/lib/libx11block.so $out/lib/

    # Copy desktop files and icons from the original qq package
    cp -r ${qq}/share/* $out/share/ 2>/dev/null || true

    # Fix desktop file to point to our wrapped binary
    if [ -f $out/share/applications/qq.desktop ]; then
      substituteInPlace $out/share/applications/qq.desktop \
        --replace-fail "${qq}/bin/qq" "$out/bin/qq"
    fi

    # Create wrapper that prepends LD_PRELOAD
    makeWrapper ${qq}/bin/qq $out/bin/qq \
      --prefix LD_PRELOAD : "$out/lib/libx11block.so"

    runHook postInstall
  '';

  meta = qq.meta // {
    description = "QQ with X11 leak fix (blocks XOpenDisplay from wrapper.node)";
    mainProgram = "qq";
  };
}
