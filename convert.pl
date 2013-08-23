#!/usr/local/bin/perl
#!/usr/local/bin/perl
use warnings;
use strict;

my $delimiters;
my %type_convert = (
      'TINYINT' => 'SMALLINT',
      'SMALLINT' => 'SMALLINT',
      'MEDIUMINT' => 'INTEGER',
      'BIGINT' => 'BIGINT',
      'TINYINT UNSIGNED' => 'SMALLINT',
      'SMALLINT UNSIGNED' => 'INTEGER',
      'MEDIUMINT UNSIGNED' => 'INTEGER',
      'INT UNSIGNED' => 'BIGINT',
      'BIGINT UNSIGNED' => 'NUMERIC(20)',
      'FLOAT' => 'REAL',
      'FLOAT UNSIGNED' => 'REAL',
      'DOUBLE' => 'DOUBLE PRECISION',
      'BOOLEAN' => 'BOOLEAN',
      'TINYTEXT' => 'TEXT',
      'TEXT' => 'TEXT',
      'MEDIUMTEXT' => 'TEXT',
      'LONGTEXT' => 'TEXT',
      'BINARY(n)' => 'BYTEA',
      'VARBINARY(n)' => 'BYTEA',
      'TINYBLOB' => 'BYTEA',
      'BLOB' => 'BYTEA',
      'MEDIUMBLOB' => 'BYTEA',
      'LONGBLOB' => 'BYTEA',
      'ZEROFILL' => 'na',
      'DATE' => 'DATE',
      'TIME' => 'TIME [WITHOUT TIME ZONE]',
      'DATETIME' => 'TIMESTAMP [WITHOUT TIME ZONE]',
      'TIMESTAMP' => 'TIMESTAMP [WITHOUT TIME ZONE]',
   );

 open (MYFILE, 'func.sql') || die "File not found";
 while (<MYFILE>) {
 	chomp;
 	
	# Remove empty lines
	if ($_ =~ /^\s*$/) {
	  next;
	}
	# Checking for comments
	s/\#/--/i;

	# Change all double quotes to single for strings, and accent marks to double quotes for system identifiers
	s/"/'/g;
	s/`/"/g;

	# Data type conversion
	my @words = split(' ', $_);
	
	foreach my $val (@words) {
	  foreach my $key ( keys %type_convert ) {
	    $val = uc($val);
	    if ($val eq $key) {
	    print "Found $val\n";
	      my $newval = $type_convert{$key};
	      $_ =~ s/$val/$newval/i;
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

    my $word = $_[0];  print "word is $word\n";
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