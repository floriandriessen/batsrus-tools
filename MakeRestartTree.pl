#!/usr/bin/perl -s

my $help    = $h;
my $verbose = $v;
my $savedir = $s;
my $link    = $l;
my $treedir = $t;
my $force   = $f;

use strict;
use warnings;
use Cwd qw(getcwd);

# Some defaults
my $cwd = getcwd;
my $INFO = "MakeRestartTree.pl";
my $ERROR = "ERROR in $INFO";
my $outdir = "$cwd" . "/" . "GM";
my $restart_outdir = "$outdir" . "/" . "restartOUT";
my $restart_indir = "$outdir" . "/" . "restartIN";
my $headfile = "restart.H";
my $headfile_tmp = "restart_tmp.H";
my $success = "BATSRUS.SUCCESS";
my $restart_tree = $savedir;

# Remove trailing '/' of name if user included it
$restart_tree =~ s/\/+$// if $savedir;

# Set time and iteration dummy to nonsense value
my $istep = -1;
my $itime = -1;

&show_help if ($help);

# Sanity check
die "$ERROR: BATSRUS did not finish successfully\n" unless -e $success
    or $force;
die "$ERROR: -t flag only works with -l flag\n" if ($treedir and not $link);

if ($treedir){
    print "$INFO: linking existing $treedir to $restart_indir\n" if $verbose;
    $restart_tree = $treedir;
    &link_restartdir;
    exit 0;
}

# Open the header file, get iteration step, and clean file by writing to new
open (HEADERFILE, "$restart_outdir/$headfile")
    or die "$ERROR could not open file $headfile\n";
open (NHFILE, ">", "$restart_outdir/$headfile_tmp");

while ( <HEADERFILE> ){
    # Remove this header for correct restart reading
    print NHFILE unless m/IDEALAXES/;

    if (/\#NSTEP/){
        # Read in number of steps and extract
        $istep = <HEADERFILE>;
        print NHFILE $istep; # force line to be written to file
        chop($istep);

        # Remove leading spaces and trailing info
        $istep =~ s/^\s+//;
        $istep =~ s/\s.*//;

        # Convert string to number
        $istep += 0;
    }

    if (/\#TIMESIMULATION/){
        # Read in simulation time and extract
        $itime = <HEADERFILE>;
        print NHFILE $itime;
        chop($itime);

        $itime =~ s/^\s+//;
        $itime =~ s/\s.*//;
        $itime += 0;
    }
}

close NHFILE;
close HEADERFILE;

die "$ERROR: cannot find simulation time in $headfile!\n" if $itime < 0;
die "$ERROR: cannot find iteration step in $headfile!\n" if $istep < 0;

print "$INFO: read simulation time = $itime and it = $istep from $headfile\n"
    if $verbose;
rename "$restart_outdir/$headfile_tmp", "$restart_outdir/$headfile";

&make_restartdir;

&link_restartdir if $link;

exit 0;

#==============================================================================
# SUBROUTINES
#==============================================================================
sub make_restartdir{

    unless ($savedir){
        # Append iteration number to default directory name
        $restart_tree = sprintf("RESTART-t%9.4f-it%6d", $itime, $istep);

        # Replace spaces with zeros
        $restart_tree =~ s/ /0/g;
    }

    print "$INFO: restart tree named as $restart_tree inside $outdir.\n"
        if $verbose;
    $restart_tree = "$outdir" . "/" . "$restart_tree";

    # Create new restart directory
    print "mkdir $restart_tree\n" if $verbose;
    mkdir $restart_tree, 0755
        or die "$ERROR: restart tree $restart_tree cannot be created!\n";

    # Move the restart output over to the new restart tree
    opendir(DIR, $restart_outdir)
        or die "$ERROR: $restart_outdir does not exist!\n";
    my @content = readdir(DIR);
    closedir(DIR);

    die "$ERROR: directory $restart_outdir is empty!\n" if $#content < 2;

    rename $restart_outdir, $restart_tree or
        die "$ERROR: cannot move $restart_outdir into $restart_tree!\n";

    # Recreate the official output directory for new storage
    print "mkdir $restart_outdir\n" if $verbose;
    mkdir $restart_outdir, 0755
        or die "$ERROR: cannot create directory $restart_outdir!\n";
}

sub link_restartdir{
    # When directory already exists overwrite it with new link
    if ( -l $restart_indir ){
        print "rm -f $restart_indir\n" if $verbose;
        unlink $restart_indir
            or die "$ERROR: cannot remove link $restart_indir!\n";
    }elsif ( -d $restart_indir ){
        print "rmdir $restart_indir\n" if $verbose;
        rmdir $restart_indir
            or die "$ERROR: cannot remove directory $restart_indir!\n";
    }

    # Link restart tree with the input restart directory
    print "ln -s $restart_indir $restart_tree\n" if $verbose;
    symlink $restart_tree, $restart_indir or
        die "$ERROR: cannot link $restart_tree to $restart_indir!\n";
}

sub show_help{
    print
"Purpose:
   Make a restart tree from a BATSRUS simulation in the working directory and
   link it.

Usage:
   MakeRestartTree.pl [-h] [-v] [-l] [-t=DIRNAME] [-s=DIRNAME]

   -h          Print help message and exit.

   -v          Print verbose info to screen.

   -l          Link restart tree to restartIN.

   -f          Force script to run even if BATSRUSS.SUCCESS is not present.

   -t=DIRNAME  Specify an existing restart tree DIRNAME to link with restartIN.

   -s=DIRNAME  Specify the directory DIRNAME to save the restart files into. It
               will be prepared as GM/DIRNAME.
               Default is GM/RESTART-t[TIME]-it[NSTEP] with [TIME] and [NSTEP]
               the simulation time (in sec) and iteration step.

Examples:

Create restart tree from model with output located in GM/restartOUT and link
it to the input restart directory 'restartIN':

  MakeRestartTree.pl -l

Create restart tree from model with output located in GM/restartOUT, put it in
a directory 'restart-isolated' inside GM, and print verbose info:

  MakeRestartTree.pl -v -s=restart-isolated
"
    ,"\n\n";
    exit;
}
