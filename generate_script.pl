#!/usr/bin/perl
use strict;
my $scrfile = shift or die "Usage: $0 project.prj [source...]\n";
open my $scr, ">", $scrfile or die "$scrfile: $!\n";
print $scr "run\n";
for my $arg (@ARGV) {
    print $scr "$arg\n";
}
