#!/usr/local/bin/perl
#!/usr/local/bin/perl
use warnings;
use strict;

#parts to go into the pg func
my @comments;


 open (MYFILE, 'func.sql') || die "File not found";
 while (<MYFILE>) {
 	chomp;
	 
	# Checking for comments
	if ($_ =~ m/\#(.*)/i)
	{
	  push(@comments, $1);
	  print "$1\n";
	}
	
	

 }
 close (MYFILE);
