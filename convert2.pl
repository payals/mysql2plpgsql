#!/usr/local/bin/perl
#!/usr/local/bin/perl
use warnings;
use strict;

my $delimiters;
my @lines;
my $total_lines;
my $is_procedure = 0;
my $add_return = 0;
my $no_declare = -1;
my $declare_at = -1;
my $return_param;
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
   {restore i
      my $word = @_;
      foreach my $key ( keys %type_convert ) {
		    $word = uc($word);
		    if ($word eq $key) {
		      ####print "Found $val\n";
		      my $newval = $type_convert{$key};restore i
		      #$lines[$count] =~ s/$val/$newval/i;
		    }
      }
    }
   
 open (MYFILE, 'func.sql') || die "File not found";
 print "\n----------------\nOriginal: \n----------------\n";
 while (<MYFILE>) {
 	chomp;
	if (($_ =~ m/returns/i) && ($_ !~ m/create/i)) {			# if create... and returns... are not already in the same line
	  $lines[-1] = $lines[-1] . " " . $_;			# append returns... to the create function... line
	  next;
	}
	  
	if(($_ =~ m/language/i) && ($_ !~ m/create/i)) {
	  next;
	}
 	push(@lines, $_);
 	
 	if( m/declare/i) {
	  $declare_at = @lines;
 	}
 	
 	if ((m/begin/i) && ($declare_at == -1)) {
	  $no_declare = @lines;
 	}
 	# Ignore rest of the file
 	if ( $_ eq '#ignore'){
	  last;
	}
	print "$_\n";
 	
 }
 close (MYFILE);
 	
 $total_lines = @lines;

print "\n----------------\nConverted: \n----------------\n";

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
	
	  if ($lines[$count] =~ m/procedure/si) {
	    $is_procedure = 1;
	    $lines[$count] =~ s/procedure/FUNCTION/i;
	    
	    # Extract IN and OUT parameters and modify accordingly
	    my $uppercase_val;				 # to convert types to uppercase for conversion after comparision
	    my $newval;					 # the new converted datatype value
	    # my $argument;				 # the whole argument required to remove all OUT parameters
	    
	    if ($lines[$count] =~ m/\((.+)\)/i) {
	      #if ($1 =~ m/OUT\s*([0-9a-zA-Z_]+)\s+([0-9a-zA-Z_]+)/i)
	      my @parameters = split(",",$1);
	      foreach my $parameter (@parameters) {
		my @parameter_parts = split(" ", $parameter);
		
		#Check for type conversion
		foreach my $val (@parameter_parts) {
		  foreach my $key ( keys %type_convert ) {
		    $uppercase_val = uc($val);
		    if ($uppercase_val eq $key) {
		      ####print "Found $val\n";
		      $newval = $type_convert{$key};
		      $lines[$count] =~ s/$val/$newval/i;
		      $parameter =~ s/$val/$newval/i;			# append language... to create function... line/$newval/i;
		    }
		  }
		}
		foreach my $val (@parameter_parts) {
		  if ($val eq 'OUT') {
		    $lines[$count] =~ s/$parameter//i;
		    $lines[$count] = $lines[$count] . ' RETURNS ' . $newval . ' ';
		    $add_return = 1;
		    my @extract_return_param = split(" ", $parameter);
		    $return_param = $extract_return_param[1];
		    print "\n $return_param \n";
		    declare_params($return_param);
		  }
		}
	      }
	    }
	  }
	#}
	# Add returns keyword if not present
	if ($lines[$count] =~ m/create/i) {
	  if ($lines[$count] !~ m/returns/i) {
		$lines[$count] = $lines[$count] . ' RETURNS void ';
	  }
	}
	
	# Change to LANGUAGE plpgsql or add one if not already present
	$lines[$count] =~ s/^\s*language\s*sql/ LANGUAGE plpgsql/i;
	if (($lines[$count] =~ m/returns/i) && ($lines[$count + 1] !~ m/language/i)) { #print "HEREEEE $lines[$count]\n";
	      $lines[$count] = $lines[$count] . ' LANGUAGE plpgsql ';
	}

 	# Remove lines with just a semi-colon
 	if ($lines[$count] =~ m/end\s*;|end\s*/i)
 	{
	  if ($is_procedure) {
	    if ($add_return) {
	      print "\n RETURN $return_param; \n\n";
	    }
	  }
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
		$lines[$count - 1] = $lines[$count -1] . "\n AS $delimiters \n";
	}
	
	#}
}
print "$total_lines\n";
foreach my $count (1 .. @total_lines) {
  print "$lines[$count]\n";
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

sub declare_params
{
  my $parameter = @_;
  print "\n $parameter \n";
  # If declare doesn't exist, insert it before begin
  if ($declare_at == -1) {
    splice @lines, $no_declare - 1, 0, 'DECLARE';
    $declare_at = $no_declare + 1;
  }
  
  splice @lines, $declare_at, 0, $parameter;
  $total_lines = @lines;
}