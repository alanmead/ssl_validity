#!/usr/bin/perl

# simulation of semi-supervised learning for validity studies

use strict;
use warnings;

use List::Util qw(sum);

my $learn_sample_size = 200;
my $learn_prop_labeled = 0.50;
my $test_sample_size = 200;

my $test_length = 30;
my $pop_mean_citc


my $pfn = shift or die( "Please supply a pool filename\n" );

open( my $fh, "<$pfn" ) or die( "Cannot open pool file \"$pfn\": $!\n" );

my %items;
while ( my $line = <$fh> ) { 
  $line =~ s/[\r\n]*//g;
  $line =~ s/#.*$//g;
  next unless( $line );
  my($item_id, $obj, undef, $diff, $citc) = split /\t/, $line;
  next if( $item_id =~ /^\s*item\s*$/i );
  $items{$item_id} = {
    obj => $obj,
    diff => $diff,
    citc => $citc,
  };
}

close($fh);

print "Found ", scalar keys %items, " items\n";

# print pool summary

print "mean difficulty and citc by objective\n";
printf " %7s %7s %7s %7s\n", qw/obj n diff citc/;
for my $obj ( 1 .. 10 ) { 
  my $avg_diff = 0;
  my $avg_citc = 0;
  my $n = 0;
  for my $id ( sort{ $a <=> $b } keys %items ) { 
    next unless( $items{$id}{obj} eq $obj );
    $n++;
    $avg_diff += $items{$id}{diff};
    $avg_citc += $items{$id}{citc};
  }
  $avg_diff /= $n if( $n );
  $avg_citc /= $n if( $n );
  printf " %7d %7d %7.3f %7.3f\n", $obj, $n, $avg_diff, $avg_citc;
}

# simulation

my $reps = 1000;

my %results;
my @avg_diffs;
my @avg_citcs;
for my $it ( 1 .. $reps ) { 
  my $avg_diff = 0;
  my $avg_citc = 0;
  for my $obj ( 1 .. 10 ) { 
    my @avail;
    for my $id ( keys %items ) { 
      next unless( $items{$id}{obj} eq $obj );
      push( @avail, $id );
    }
    die "Zero items available for objective $obj!\n" unless( @avail );
    shuffle( \@avail );
    my $id = $avail[0];
    $avg_diff += $items{$id}{diff};
    $avg_citc += $items{$id}{citc};
  }
  $avg_diff /= 10;
  $avg_citc /= 10;
  push( @avg_diffs, $avg_diff );
  push( @avg_citcs, $avg_citc );
  $results{$it} = { 
    diff => $avg_diff, 
    citc => $avg_citc, 
  };
}

my($min_diff, $max_diff) = minmax( @avg_diffs );
my($pct25_diff, $pct50_diff, $pct75_diff ) = interquartile_range( @avg_diffs );
my $avg_diff = mean( @avg_diffs );
my $sd_diff = std_dev( @avg_diffs );

my($min_citc, $max_citc) = minmax( @avg_citcs );
my($pct25_citc, $pct50_citc, $pct75_citc ) = interquartile_range( @avg_citcs );
my $avg_citc = mean( @avg_citcs );
my $sd_citc = std_dev( @avg_citcs );

for ( $avg_diff, $sd_diff, $pct50_diff, $pct25_diff, $pct75_diff, $min_diff, $max_diff, 
      $avg_citc, $sd_citc, $pct50_citc, $pct25_citc, $pct75_citc, $min_citc, $max_citc ) { 
  $_ = sprintf "%.3f", $_;
}

print<<EOF;

Simulation

Difficulty (proportion correct)

mean   : $avg_diff
SD     : $sd_diff
median : $pct50_diff
IQR    : [ $pct25_diff, $pct75_diff ]
range  : [ $min_diff, $max_diff ]


Corrected Item-Total Correlation (higher is better)

mean   : $avg_citc
SD     : $sd_citc
median : $pct50_citc
IQR    : [ $pct25_citc, $pct75_citc ]
range  : [ $min_citc, $max_citc ]

EOF


# calculate mean
sub mean {
  return sum(@_)/@_;
}

# calculate min/max
sub minmax {
  my (@data) = @_;
  my $min = undef;
  my $max = undef;
  foreach (@data) {
    $min = $_ if( !defined( $min )); 
    $min = $_ if( $_ < $min ); 
    $max = $_ if( !defined( $max )); 
    $max = $_ if( $_ > $max ); 
  }
  return ( $min, $max );
}

# calculate mean (algo 2)
sub mean2 {
  my (@data) = @_;
  my $sum;
  foreach (@data) {
    $sum += $_;
  }
  return ( $sum / @data );
}

# calculate median 
sub median {
  my (@data) = sort { $a <=> $b } @_;
  if ( scalar(@data) % 2 ) {
    return ( $data[ @data / 2 ] );
  } else {
    my ( $upper, $lower );
    $lower = $data[ @data / 2 ];
    $upper = $data[ @data / 2 - 1 ];
    return ( mean2( $lower, $upper ) );
  }
}

# calculate interquartile range
sub interquartile_range {
  my (@data) = sort { $a <=> $b } @_;
  my $pct25 = 0;
  my $pct50 = 0;
  my $pct75 = 0;
  # 25TH and 75TH percentile
  my $thres = int( @data / 4 );
  $pct25 = mean2( $data[ $thres ], $data[ $thres + 1 ] );
  $pct75 = mean2( $data[ @data - $thres ], $data[ @data - $thres - 1 ] );
  # median
  if ( scalar(@data) % 2 ) {
    $pct50 = $data[ @data / 2 ];
  } else {
    my $lower = $data[ @data / 2 ];
    my $upper = $data[ @data / 2 - 1 ];
    $pct50 = mean2( $lower, $upper );
  }
return( $pct25, $pct50, $pct75 );
}

# calculate SD
sub std_dev {
  my (@data) = @_;
  my ( $sq_dev_sum, $avg ) = ( 0, 0 );
  
  $avg = mean2(@data);
  foreach my $elem (@data) {
    $sq_dev_sum += ( $avg - $elem )**2;
  }
  return ( sqrt( $sq_dev_sum / ( @data - 1 ) ) );
}



# randomly permutate @array in place Fisher-Yates shuffle
sub shuffle {
  my $array = shift;
  my $i = @$array;
  while ( --$i ) {
    my $j = int rand( $i+1 );
    @$array[$i,$j] = @$array[$j,$i];
  }
}
