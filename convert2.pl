#!/usr/local/bin/perl
#!/usr/local/bin/perl
use warnings;
use strict;

my $delimiters;
my @lines;
my $total_lines;
my %type_convert = (
      'TINYINT' => 'SMALLINT',
      'SMALLINT' => 'SMALLINT',
      'MEDIUMINT' => 'INTEGER',
      'BIGINT' => 'BIGINT',
      'TINYINT UNSIGNED' => 'SMALLINT',
      'SMALLINT UNSIGNED' => 'INTEGER',
      'MEDIUMINT UNSIGNED' => 'INTEGER',
      'INT' => 'INTEGER',
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

   sub convert_type
   {
      $word = @_;
      foreach my $key ( keys %type_convert ) {
		    $word = uc($word);
		    if ($word eq $key) {
		      ####print "Found $val\n";
		      my $newval = $type_convert{$key};
		      $lines[$count] =~ s/$val/$newval/i;
		    }
      }
    }
   
 open (MYFILE, 'func.sql') || die "File not found";
 while (<MYFILE>) {
 	chomp;
 	push(@lines, $_);
 }
 close (MYFILE);
 	
 $total_lines = @lines;

foreach my $count (0 .. $total_lines) {

	# Remove empty lines
	if ($lines[$count] =~ /^\s*$/) {
	  next;
	}
	# Checking for comments
	$lines[$count] =~ s/\#/--/i;

	# Change all double quotes to single for strings, and accent marks to double quotes for system identifiers
	$lines[$count] =~ s/"/'/g;
	$lines[$count] =~ s/`/"/g;

	# Data type conversion
	my @words = split(' ', $lines[$count]);
	
	foreach my $val (@words) {
	  foreach my $key ( keys %type_convert ) {
	    $val = uc($val);
	    if ($val eq $key) {
	      ####print "Found $val\n";
	      my $newval = $type_convert{$key};
	      $lines[$count] =~ s/$val/$newval/i;
	    }
	  }
	}
	
	# Remove keyword Delimeter from MySQL functions and extract the actual delimiter
	####print "line --- $_\n";
	if ($lines[$count] =~ m/delimiter\s*(.*)/i)
	{ ####print "line is $_\n";
	  $delimiters = $1;
	  $lines[$count] =~ s/.*//i;
	}
	
	# Remove keyword procedure from MySQL functions
	if ($lines[$count] =~ m/create/i) {
	  if ($lines[$count] =~ m/procedure/si) {
	    $lines[$count] =~ s/procedure/FUNCTION/i;
	    if ($lines[$count] =~ m/\(\)/) {
	      $lines[$count] = $lines[$count] . "\n" . 'RETURNS void';
	    }
	    
	    # Extract IN and OUT parameters and modify accordingly
	    if ($lines[$count] =~ m/\((.+)\)/i) {
	      #if ($1 =~ m/OUT\s*([0-9a-zA-Z_]+)\s+([0-9a-zA-Z_]+)/i)
	      my @parameters = split(",",$1);
	      foreach my $parameter (@parameters) {
		my @parameter_parts = split(" ", $parameter);
		
		#Check for type conversion
		foreach my $val (@parameter_parts) {
		  foreach my $key ( keys %type_convert ) {
		    $val = uc($val);
		    if ($val eq $key) {
		      ####print "Found $val\n";
		      my $newval = $type_convert{$key};
		      $lines[$count] =~ s/$val/$newval/i;
		    }
		  }
		}
	      }
	    }
	  }
	}
	
	# Change to LANGUAGE plpgsql or add one if not already present
	$lines[$count] =~ s/^\s*language\s*sql/ LANGUAGE plpgsql/i;
	if (($lines[$count] =~ m/returns/i) && ($lines[++$count] !~ m/language/i)) { #print "HEREEEE $lines[$count]\n";
	      $lines[--$count] = $lines[--$count] . "\n" . 'LANGUAGE plpgsql';
	}

 	# Remove lines with just a semi-colon
 	if ($lines[$count] =~ m/end\s*;|end\s*/i)
 	{
	  $lines[$count] =~ s/end;|end\s*.*/end\n$delimiters;/i;
	  print "$lines[$count]\n";
	  last;
	}

	# Remove lines with empty semicolon and append semicolon to previous line
 	#if (($_ !~ /^\s*\;$/) && ($_ !~ /^\s*$delimiters$/) ) 
	#{
	# Add the 'AS' clause
	if($lines[$count] =~ m/begin/i)
	{
		print "AS $delimiters \n";
	}
	print "$lines[$count]\n";
	#}
}
#  
#  sub convert_type
#  {
# 
#     my $word = $_[0];  print "word is $word\n";
#     open (FILE, 'type_conversion.txt') || die "File not found";
#     while( my $line = <FILE> ){
# 	chomp; 
# 	if( $line =~ /$word/i)
# 	{ 
# 		#if(/\s*(.*)/i)
# 		#{
# 		my @pg_type = split(' - ', $line);
# 		return $pg_type[1];
# 		#}
# 	}
#     }
#     return $word;
#     close (FILE);
#  
#  }