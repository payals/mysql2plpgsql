#!/usr/local/bin/perl
#!/usr/local/bin/perl
use warnings;
use strict;

my @newline_keywords = ("CREATE", "RETURNS", "RETURN", "LANGUAGE", "AS", "DECLARE", "BEGIN", "END");
my %ignore_keywords = (
      'DETERMINISTIC' => 1, 
      'SQL SECURITY DEFINER' => 1,
  );
my $delimiters;
my @lines;
my $total_lines;
my @output;
my $plsql_type;				# 0 for function, 1 for procedure
my $add_return = 0;
my %variables_to_be_declared;
my $inout;
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

# Reads each line of file into array @lines
sub read_file {
  open (MYFILE, 'func.sql') || die "File not found";
  print "\n----------------\nOriginal: \n----------------\n";
  my $add = 1;
  while (<MYFILE>) {
	chomp;
	
	# Ignore rest of the file
	if ($_ eq '#ignore'){
	  last;
	}
	
	print "$_\n";
	
	if($add) {
	  push(@lines, $_);
	}
	
	if ($_ =~ m/end/i) {
	  $add = 0;
	}	
  }
  close (MYFILE);
	
  $total_lines = @lines;
}

# Converts lines to expected format for further conversion. Basically adjusts \n positions
sub structure_lines {
  for ( my $i = 0; $i <= $#lines; ++$i) { # print "$line\n";
    foreach my $key (keys %ignore_keywords) {
      if ($lines[$i] =~ m/($key)/i) { 
	    $lines[$i] =~ s/$1//i;
      }
    }
    foreach my $keyword(@newline_keywords) {
      if ($lines[$i] =~ m/^$keyword|\s+$keyword/i) { # print "TEST - $lines[$i]\n";
	if (uc($lines[$i]) !~ m/^$keyword.*/i) { # print "WORD - $keyword in LINE - $lines[$i]\n";
	  $lines[$i] =~ s/($keyword.*)//i;
	  splice (@lines, $i + 1, 0, $1);
	  $total_lines += 1;
	}
      }
    }
  }
}

# Removes empty lines. No empty lines help in assuming definite positions of before/after keywords in the array for conditions
sub remove_empty {
  for (my $i = 0; $i <= $#lines; ++$i) {
    if ($lines[$i] =~ m/^\s*$/) { #print "$i initial length = $#lines\n";
      splice(@lines, $i, 1); #print "$lines[2] and length is now $#lines\n";
      $total_lines -= 1;
      $i--;
    }
  }
}

# Removes the delimiter keyword and extracts the actual delimiter to append it to plpgsql where expected
sub remove_delimiter {
  for (my $i = 0; $i <= $#lines; ++$i) {
    if ($lines[$i] =~ m/delimiter\s*(.*)/i) {
      $delimiters = $1; # print "$delimiters\n";
      splice (@lines, $i, 1);
      $total_lines -= 1;
      return;
    }
  }
}

# Determines if the mysql block is a function or a stored procedure. If it is a procedure, then additional functions are needed for conversion.
sub plsql_type() {
  foreach my $count(0 .. $total_lines-1) {
    if ($lines[$count] =~ m/create .*function/i) {
      $plsql_type = 0;
    } elsif ($lines[$count] =~ m/create .*procedure/i) {
	$plsql_type = 1;
	$lines[$count] =~ s/procedure/FUNCTION/i;
      }
  }
  #print "$plsql_type\n";
}

# Name says it all, changes # to --
sub change_comments {
  foreach my $count(0 .. $total_lines-1) {
    $lines[$count] =~ s/\#/--/; 
  }
}

