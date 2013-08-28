#!/usr/local/bin/perl
#!/usr/local/bin/perl
use warnings;
use strict;

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

 sub remove_empty {
  for (my $i = 0; $i <= $#lines; ++$i) {
    if ($lines[$i] =~ m/^\s*$/) { #print "$i initial length = $#lines\n";
      splice(@lines, $i, 1); #print "$lines[2] and length is now $#lines\n";
      $total_lines -= 1;
      $i--;
    }
  }
 }
 
 sub plsql_type() {
  foreach my $count(0 .. $total_lines-1) {
    if ($lines[$count] =~ m/create .*function/i) {
      $plsql_type = 0;
    } elsif ($lines[$count] =~ m/create .*procedure/i) {
	$plsql_type = 1;
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
	  my $newval = $type_convert{$key};			 #print "$word\n";	
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
	splice(@lines, $i + 1, 0, "\t" . $variables_to_be_declared{$key} . "\t" . $key . ";");
	$total_lines += 1;
      }
    }
    if ($lines[$i] =~ m/end/i) {
      if ($lines[$i - 1] !~ m/return/i) {
	foreach my $key (keys %variables_to_be_declared) {
	  splice(@lines, $i, 0, "RETURN " . $variables_to_be_declared{$key} . ";");
	  $total_lines += 1;
	}
      }
    }
  }
 }
 
 open (MYFILE, 'func.sql') || die "File not found";
 print "\n----------------\nOriginal: \n----------------\n";
 while (<MYFILE>) {
 	chomp;
 	
 	# Ignore rest of the file
 	if ( $_ eq '#ignore'){
	  last;
	}
	
	push(@lines, $_);
	
	print "$_\n";
 	
 }
 close (MYFILE);
 	
 $total_lines = @lines;

print "\n----------------\nConverted: \n----------------\n";

remove_empty();
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

foreach my $count (0 .. $total_lines-1) {
  print "$lines[$count]\n";
}
