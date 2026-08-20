{
  helpers,
  prev,
  ...
}:
helpers.wasmRename {wasmName = "patch";} (
  helpers.libTweaks {
    passthru.wasix.shipped = true;
    postPatch = ''
      substituteInPlace lib/backupfile.c \
        --replace-fail 'opendirat (dir_fd, buf, 0, pnew_fd)' 'rpl_opendirat (dir_fd, buf, 0, pnew_fd)'
      substituteInPlace lib/opendirat.c \
        --replace-fail 'opendirat (int dir_fd, char const *dir, int extra_flags, int *pnew_fd)' \
                       'rpl_opendirat (int dir_fd, char const *dir, int extra_flags, int *pnew_fd)'
      substituteInPlace lib/opendirat.h \
        --replace-fail 'DIR *opendirat (int, char const *, int, int *)' \
                       'DIR *rpl_opendirat (int, char const *, int, int *)'
    '';
  }
  prev.patch
)
