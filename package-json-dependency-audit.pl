#!/usr/bin/perl

use strict;

=head1 NAME

package-json-dependency-audit.pl

=head1 SYNOPSIS

perl package-json-dependency-audit.pl <path> [--new-package-json=<filepath>] [--output-path=<path>]

=head1 DESCRIPTION

Primary Purpose: Recursively scan code-dir for package.json files and come up with a list of dependencies (package, frequency, versions, version frequency).
Secondary Purpose: Given a "new" package.json, scan directory and show what new things this package.json brings to the directory.

=head1 OPTIONS

=over 8

=item debug

Enables debugging print statements.

=item help

Prints this help documentation.

=item new-package-json

Optional: File to compare to the folder

=item output-path

Optional: Path to output the analysis files. Defaults to /tmp


=back

=head1 LICENSE

This is released under the Artistic License. See L<http://dev.perl.org/licenses/artistic.html>.

=head1 AUTHOR

Matt Gill - L<http://mattgill.net/>

=cut

use strict;
use Getopt::Long;
use Data::Dumper;
use JSON::PP;

# set options
my %opts;
my $opt_ret = GetOptions(\%opts, 'debug', 'help', 'new-package-json=s', 'output-path=s');
print_usage() if $opts{'help'} or !$ARGV[0];

# local vars
my $outputDelim = "\t";
my %deps;
my %depsByApp;
my $codeDir = $ARGV[0];
$codeDir =~ s/\/$//;
my $newJsonFile = $opts{'new-package-json'};
my @newJsonFileDirs = $newJsonFile ? split(/\//, $newJsonFile) : ();
my $newJsonFileDir = ( scalar(@newJsonFileDirs) >= 2 ) ? $newJsonFileDirs[scalar(@newJsonFileDirs) - 2] : '';

my $outputDir = $opts{'output-path'} ? $opts{'output-path'} : '/tmp/package-json-audit/';
$outputDir .= '/' if $outputDir !~ /\/$/;
my $fileDistinctModules = $outputDir . 'distinctModules.txt';
my $fileDistinctModulesVersions = $outputDir . 'distinctModulesVersions.txt';
my $fileModuleUse = $outputDir . 'moduleUsage.txt';
my $fileNewPackageAudit = $outputDir . 'newPackageAnalysis.txt';


# find files
my @files = `find $codeDir | grep 'package.json\$'`;
# and loop
foreach my $file (@files)
{
    my @dirs = split(/\//, $file);
    my $dir = $dirs[scalar(@dirs) - 2];

    chomp($file);
    print_debug($file);
    
    open(INFILE, "$file") or die $!;
    my $packageJsonString = join("\n", <INFILE>);
    close(INFILE);
    
    $file =~ s/$codeDir\///;

    my $jsonHash = decode_json($packageJsonString);
    my $packageDeps = $jsonHash->{'dependencies'};

    print "Found dependencies for $dir\n";
    $depsByApp{$dir} = $packageDeps;

    # if it's something we are going to compare to, don't put it in the pool.
    next if $newJsonFile && $newJsonFileDir eq $dir;
    print "Loading dependencies from $file into the pool!\n";
    foreach my $module (sort keys %{$packageDeps})
    {
        my $version = $packageDeps->{$module};
        $version =~ s/[^0-9\.]//g;
        
        $deps{$module}{$version}{'count'}++;
        $deps{$module}{$version}{'files'} = () if !$deps{$module}{$version}{'files'};
        push(@{$deps{$module}{$version}{'files'}}, $file);
    }
}

# we have info. let's start printing it!
system("mkdir -p $outputDir");

open(MODULES, ">$fileDistinctModules");
print MODULES join($outputDelim, ("Module", "Times Used")) . "\n";

open(VERSIONS, ">$fileDistinctModulesVersions");
print VERSIONS join($outputDelim, ("Module", "Module Frequency", "Module Version", "Module Version Frequency")) . "\n";

open(ALLMODULES, ">$fileModuleUse");
print ALLMODULES join($outputDelim, ("Module", "Module Frequency", "Module Version", "Module Version Frequency" ,"File With Module and Version")) . "\n";

foreach my $module (sort keys %deps)
{
    # grab overall count
    my $overallCount = 0;
    foreach my $version (keys %{$deps{$module}})
    {
        $overallCount += $deps{$module}{$version}{'count'};
    }
    print MODULES join($outputDelim, ($module, $overallCount)) . "\n";

    foreach my $version (keys %{$deps{$module}})
    {
        my $versionCount = $deps{$module}{$version}{'count'};
        print VERSIONS join($outputDelim, ($module, $overallCount, $version, $versionCount)) . "\n";
        
        foreach my $file (@{$deps{$module}{$version}{'files'}})
        {
            print ALLMODULES join($outputDelim, ($module, $overallCount, $version, $versionCount, $file)) . "\n";
        }
    }
}
close(MODULES);
close(VERSIONS);
close(ALLMODULES);

# if we are looking at a particular file too let's see what's new/different!
if ($newJsonFile)
{
    print_debug("Looking at $newJsonFileDir");
    open(NEWPACKAGEAUDIT, ">$fileNewPackageAudit");
    print NEWPACKAGEAUDIT join($outputDelim, ("Module", "Version", "Lowest Version In CodeBase", "Highest Version In CodeBase", "Total Versions In CodeBase")) . "\n"; 
    foreach my $module (sort keys %{$depsByApp{$newJsonFileDir}})
    {
        print_debug($module);
        my $newVer = $depsByApp{$newJsonFileDir}{$module};
        $newVer =~ s/[^0-9\.]//g;
        my $versionsCount = scalar(keys %{$deps{$module}});
        
        # Didn't want to depend on external CPANs otherwise could use Sort::Versions. So let's lean on Unix sort.
        # Callouts are slow but we aren't doing a lot of these.
        my $versionString = join("\n", keys %{$deps{$module}} );
        # echo -e is being strange. so let's take the I/O hit with a file too.
        my $versionFileDump = '/tmp/asdagawceedawsveaw.txt';
        open(COMMANDVERSIONS, ">$versionFileDump");
        print COMMANDVERSIONS $_ . "\n" foreach keys %{$deps{$module}};
        close(COMMANDVERSIONS);

        my $minVer = `cat $versionFileDump | sort -V | head -1`;
        chomp($minVer);
        my $maxVer = `cat $versionFileDump | sort -rV | head -1`;
        chomp($maxVer);
        print_debug("Min: $minVer");
        print_debug("Max: $maxVer");
        print NEWPACKAGEAUDIT join($outputDelim, ($module, $newVer, $minVer, $maxVer, $versionsCount)) . "\n";

        unlink($versionFileDump);
    }
    close(NEWPACKAGEAUDIT);
}

print "Analysis files can be found in $outputDir\n";

sub print_debug
{
    my $line = shift;
    print $line . "\n" if $opts{'debug'};
}

sub print_usage
{
	print `perldoc $0`;
	exit 0;
}