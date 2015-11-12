#!/usr/bin/perl

use strict;
use warnings;

use IPC::Open3;
use IO::Select;

my $bin = "/usr/lib/gnupg2/scdaemon --multi-server";

my $pid = open3(my $pipe_in, my $pipe_out, my $pipe_err, $bin) or die "failed to start $bin";
my $s = IO::Select->new();
$s->add(\*STDIN);
$s->add($pipe_out);

my $e = IO::Select->new();
$s->add($pipe_err);

open(my $log, ">>", "/tmp/scdaemon-proxy.log");
print $log "starting\n";
close $log;

my $cryptop = 0;

while(1) {
  my @ready = $s->can_read(1);
  if(!@ready and $cryptop) {
    open(my $log, ">>", "/tmp/scdaemon-proxy.log");
    print $log "notifying!\n";
    close($log);
    system("notify-send 'Crypto' 'Long running crypto operation'");
    $cryptop = 0;
  }
  foreach my $r (@ready) {
    my $message;
    sysread($r, $message, 2048);
    foreach my $m (split(/\n/, $message)) {
      open(my $log, ">>", "/tmp/scdaemon-proxy.log");
      $m .= "\n";
      print $log $m;
      close($log);
      if($r eq \*STDIN) {
        if($m =~ m/^pksign/i or $m =~ m/^pkdecrypt/i or $m =~ m/^auth/i) {
          $cryptop = 1;
        } else {
          $cryptop = 0;
        }
        print $pipe_in $m;
      } elsif($r eq $pipe_out) {
        $cryptop = 0;
        if($m =~ m/^scdaemon/) {
          print STDERR $m;
        } else {
          syswrite(STDOUT, $m);
        }
      }
    }
  }
}
