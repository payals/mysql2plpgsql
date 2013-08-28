#!/usr/local/bin/perl
#!/usr/local/bin/perl
use warnings;
use strict;

my @newline_keywords = ("CREATE", "RETURNS", "LANGUAGE", "AS", "DECLARE", "BEGIN", "END");
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

sub structure_lines {
  for (my $i = 0; $i <= $#lines; ++$i) {
    foreach my $keyword(@newline_keywords) {
      if ($lines[$i] =~ m/$keyword/i) {
	if ($lines[$i] =! m/^$keyword.*/i) {
	  $lines[$i] =~ s/($keyword.*)//i;
	  splice (@lines, $i + 1, 0, $1);
	  $total_lines += 1;
	}
      }
    }
  }
}

sub remove_empty {
  for (my $i = 0; $i <= $#lines; ++$i) {
    if ($lines[$i] =~ m/^\s*$/) { #print "$i initial length = $#lines\n";
      splice(@lines, $i, 1); #print "$lines[2] and length is now $#lines\n";
      $total_lines -= 1;
      $i--;
    }
  }
}

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

sub change_comments {
  foreach my $count(0 .. $total_lines-1) {
    $lines[$count] =~ s/\#/--/; 
  }
}

sub change_quotes {
  foreach my $count(0 .. $total_lines-1) {
    $lines[$count] =~ s/"/'/g;
    $lines[$count] =~ s/`/"/g; 
  }
}

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

sub output {
  print "\n----------------\nConverted: \n----------------\n";
  foreach my $count (0 .. $total_lines-1) {
    print "$lines[$count]\n";
  }
}

read_file();
remove_empty();
#structure_lines();
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
