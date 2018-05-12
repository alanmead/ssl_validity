#!/usr/bin/perl

# simulation of semi-supervised learning for validity studies

use strict;
use warnings;

use List::Util qw(sum shuffle);

my @nl_sample_sizes = qw/50 200 500/; # labeled
my @nu_sample_sizes = qw/50 200 500/; # unlabled
my $num_replications = 10;

my $test_length = 30;
my $pop_validity = 0.20;

for my $nl ( @nl_sample_sizes ) { 
  for my $nu ( @nu_sample_sizes ) { 
    for my $rep ( 1 .. $num_replications ) { 
      print "Replication $rep, NL = $nl, NU = $nu\n";
    }
  }
}



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
sub fisheryates_shuffle {
  my $array = shift;
  my $i = @$array;
  while ( --$i ) {
    my $j = int rand( $i+1 );
    @$array[$i,$j] = @$array[$j,$i];
  }
}
