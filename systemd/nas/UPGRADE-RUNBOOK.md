# NAS bcachefs module runbook
# Source of truth: dotfiles systemd/nas/UPGRADE-RUNBOOK.md (mirror of nas:~/UPGRADE-RUNBOOK.md)

## CURRENT PROCEDURE: reload the module WITHOUT a reboot (proved 2026-09-10 and 2026-09-20)

Prereqs (no downtime, any time):
1  build + install the new version into DKMS as root (source clone must be tom-owned,
   e.g. `git clone --shared ~/bcachefs-tools ~/pcm-src2 && git checkout <branch>`):
     cd ~/pcm-src2 && sudo make install_dkms            # -> /usr/src/bcachefs-<git describe>[suffix]
     V=$(ls -d /usr/src/bcachefs-v1.39.4-* | tail -1 | sed 's#.*/bcachefs-##')   # NOTE: dir name may carry
     sudo dkms add -m bcachefs -v $V; sudo dkms build -m bcachefs -v $V             # extra hex, use the dir name
     sudo dkms install -m bcachefs -v $V --force                                    # replaces the .ko for the NEXT load only
2  deploy the matching /usr/local/sbin/bcachefs-pool-options if a new runtime option
   must be set after mount (the unit FAILS red on a module lacking the option).
3  make sure ~/nas-pool-holders and ~/switch-noreboot.sh are current (dotfiles scripts/).

Switch window (~10 min of downtime, user at the keyboard for the passphrase):
4  in the NAS base tmux:            sudo sh ~/switch-noreboot.sh
5  from spark-1, right after:       ssh root@100.74.188.66 'ha host shutdown'
6  when the tty shows "bcachefs /pool passphrase": type it. The script then restarts
   docker, every compose stack, pool-options/governor/raiser and the HA VM, and prints
   the module version + key options + service counts, ending in DONE.

If it prints ABORT at the umount: it already retried for 5 min and listed the holders
(via ~/nas-pool-holders — NEVER `lsof +D /pool`, it walks 190 TB and holds the mount).
The pool is still mounted and the OLD module still loaded; services are down. Either fix
the holder and rerun from "sudo systemctl stop pool-mount" by hand, or bring services
back: `sudo systemctl start docker <stacks> haos-vm`.

Rollback: `sudo dkms install -m bcachefs -v <previous version> --force` + the same window.
Installed versions: `dkms status | grep bcachefs`. Running: `cat /sys/module/bcachefs/version`.

History: 2026-09-10 v1.39.4 -> v1.39.4-1-gd390a8ae0b23 (promote_skip_congested);
2026-09-20 -> v1.39.4-2-g44c68c7c22a4 (reconcile_wait_on_copygc). The 09-20 run lost
13 min to a missing umount retry (docker releases /pool asynchronously) - fixed in the script.

---------------------------------------------------------------------------------------
## HISTORICAL: the 2026-08-31 reboot-based v1.38.8 -> v1.39.4 switch (executed 2026-09-01)

# bcachefs v1.38.8 -> v1.39.4 switch runbook (NAS)
# Prepared 2026-08-31. PREP IS DONE UP TO "SWITCH WINDOW" — nothing below
# "switch window" has been executed.

## Already done (prep, zero service impact)
- ~/bcachefs-tools checked out at tag v1.39.4 (d997ad76e), clean tree
- tools built:            ~/bcachefs-tools/bcachefs  (verify: `version` -> 1.39.4)
- version_upgrade=compatible  (sysfs write, persisted; readback shows [compatible])
  -> first 1.39.4 mount applies CODE fixes only; per_dev_fragmentation_lru
     on-disk format change stays OFF until deliberately enabled later
- /usr/src/bcachefs-v1.39.4 populated (make install_dkms)
- dkms add + build done for 6.18.12+deb13-amd64 (NOT installed — /lib/modules untouched)

## Why v1.39.4 not v1.39.2/3
- our reconcile wedge fix (3ad7d3b) is in since v1.39.2
- v1.39.3 tag is defective (Cargo.toml not bumped -> DKMS fetches 1.39.2 module)
- v1.39.4 adds: EC wrong-reconstruction fix (we run 4+2), ec_stripe_new leak fix
  (we HAD stripe alloc failures), emergency-ro-during-tiering fix, recovery not
  killed at 90s on boot

## SWITCH WINDOW (needs: user present for pool passphrase after reboot)
1  sudo dkms install -m bcachefs -v v1.39.4                  # running kernel
   sudo dkms install -m bcachefs -v v1.39.4 -k 7.1.3+deb13-amd64   # optional
   sudo dkms install -m bcachefs -v v1.39.4 -k 7.0.12+deb13-amd64  # optional
2  sudo make -C /home/tom/bcachefs-tools install             # tools -> /usr/local/sbin
3  clean shutdown sequence (proved 2026-08-30):
     ssh root@100.74.188.66 'ha host shutdown'   # then wait qemu exit / stop unit
     sudo systemctl stop haos-vm.service
     sudo docker stop -t 600 nas-postgres ha_postgres_recorder immich_postgres mlflow-postgres
     sudo systemctl stop docker
     sync && sudo systemctl poweroff             # umount now blocks properly, 5min cap
     (poweroff -f if it wedges on the unmount — journal already flushed at that point)
4  boot; passphrase: sudo systemd-tty-ask-password-agent
5  VERIFY, in order:
     cat /sys/module/bcachefs/version            # must say 1.39.4
     recovery_status: Failing empty
     ps: bch-reconcile in S state AND STAYS S past the 2-minute mark
         (1.38.8 re-wedged at ~120s every mount — this is THE test)
     reconcile_status: position advancing, not POS_MIN
     nas_bcachefs_pending_reconcile_bytes: high_priority/target FALLING
6  services come back: docker + haos-vm auto; six nas-* units cover the rest
7  ROLLBACK if reconcile still wedges or worse:
     sudo dkms remove -m bcachefs -v v1.39.4 --all
     (bcachefs/v1.38.8 dkms is still installed for all kernels — reboot restores it)
     tools: cd ~/bcachefs-tools && git checkout <1.38.8-era commit> && rebuild, or
     keep 1.39.4 tools (userspace reads old module fine for status commands)

## AFTER days of stable drain (separate decision)
- take the format upgrade for per-device fragmentation LRUs (copygc/reconcile
  contention fix): echo incompatible > options/version_upgrade, remount once,
  then set back to compatible. ONE-WAY once applied.
