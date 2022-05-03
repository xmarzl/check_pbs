# check_pbs.pl
icinga2 check proxmox backups

## Example output:
```
perl check_pbs.pl -n pve -s "backup-usb" -vm 100 -vm 101 -vm 102 -v
[...]
verbose: working with 100
verbose: adding backup backup-usb:backup/vzdump-qemu-100-2022_02_25-22_00_02.vma.zst
verbose: working with 101
verbose: adding backup backup-usb:backup/vzdump-qemu-101-2022_03_26-00_56_15.vma.zst
verbose: working with 101
verbose: adding backup backup-usb:backup/vzdump-qemu-101-2022_03_29-00_43_29.vma.zst
verbose: working with 102
verbose: adding backup backup-usb:backup/vzdump-qemu-102-2022_03_19-00_11_13.vma.zst
verbose: working with 102
verbose: adding backup backup-usb:backup/vzdump-qemu-102-2022_03_26-00_57_32.vma.zst
verbose: searching for the newest backup of vmid 100...
verbose: Newst backup for vmid "100": 2022-02-25 22:00:02
verbose: searching for the newest backup of vmid 102...
verbose: Newst backup for vmid "102": 2022-03-26 00:57:32
verbose: searching for the newest backup of vmid 101...
verbose: Newst backup for vmid "101": 2022-03-29 00:43:29
Critical: 2 - Warning: 0 - OK: 1
100 - 2022-02-25 22:00:02
102 - 2022-03-26 00:57:32
101 - 2022-03-29 00:43:29
```
```
perl check_pbs.pl -n pve01 -vm 100 -vm 101 -vm 102 -vm 103 -v
[...]
verbose: working with 102
verbose: adding backup Proxmox-Backup-Server:backup/vm/102/2022-03-27T20:01:52Z
verbose: working with 102
verbose: adding backup Proxmox-Backup-Server:backup/vm/102/2022-03-28T20:02:23Z
verbose: searching for the newest backup of vmid 101...
verbose: Newst backup for vmid "101": 2022-03-28 22:01:12
verbose: searching for the newest backup of vmid 102...
verbose: Newst backup for vmid "102": 2022-03-28 22:02:23
verbose: searching for the newest backup of vmid 103...
verbose: Newst backup for vmid "103": 2022-03-28 22:02:40
verbose: searching for the newest backup of vmid 100...
verbose: Newst backup for vmid "100": 2022-03-28 22:00:01
Critical: 0 - Warning: 0 - OK: 4
101 - 2022-03-28 22:01:12
102 - 2022-03-28 22:02:23
103 - 2022-03-28 22:02:40
100 - 2022-03-28 22:00:01
verbose: End script - Everything fine!
```
```
perl check_pbs.pl -n pve01 -vm 100 -vm 101 -vm 102 -vm 444
Critical: 3 - Warning: 0 - OK: 1
100 - 2022-02-25 22:00:02
101 - 2022-03-29 00:43:29
102 - 2022-03-26 00:57:32
Vmid "444" not found.
```

## Installation:
```sh
cd /usr/lib/nagios/plugins
wget https://raw.githubusercontent.com/xmarzl/check_pbs/main/check_pbs.pl
chmod 750 /usr/lib/nagios/plugins/check_files.pl
```
Installation des Moduls "JSON"  
Dokumentation: https://metacpan.org/pod/JSON
```
perl -MCPAN -e shell
install JSON
```
## 

| Parameter         | Description                   |
| ----------------- | ----------------------------- |
| -n  \| --node     | Node name (only one possible) |
| -s  \| --storage  | Storage to check              |
| -w  \| --warning  | File age warning (seconds)    |
| -c  \| --critical | File age critical (seconds)   |
| -vm \| --vmid     | Which vm should be checked    |
| -v  \| --verbose  | More information              |
| -h  \| --help     | This help                     |
| usage | perl check_pbs.pl -n <node> -vm <vmid> [-s <storagename>] [-w <warning>] [-c <critical>] [-v] |

Example:
```bash
./check_pbs.pl -n pve01 -vm 100 -vm 101 -vm 102 -vm 103 -s mystorage -w 86400 -c 172800
```
