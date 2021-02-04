#!/usr/bin/perl

use strict;
use warnings;

my $moz_supported_file;
my $lpom_dir;

my %blacklist;
my %locale2pkgname;
my %languages;

my %pkglist;

my $file;

while (@ARGV) {
    my $arg = shift(@ARGV);
    if ($arg eq '-s') {
        $moz_supported_file = shift(@ARGV);
    } elsif ($arg eq '-l') {
        $lpom_dir = shift(@ARGV);
    } else {
        die "Unknown argument '$arg'";
    }
}

(defined($moz_supported_file)) || die "Need to specify a supported language list";

if (defined($lpom_dir)) {
    my $lang_file = "$lpom_dir/maps/languages";
    my $map_file = "$lpom_dir/maps/locale2pkgname";
    my $variant_file = "$lpom_dir/maps/variants";

    open($file, $lang_file) or die "Failed to open $lang_file";
    while (<$file>) {
        chomp($_);
        my $langcode = my $lang = $_;
        $langcode =~ s/([^:]*):*([^:]*)/$1/;
        $lang =~ s/([^:]*):*([^:]*)/$2/;
        if ($lang ne "") { $languages{$langcode} = $lang; }
    }
    close($file);

    open($file, $map_file) or die "Failed to open $map_file";
    while (<$file>) {
        chomp($_);
        my $langcode = my $pkgname = $_;
        $langcode =~ s/([^:]*):*([^:]*)/$1/;
        $pkgname =~ s/([^:]*):*([^:]*)/$2/;
        if ($pkgname ne "") { $locale2pkgname{$langcode} = $pkgname; }
    }
    close($file);

    open($file, $variant_file) or die "Failed to open $variant_file";
    while (<$file>) {
        chomp($_);
        my $langcode = my $lang = $_;
        $langcode =~ s/([^:]*):*([^:]*)/$1/;
        $lang =~ s/([^:]*):*([^:]*)/$2/;
        if ($lang ne "") { $languages{$langcode} = $lang; }
    }
    close($file);
}

if (-e "debian/config/locales.all") {
    open($file, "debian/config/locales.all");
    while (<$file>) {
        $_ =~ s/#.*//; s/\s*$//;
        /^$/ || do {
            chomp($_);
            my $pkgname = my $lang = $_;
            $pkgname =~ s/([^:]*):*([^:]*)/$1/;
            $lang =~ s/([^:]*):*([^:]*)/$2/;
            $pkglist{$pkgname} = 1;
            if ($lang ne "") { $languages{$pkgname} = $lang; }
        }
    }
}

if (-e "debian/config/locales.shipped") {
    open($file, "debian/config/locales.shipped");
    while (<$file>) {
        $_ =~ s/#.*//; s/\s*$//;
        /^$/ || do {
            chomp($_);
            my $langcode = my $pkgname = $_;
            $langcode =~ s/([^:]*):*([^:]*)/$1/;
            $pkgname =~ s/([^:]*):*([^:]*)/$2/;
            if ($pkgname eq "") { die "Malformed locales.shipped file"; }
            if (not exists $pkglist{$pkgname}) {
                die "WTF? Language in locales.shipped is not present in locales.all. Did we produce broken output last time?";
            }
            $locale2pkgname{lc($langcode)} = $pkgname;
        }
    }
    close($file);
}

if (-e "debian/config/locales.blacklist") {
    open($file, "debian/config/locales.blacklist");
    while (<$file>) {
        $_ =~ s/#.*//; s/\s*$//;
        /^$/ || do {
            chomp($_);
            $blacklist{$_} = 1;
        }
    }
    close($file);
}

my $have_language = 0;

open($file, $moz_supported_file) or die "Failed to open $moz_supported_file";
open(my $outfile, ">debian/config/locales.shipped");
while (<$file>) {
    chomp($_);
    my $langcode = my $platforms = $_;
    $langcode =~ s/^([[:alnum:]\-]*)[[:space:]]*(.*)/$1/;
    $platforms =~ s/^([[:alnum:]\-]*)[[:space:]]*(.*)/$2/;
    next if (($langcode eq "en-US") ||
             (($platforms ne "") && (rindex($platforms, "linux") eq -1)) ||
             (exists $blacklist{$langcode}));
    my $llangcode = lc($langcode);
    my $pkgname = $llangcode;
    if (exists $locale2pkgname{$llangcode}) { $pkgname = $locale2pkgname{$llangcode}; }
    if (not exists $languages{$pkgname}) {
        if ($pkgname eq $llangcode) { $pkgname =~ s/\-.*//; }
        if (not exists $languages{$pkgname}) { die "No description for $pkgname"; }
    }
    if ($have_language eq 0) {
        print $outfile "# List of shipped locales. This list is automatically generated. Do not edit by hand\n";
    }
    $have_language = 1;
    print $outfile "$langcode:$pkgname\n";
    $pkglist{$pkgname} = 1;
}

if ($have_language eq 0) {
    print $outfile "# Placeholder file for the list of shipped languages. Do not delete";
}
close($file);
close($outfile);

open($outfile, ">debian/config/locales.all");
my @completelist = keys(%pkglist);
if (scalar(@completelist) gt 0) {
    @completelist = sort(@completelist);
    print $outfile "# List of all language packs, past and present. Please don't delete any entries from this file\n";
    foreach my $lang (@completelist) {
        if (not exists $languages{$lang}) { die "How on earth did we get here?"; }
        my $desc = $languages{$lang};
        print $outfile "$lang:$desc\n";
    }
} else { print $outfile "# Placeholder file for the list of all language packs. Do not delete"; }
close($outfile);