# Again, as the name says, converts " to ' and ` to " as accepted by postgres
sub change_quotes {
  foreach my $count(0 .. $total_lines-1) {
    $lines[$count] =~ s/"/'/g;
    $lines[$count] =~ s/`/"/g; 
  }
}

# Divides each line into words and compares each word with the hash of keywords. Not very bright. 
# TODO: Only look in areas where keywords might be present (Beginning, with DECLARE)
# TODO: Has a bug where recursive nature of s// changes substring if it matches in hash table first (SMALLINT after INT will change to SMALLINTEGER) Working on it
sub convert_datatype {
  foreach my $count(0 .. $total_lines-1) {
    my @words = split(' ', $lines[$count]);
    
    foreach my $word (@words) {
      $word =~ s/\s+|,|\(|\)|;//i;
      foreach my $key (keys %type_convert) {
	#print "$word\n";
	if((uc($word) eq $key)) {
	  #print "$word and $type_convert{$key}\n";
	  my $newval = $type_convert{$key};			 # print "$word\n";	
	  if($lines[$count] !~ m/$newval/){ 
	    $lines[$count] =~ s/$word/$newval/ig;
	  }
	}
      }
    }
  }
}

# If stored procedure with IN, OUT and INOUT parameters, parses them and adds to plpgsql as required
sub parse_args { 
  foreach my $count(0 .. $total_lines-1) {
    if($lines[$count] =~ m/create.*\(\s*\)/i) {
      next;
    }
    elsif($lines[$count] =~ m/create.*\((.*)\)/i) { 
      my @params = split(',', $1);
      
      foreach my $parameter (@params) {
	my @param_parts = split(' ', $parameter);
	
	for (my $i = 0; $i <= $#param_parts; ++$i) {
	  my $part = $param_parts[$i];
	  if(uc($part) eq 'IN') {#print "$part\n";
	    $lines[$count] =~ s/$part\s/ /i;
	  }
	  if(uc($part) eq 'OUT') {
	    $variables_to_be_declared{$param_parts[$i + 2]} = $param_parts[$i + 1];
	    $lines[$count] =~ s/$parameter//i;
	    $lines[$count] =~ s/,\s*,/,/i;
#  	    for my $key (keys %hash) {
# 	      print "$key\t$hash{$key}\n";
# 	    }
	  }
	  if(uc($part) eq 'INOUT') {
	    $inout = 1;
	    $variables_to_be_declared{$param_parts[$i + 2]} = $param_parts[$i + 1];
	    $lines[$count] =~ s/$part\s/ /i;
#  	    for my $key (keys %hash) {
# 	      print "$key\t$hash{$key}\n";
# 	    }
	  }
	}
      }
    }
  }
}

# Adds declare if not already present in stored procedures
# TODO: Add it only if not previously there and OUT is present, else let it be
# TODO: Remove individual DECLARE for every param and make a single one before BEGIN with all those params. Could use %variables_to_be_declared hash table for this.
sub add_declare {
  for (my $i = 0; $i <= $#lines; ++$i) {
    if ($lines[$i] =~ m/create/i) {
      if ($lines[$i + 1] !~ m/declare/i) {
	splice(@lines, $i + 1, 0, 'DECLARE');
	$total_lines += 1;
	return;
      }
    }
  }
}

# Removes the OUT parameters from argument part and adds them to the DECLARE section in case of stored procedure conversion
sub add_declare_params {
  for (my $i = 0; $i <= $#lines; ++$i) {
    if (($lines[$i] =~ m/declare/i) && (!$inout)) {
      foreach my $key (keys %variables_to_be_declared) {
	splice(@lines, $i + 1, 0, "   " . $variables_to_be_declared{$key} . " " . $key . ";");
	$total_lines += 1;
      }
    }
    if ($lines[$i] =~ m/end/i) {
      if ($lines[$i - 1] !~ m/return/i) {
	foreach my $key (keys %variables_to_be_declared) {
	  splice(@lines, $i, 0, "   RETURN " . $variables_to_be_declared{$key} . ";");
	  $total_lines += 1;
	}
      }
    }
  }
}

# Checks to see if return is already present or adds it when OUT parameter is removed in stored procedure. The OUT parameter type is returned
sub check_return {
  foreach my $count (0 .. $total_lines-1) {
    if ($lines[$count] =~ m/create/i) {
      if($lines[$count + 1] !~ m/returns/i) {
	foreach my $key (keys %variables_to_be_declared) {
	  splice(@lines, $count + 1, 0, "RETURNS " . $key);
	  $total_lines += 1;
	  return;
	}
      }
    }
  }
}

# Checks and adds LANGUAGE plpgsql if not already present
sub check_language {
  foreach my $count (0 .. $total_lines-1) {
    if ($lines[$count] =~ m/returns/i) {
      if($lines[$count + 1] !~ m/language/i) {
	splice(@lines, $count + 1, 0, "LANGUAGE plpgsql ");
	$total_lines += 1;
	return;
      }
      elsif ($lines[$count + 1] =~ m/language\s+(sql)/i) {
	$lines[$count + 1] =~ s/$1/plpgsql/i;
	return;
      }
    }
  }
}

# Checks for AS <delimiter> 
sub check_as {
  foreach my $count (0 .. $total_lines-1) {
    if ($lines[$count] =~ m/language/i) {
      if($lines[$count + 1] !~ m/as/i) {
	  splice(@lines, $count + 1, 0, "AS " . $delimiters);
	  $total_lines += 1;
	  return;
      }
    }
  }
}

# Appends the demimeter after END keyword
sub add_end_delimiter {
  foreach my $count (0 .. $total_lines-1) {
    if ($lines[$count] =~ m/end(.*)/i) {
      $lines[$count] =~ s/$1//i;#structure_lines();
      splice (@lines, $count + 1, 0, $delimiters . ";");
      $total_lines += 1;
      return;
    }
  }
}

# prints converted plpgsql function(barely right now) to stdout
sub output {
  print "\n----------------\nConverted: \n----------------\n";
  foreach my $count (0 .. $total_lines-1) {
    print "$lines[$count]\n";
  }
}

read_file();
structure_lines();
remove_empty();
remove_delimiter();
plsql_type();
change_comments();
change_quotes();
convert_datatype();

# if procedure
if ($plsql_type) {
  parse_args();
  add_declare();
  add_declare_params();
}

check_return();
check_language();
check_as();
add_end_delimiter();
output();
