#!/usr/bin/perl

# Copyright (c) 2015 Yubico AB
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
# 
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
# 
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;
use warnings;

use IPC::Open3;
use IO::Select;
use Symbol;

my $bin = "/usr/lib/gnupg2/scdaemon --multi-server";
my $debug = 0;

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
    logg("notifying about '$op'");
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
      logg("$m on $r") if $debug;
      $m .= "\n";
      my $out;
      if($r eq \*STDIN) {
        $out = $pipe_in;
        $m =~ m/^([a-zA-Z]+)/;
        $op = $1;
        logg("running '$op'");
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
