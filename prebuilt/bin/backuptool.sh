#!/sbin/sh
#
# Backup and restore addon /system files
#

export C=/tmp/backupdir
export S=/system
export V=7

# Preserve /system/addon.d in /tmp/addon.d
preserve_addon_d() {
  if [ -d /system/addon.d/ ]; then
    mkdir -p /tmp/addon.d/
    cp -a /system/addon.d/* /tmp/addon.d/
    chmod 755 /tmp/addon.d/*.sh
  fi
}

# Restore /system/addon.d from /tmp/addon.d
restore_addon_d() {
  if [ -d /tmp/addon.d/ ]; then
    cp -a /tmp/addon.d/* /system/addon.d/
    rm -rf /tmp/addon.d/
  fi
}

# Proceed only if /system is the expected major and minor version
check_prereq() {
# If there is no build.prop file the partition is probably empty.
if [ ! -r /system/build.prop ]; then
    return 0
fi
if ( ! grep -q "^ro.bliss.version=$V.*" /system/build.prop ); then
  echo "Not backing up files from incompatible version: $V"
  return 0
fi
return 1
}

check_blacklist() {
  if [ -f /system/addon.d/blacklist ];then
      ## Discard any known bad backup scripts
      cd /$1/addon.d/
      for f in *sh; do
          s=$(md5sum $f | cut -c-32)
          grep -q $s /system/addon.d/blacklist && rm -f $f
      done
  fi
}

# Execute /system/addon.d/*.sh scripts with $1 parameter
run_stage() {
if [ -d /tmp/addon.d/ ]; then
  for script in $(find /tmp/addon.d/ -name '*.sh' |sort -n); do
    $script $1
  done
fi
}

case "$1" in
  backup)
    mkdir -p $C
    check_prereq
    check_blacklist system
    preserve_addon_d
    run_stage pre-backup
    run_stage backup
    run_stage post-backup
  ;;
  restore)
    check_prereq
    check_blacklist tmp
    run_stage pre-restore
    run_stage restore
    run_stage post-restore
    restore_addon_d
    rm -rf $C
    sync
  ;;
  *)
    echo "Usage: $0 {backup|restore}"
    exit 1
esac

exit 0
