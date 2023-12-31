#!/usr/bin/perl -s

my $help    = $h;
my $verbose = $v;
my $preplot = $p;
my $kill    = $k;
my $targz   = $g;
my $repeat  = $r;
my $dir     = $d;
my $nametar = $n;

use strict;
use warnings;
use Cwd qw(getcwd);

# Some defaults
my $cwd = getcwd;
my $INFO = 'RuntimeProc.pl';
my $ERROR = "ERROR in $INFO";
my $STOP = 4;
my $outdir = "$cwd" . "/" . "GM/IO2";
my $preplot_found = 0;
my $tardir = "ALL-DATFILES";
my $success = "BATSRUS.SUCCESS";

&show_help if $help;

# Sanity check
die "-n argument only works together with -g!\n" if ($nametar and not $targz);
die "$ERROR: the pTEC script is not in run directory: $cwd\n"
    unless glob( $cwd . '/pTEC' );

# Overwrite the path to the output directory if needed
$outdir = "$cwd" . "/" . "$dir" if $dir;

# Remove trailing '/' of name if user included it
$outdir =~ s/\/+$//;
print "Output directory is at $outdir\n" if $verbose;

if ($repeat){
    print "$INFO running on ", `hostname`;
    print "$INFO will stop in $STOP days. Started on ", `date`;
}

# Time counter for repeat option
my $time_start = time();

# Prevent repeat counter to terminate at restart of successfull model
# The $success file is only deleted once BATSRUS (re)starts
my $startup = 1;

# Concatenate the simulation files from all processors
REPEAT:{
    chdir $cwd;

    # NOTE: for proper functioning of pTEC an additional '/' has to be appended
    &shell("./pTEC b=${outdir}/");

    # Escape only if code finished or exceeding of script time
    last REPEAT if -e $success and not $startup;
    print "$success already exists at startup. Ignoring it for repeat count.\n"
        if -e $success and $verbose;
    $startup = 0 if $startup;

    if ($repeat){
        last REPEAT if (time - $time_start) > $STOP*3600*24;
        sleep $repeat;
        redo REPEAT;
    }
}

# Find all .dat files in the output directory
my @datfiles = glob( $outdir . '/*.dat' );

&find_preplot if $preplot;

if ( $preplot and $preplot_found ){

    foreach my $file (@datfiles){
        my $datfile = $file;

        if ( $datfile !~ /\.dat$/ ){
            warn "WARNING: for preplotting the extension should be .dat -> "
                . "$file\n";
            next;
        }

        # Preplot file
        &shell("preplot $datfile");

        # Check if plt file is produced
        my $pltfile = $datfile;
        $pltfile =~ s/.dat/.plt/;
        die "$ERROR: while using preplot no $pltfile was produced\n"
            unless -s $pltfile;
    }
}

if ($targz){
    die "$ERROR: no file matches @datfiles! Archiving cancelled...\n"
        unless @datfiles;

    print "Archiving files...\n";
    chdir $outdir;
    $tardir = $nametar if $nametar;
    &shell("mkdir $tardir");
    `cp @datfiles $tardir`;
    &shell("tar -c -z -f ${tardir}.tar.gz $tardir");
    `rm -r $tardir`;
}

# Remove .dat file
print "Deleting all .dat files in $outdir...\n" if $kill and $verbose;
unlink @datfiles if $kill;

exit 0;

#==============================================================================
# SUBROUTINES
#==============================================================================
sub shell{
    my $command = join(" ", @_);
    print "$command\n" if $verbose;
    my $result = `$command`;
    print $result if $verbose or $result =~ /error/i;
}

sub find_preplot{
    my $dump = ".tmp";
    my $searchpp = "(which preplot | grep -v \'Command not found\' > $dump)";
    `$searchpp >/dev/null 2>&1`;

    if (-s $dump){
        print "--- Preplot binary found at: " . `cat $dump` . "\n";
        `rm -f $dump`;
        $preplot_found = 1;
    }else{
        print "--- Preplot binary not found in PATH! Ignoring '-p' flag\n";
        `rm -f $dump`;
    }
}

sub show_help{
    print
"Purpose:
   Post-process BATSRUS output files created by each processor.
   The pTEC script needs to be included in the current working directory.

Usage:
   RuntimeProc.pl [-h] [-v] [-p] [-g] [-k] [-n=NAME] [-r=REPEAT] [-d=DIRNAME]

   -h          Print help message and exit.

   -v          Print verbose info to screen.

   -p          Preplot .dat files in the output directory.

   -g          Archive and compress all .dat files into a gzipped tarball in
               the output directory.

   -k          Delete all .dat files in the output directory.

   -n=NAME     Specify NAME for gzipped tarball in the output directory.
               Default ALL-DATFILES.tar.gz.

   -r=REPEAT   Repeat post-processing of .dat files every REPEAT seconds.

   -d=DIRNAME  Specify the directory DIRNAME containing the .dat files relative
               to the current working directory.
               Default is GM/IO2/ relative to current working directory.

Examples:

Post-process output files into .dat files located in GM/IO2:

  RuntimeProc.pl

Repeat post-processing output files in GM/IO2 every 60 seconds:

  RuntimeProc.pl -r=60

Post-process output files in the 'Run12' directory relative to the current
working directory, preplot to plt files, and print verbose info:

  RuntimeProc.pl -v -p -d=Run12

Post-process output files in the 'NewRun' directory relative to the current
working directory, compress and archive the .dat files, compress the .dat files
into a gzipped tarball 'B0_q5', and delete the .dat files:

  RuntimeProc.pl -g -k -d=NewRun -n=B0_q5
"
    ,"\n\n";
    exit;
}
