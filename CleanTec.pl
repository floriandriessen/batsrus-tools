#!/usr/bin/perl -s

my $verbose = $v;
my $help = $h;
my $kill = $k;
my $targz = $t;
my $infile = $i;

use strict;
use warnings;

if ( $help or not @ARGV ){
    print "
Purpose:
  Strip BATSRUS Tecplot data file(s) from header and node information.
  The produced file can be easily read into Python/Matlab/IDL/...

Usage:
  CleanTec.pl [-h] [-v] [-k] [-t] [-i] FILE1 [FILE2 FILE3 ...]

  -h    Print this message.

  -v    Print verbose info to screen.

  -k    Delete FILE1 [FILE2 FILE3 ...].

  -t    Archive and compress the cleaned data files into a gzipped tarball.

  -i    Only tarball input data files, not already cleaned data files.

Examples:

*** Supported 'PlotArea' strings are {1d,2d,3d} and {x,y,z} slices ***

Strip all Tecplot data files in current directory into a clean format:

  CleanTec.pl *.dat

Strip y,z data slices in current directory into a clean format and compress
them into a tarball (together with other cleaned data, if present):

  CleanTec.pl -t z=0_var_1_n00002000.dat y=0_var_3_n00003000.dat

Strip x data slice in current directory into a clean format and compress
it into a tarball (without other cleaned data, if present):

  CleanTec.pl -t -i x=0_var_1_n00000010.dat

Strip single 3D data file in the current directory, compress it into a tarball,
and then delete the original data file:

  CleanTec.pl -k -t -i 3d_mhd_2_n00010000.dat

";
    exit;
}

die "-i argument only works together with -t!\n" if ($infile and not $targz);

# No cleaning of already cleaned files and avoid reading non-BATSRUS files
my @files = grep { m/(^[321]d|^[xyz]).{1,}[0-9].dat$/ } @ARGV;
die "No file in this directory matches @ARGV!\n" unless @files;

foreach my $file (@files){

    print "Working on file: $file ...\n" if $verbose;

    my $outfile = $file;
    $outfile =~ s/\.dat/_clean\.dat/g;

    open (BATSFILE, "$file") or die "$file does not exist!\n";
    open (NF, ">", "$outfile");

    while (<BATSFILE>){
        s/VARIABLES\s=|\"//g;
        # Split line in fields, point connectivity is dimension dependent and
        # has 4 fields in 1d,2d output and 8 fields in 3d output
        my @F = split;
        print NF unless ( m/TITLE|AUXDATA|ZONE/
                          or (@F < 5 and $file =~ m/^[xyz]/)
                          or (@F < 9 and $file =~ m/^[321]d/)
                        );
    }

    close NF;
    close BATSFILE;
}

if ($targz){

    my @tarfile;

    if ( $infile ){
        @tarfile = @files;
        s/\.dat/_clean\.dat/g foreach @tarfile;
    }else{
        opendir(DIR,'.');
        @tarfile = grep {m/(^[321]d|^[xyz]).{1,}[0-9]_clean.dat$/
                         and not -d
                        } readdir(DIR);
        closedir(DIR);
    }

    print "File(s) to be tar-gzipped: @tarfile\n" if $verbose;

    if ( @tarfile > 1 ){
        my $tardir = 'ALL-CLEAN-DAT';
        `mkdir $tardir`;
        `cp @tarfile $tardir`;
        `tar -c -z -f ${tardir}.tar.gz $tardir`;
        `rm -r $tardir`;
        `rm @tarfile`;
    }else{
        `tar -c -z -f $tarfile[0].tar.gz $tarfile[0]`;
    }
}

print "Deleting file(s): @files ...\n" if $kill and $verbose;
unlink @files if $kill;
