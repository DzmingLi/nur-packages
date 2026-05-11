{
  lib,
  emacsPackages,
  fetchFromGitHub,
}:

## yuchen-lea/org-noter-plus: extract a PDF's outline + annotations into an
## org-mode note. Upstream renamed the package internally to org-annot-bridge
## (file: org-annot-bridge.el, feature: org-annot-bridge) but the GitHub repo
## still lives under the old name org-noter-plus. We keep the NUR attr name
## matching the repo (org-noter-plus) so it's easy to find; in Emacs you do
## `(require 'org-annot-bridge)`.
##
## Consumer pattern:
##   programs.emacs.package = (pkgs.emacsPackagesFor pkgs.emacs-pgtk).emacsWithPackages
##     (epkgs: [ ... pkgs.org-noter-plus ... ]);
emacsPackages.trivialBuild {
  pname = "org-noter-plus";
  version = "0.0.2-unstable-2025-05-09";

  src = fetchFromGitHub {
    owner = "yuchen-lea";
    repo = "org-noter-plus";
    rev = "54b00cdab8382c7ff7fbc4e901a0c0347f93302d";
    hash = "sha256-m1nhsKopU4Xa9QOb3zCoM56PTX2PXo2mUPAI4meE32Y=";
  };

  ## pdf-tools 没列在 Package-Requires 头里（上游遗漏），但源里有
  ## `(require 'pdf-view)`，byte-compile 时找不到就挂。手动补上。
  packageRequires = [ emacsPackages.transient emacsPackages.pdf-tools ];

  meta = with lib; {
    description = "Bridge between annotations (PDF outlines / annotations) and org-mode notes";
    homepage = "https://github.com/yuchen-lea/org-noter-plus";
    license = licenses.gpl3Plus;
    platforms = platforms.all;
  };
}
