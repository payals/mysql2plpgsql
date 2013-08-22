#!/usr/local/bin/perl
#!/usr/local/bin/perl
use warnings;
use strict;

my $delimiters;

 open (MYFILE, 'func.sql') || die "File not found";
 while (<MYFILE>) {
 	chomp;
	 
	# Checking for comments
	s/\#/--/i;

	# Change all double quotes to single for strings, and accent marks to double quotes for system identifiers
	s/"/'/g;
	s/`/"/g;

	# Data type conversion table using 2-D array
	my @values = split();

	foreach my $val (@values) {
	  #####print "$val\n";
	  if ($val =~ /\w/i && $val !~ /\w\(\)/i)
	  { 
	      my $res = convert_type($val); #########print "val = $val and result = $res\n";
	      if ($_ =~ /$val/i)
	      {
		    s/$val/$res/ig;   #########print "new val = $val\n line = $_";
	      }
	  }
	}
	
	# Remove keyword Delimeter from MySQL functions and extract the actual delimiter
	if ($_ =~ m/delimiter\s*(.*)/i)
	{
	  $delimiters = $1;
	  $_ =~ s/.*//i;
	}
	
	# Remove keyword procedure from MySQL functions
	$_ =~ s/procedure/function/i;
	
	# Change to LANGUAGE plpgsql
	s/^\s*language\s*sql/ LANGUAGE plpgsql/i;

 	# Remove lines with just a semi-colon
 	if ($_ =~ m/end\s*;|end\s*/i)
 	{
	  s/end;|end\s*.*/end\n$delimiters;/i;
	  
	}

	# Remove lines with empty semicolon and append semicolon to previous line
 	#if (($_ !~ /^\s*\;$/) && ($_ !~ /^\s*$delimiters$/) ) 
	#{
	# Add the 'AS' clause
	if(m/begin/i)
	{
		print "AS $delimiters \n";
	}
	print "$_\n";
	#}
 }
 close (MYFILE);
 
 sub convert_type
 {

    my $word = $_[0];  #########print "word is $word\n";
    open (FILE, 'type_conversion.txt') || die "File not found";
    while( my $line = <FILE> ){
	chomp;
	if( $line =~ /$word/i)
	{ 
		#if(/\s*(.*)/i)
		#{
		my @pg_type = split(' - ', $line);
		return $pg_type[1];
		#}
	}
    }
    return $word;
    close (FILE);
 
 }