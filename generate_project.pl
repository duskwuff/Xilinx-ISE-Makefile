#!/usr/bin/perl
use strict;
my $prjfile = shift or die "Usage: $0 project.prj [source...]\n";
open my $prj, ">", $prjfile or die "$prjfile: $!";
for my $source (@ARGV) {
    if ($source =~ m{\.v$}) {
        print $prj "verilog work $source\n";
    } elsif ($source =~ m{\.vhd}) {
        print $prj "vhdl work $source\n";
    } else {
        die "unknown source type '$source'\n";
    }
}
