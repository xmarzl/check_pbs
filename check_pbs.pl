#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use JSON;

# -- Global Vars
my $verbose = 0;
my $ignore_weekend = 0;

my $proxmox_node = '';
my $proxmox_storage = 'Proxmox-Backup-Server';
my @proxmox_vmids = ();

my $backup_age_warning = 86400;  # --- 1tag
my $backup_age_critical = 86400; # --- 1tag

my %error = (
  'ok'       => 0,
  'warning'  => 1,
  'critical' => 2,
  'unknown'  => 3
);

# -- Subs
sub help() {
  print '-n  --node'."\n";
  print '-s  --storage'."\n";
  print '-w  --warning'."\n";
  print '-c  --critical'."\n";
  print '-vm --vmid'."\n";
  print '-iwd --ignoreweekend'."\n";
  print '-v  --verbose'."\n";
  print '--help'."\n";
  print 'perl check_pbs.pl -n <node> -vm <vmid> [-s <storagename>] [-w <warning>] [-c <critical>] [-v]'."\n";
  exit($error{'unknown'});
}

sub verbose($) {
  my $f_message = shift;
  print 'verbose: '.$f_message."\n" if($verbose);
}

sub pvesh($) {
  my $f_path = shift;
  my $f_command = '/usr/bin/sudo /usr/bin/pvesh get '.$f_path.' --output-format json';
  my $f_response = `$f_command`;
  if(length($f_response) <= 0) {
    print "pvesh response is lower than 0\nbackups not reachable?\n";
    exit($error{'critical'});
  }
  &verbose('pvesh response: '.$f_response);
  my $f_output = decode_json($f_response);
  return $f_output;
}

sub unixtime_to_time($) {
  my $f_unixtime = shift;
  my ($f_second, $f_minute, $f_hour, $f_day, $f_month, $f_year) = localtime($f_unixtime);
  $f_month += 1;
  $f_year += 1900;
  my $f_datetime = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $f_year, $f_month, $f_day, $f_hour, $f_minute, $f_second);
  return $f_datetime;
}

# -- GetOptions -> init
&GetOptions(
  'n|node=s' => \$proxmox_node,
  's|storage:s' => \$proxmox_storage,
  'w|warning:i' => \$backup_age_warning,
  'c|critical:i' => \$backup_age_critical,
  'vm|vmid=s@' => \@proxmox_vmids,
  'v|verbose!' => \$verbose,
  'iwe|ignore_weekend:s' => \$ignore_weekend,
  'h|help!' => sub { &help() }
);

# -- translate icinga
if($ignore_weekend eq 'true' || $ignore_weekend eq '1') {
  $ignore_weekend = 1;
}else{
  $ignore_weekend = 0;
}

# --- Verbose GetOptions
&verbose('ignore_weekend: "'.$ignore_weekend.'"');
&verbose('storage: "'.$proxmox_node.'"');
&verbose('node: "'.$proxmox_storage.'"');
&verbose('warning: "'.$backup_age_warning.'"');
&verbose('critical: "'.$backup_age_critical.'"');
&verbose('vmids: "['.join(',', @proxmox_vmids).']"');
&verbose('');

# -- check inputs
if($proxmox_node eq '') {
  print 'node not defined!'."\n";
  exit($error{'unknown'});
}

# - Script start
&verbose('Script start');

# -- search node // check exists
my $exists = 0;
my $path = '/nodes';
my $response = &pvesh($path);
for my $item(@{$response}) {
  if($$item{node} eq $proxmox_node) {
    $exists = 1;
  }
}

# -- if node does not exists
if($exists == 0) {
  print 'node does not exists'."\n";
  exit($error{'critical'});
}


# -- search storage // check exists
$exists = 0;
$path = $path.'/'.$proxmox_node.'/storage';
$response = &pvesh($path);
for my $item(@{$response}) {
  if($$item{storage} eq $proxmox_storage) {
    $exists = 1;
  }
}

# -- if storage does not exists
if($exists == 0) {
  print 'storage does not exists'."\n";
  exit($error{'critical'});
}

# -- hash which will contain all backups for each vmid
my %proxmox_vmid_backups = ();

# -- search backups for each vmid
$path = $path.'/'.$proxmox_storage.'/prunebackups';
$response = &pvesh($path);
for my $backup(@{$response}) {
  my $vmid = $$backup{vmid};
    &verbose('working with '.$vmid);
  if(grep (/^$vmid$/, @proxmox_vmids) ) {
    &verbose('adding backup '.$$backup{volid});
    push @{$proxmox_vmid_backups{$vmid}}, \%{$backup};
  }
}

my $count_critical = 0;
my $count_warning = 0;
my $count_ok = 0;

my $output = '';

&verbose('Critical seconds: '.$backup_age_critical);
&verbose('Warning seconds: '.$backup_age_warning);

# -- check newest backup for each vm
for my $vmid(keys %proxmox_vmid_backups) {
  &verbose('searching for the newest backup of vmid '.$vmid.'...');

  # -- sort array (highest unixtime = newest file)
  my @vmid_last_backups = sort { $b->{ctime} <=> $a->{ctime} } @{$proxmox_vmid_backups{$vmid}};

  # --- element 0 = newest
  my $backup = $vmid_last_backups[0];
  my $backup_unixtime = $$backup{ctime};
  my $backup_time = &unixtime_to_time($backup_unixtime);
  my $backup_age_in_seconds = (time - $backup_unixtime);

  # --- check if older than critical- or warning-seconds
  if($backup_age_in_seconds > $backup_age_critical) {
    $count_critical++;
    # ---- append critical-information to output
    $output = $output.'CRITICAL - '.$vmid.' - '.$backup_time."\n";
  }elsif($backup_age_in_seconds > $backup_age_warning) {
    $count_warning++;
    # ---- append warning-information to output
    $output = $output.'WARNING - '.$vmid.' - '.$backup_time."\n";
  }else{
    $count_ok++;
    # ---- append ok-information to output
    $output = $output.'OK - '.$vmid.' - '.$backup_time."\n";
  }
  &verbose('Age in seconds: '.$backup_age_in_seconds);
  &verbose('Newst backup for vmid "'.$vmid.'": '.$backup_time);
}

# -- error if a backop of a vm is not found
for my $vmid(@proxmox_vmids) {
  if(not grep (/^$vmid$/, keys %proxmox_vmid_backups) ) {
    $count_critical++;
    $output = $output.'No backup found for vmid "'.$vmid.'".'."\n";
  }
}

# -- if weekend parameter is set
my $is_weekend = 0;
if($ignore_weekend == 1) {

  # --- set icinga title to "ignoring weekend"
  my $day_of_week = (localtime(time))[6];
  &verbose('Day of week: '.$day_of_week);

  # --- ignoring weekend (sunday=0, saturday=6)
  if($day_of_week == 0 || $day_of_week == 6) {
    print('Ignoring weekend...'."\n");
    $is_weekend = 1;
  }
}

# -- print icinga title (if not weekend, else its also message) & message
print 'Critical: '.$count_critical.' - Warning: '.$count_warning.' - OK: '.$count_ok."\n";
print $output;

# -- exit when its weekend
if($is_weekend == 1) {
  exit($error{'ok'});
}

# -- exit if critical
if($count_critical > 0) {
  exit($error{'critical'});
}

# -- exit if warning
elsif($count_warning > 0) {
  exit($error{'warning'});
}

# -- exit if ok = File is not too old
else {
  &verbose('End script - Everything fine!');
  exit($error{'ok'});
}
