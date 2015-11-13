#!/usr/bin/perl

use strict;
use warnings;

use IPC::Open3;
use IO::Select;
use Symbol;

my $bin = "/usr/lib/gnupg2/scdaemon --multi-server";

sub logg($) {
  my $msg = shift;
  open(my $log, ">>", "/tmp/scdaemon-proxy.log");
  print $log "$msg\n";
  close $log;
}

my $pipe_err = gensym();
my $pid = open3(my $pipe_in, my $pipe_out, $pipe_err, $bin) or die "failed to start $bin";
my $s = IO::Select->new();
$s->add(\*STDIN);
$s->add($pipe_out);
$s->add($pipe_err);

my $op = 0;

while(1) {
  my @ready = $s->can_read(1);
  if(!@ready and $op) {
    logg("notifying!");
    system("notify-send 'Crypto' 'Long running sc-operation: $op'");
    $op = undef;
  }
  foreach my $r (@ready) {
    my $message;
    if(sysread($r, $message, 2048) == 0) {
      logg("lost $r");
      die("input closed.");
    }
    foreach my $m (split(/\n/, $message)) {
      logg("$m on $r");
      $m .= "\n";
      my $out;
      if($r eq \*STDIN) {
        $out = $pipe_in;
        $m =~ m/^([a-zA-Z]+)/;
        $op = $1;
      } elsif($r eq $pipe_out) {
        $op = undef;
        $out = \*STDOUT;
      } elsif($r eq $pipe_err) {
        $out = \*STDERR;
      }
      syswrite($out, $m);
    }
  }
}
