#!/usr/bin/perl

# simulation of semi-supervised learning for validity studies

use strict;
use warnings;

use List::Util qw(sum shuffle);
use Statistics::Basic qw/correlation/;

my $global_verbose = 1;

my @nl_sample_sizes = qw/50 100 200 500/; # labeled
my @nu_sample_sizes = qw/50 100 200 500 1000/; # unlabled
my $num_replications = 200;

my $test_length = 30;
my $pop_validity = 0.30;

my %details;
for my $nl ( @nl_sample_sizes ) { 
  for my $nu ( @nu_sample_sizes ) { 
    for my $rep ( 1 .. $num_replications ) { 
      my $cond = "NL=$nl,NU=$nu";
      #print "Replication $rep, NL = $nl, NU = $nu\n";
      simulate( \%details, $cond, $rep,
      {
        nl => $nl,
	nu => $nu,
	pop_r => $pop_validity,
	crit_rel => 0.70,
	test_rel => 0.80,
	test_mn => 20,
	test_sd => 3,
	nmatch => 5,
      });
    }
  }
}

## reporting

warn "reporting is a kludgy!\n";

my @r_sup;
my @r_semi;
for my $cond ( keys %details ) {
  for my $rep ( keys %{$details{$cond}} ) {
    push( @r_sup, $details{$cond}{$rep}{r_sup} );
    push( @r_semi, $details{$cond}{$rep}{r_semi} );
  }
  my $mu_sup = mean( @r_sup );
  my $mu_semi = mean( @r_semi );
  my $sd_sup = std_dev( @r_sup );
  my $sd_semi = std_dev( @r_semi );

  printf( "cond = %s, reps = %d, mu sup r = %.3f (sd=%.3f), mu semi r = %.3f (sd=%.3f)\n", 
    $cond,
    $num_replications,
    $mu_sup,
    $sd_sup,
    $mu_semi,
    $sd_semi 
  );
}



sub simulate {
  my($details, $cond, $rep, $options) = @_;

  # sanity check options; apply defaults
  my $nl = $$options{nl} || 100;
  my $nu = $$options{nu} || 200;
  my $pop_r = $$options{pop_r} || 200;
  my $crit_rel = $$options{crit_rel} || 0.80;
  my $test_rel = $$options{test_rel} || 0.80;
  my $test_mn  = $$options{test_mn} || 20;
  my $test_sd  = $$options{test_sd} || 3;
  my $nmatching  = $$options{nmatching} || 20;

  #print_simulaton_options( $options ); # debug

  # generate samples
  #printf "%10s %10s %10s %10s\n", qw/id obs_x obs_y labeled/; # debug
  #my(@xs,@ys); # debug
  my %data;
  for my $id ( 1 .. $nl+$nu ) { 
    my($x1,$x2) =  gaussian_rand();
    my($x3,$x4) =  gaussian_rand();
    my $true_x = $x1;
    my $true_y = $pop_r * $true_x + sqrt( 1 - $pop_r**2 ) * $x2;
    my $obs_x = sqrt($test_rel) * $true_x + sqrt( 1 - $test_rel ) * $x3;
    $obs_x = int( $obs_x * $test_sd + $test_mn + 0.5 );
    $obs_x = 0 if( $obs_x < 0 );
    my $obs_y = sqrt($crit_rel) * $true_y + sqrt( 1 - $crit_rel ) * $x4;
    $data{$id}{obs_x} = $obs_x;
    $data{$id}{obs_y} = $obs_y;
    $data{$id}{labeled} = ( $id <= $nl ? 1 : 0 );
    #printf "%10d %10.2f %10.2f %10d\n", $id, $obs_x, $obs_y, $data{$id}{labeled}; # debug
    #push( @xs, $true_x ); # debug
    #push( @ys, $obs_x ); # debug
  }
  #printf "Correlation: r = %.3f, N = %d\n", correlation( \@xs, \@ys )**2, $nl; # debug
  #warn "generated $nl labeled and $nu unlabeled cases\n" if( $global_verbose );

  # impute the missing labels for the unlabeled dataset
  for my $id ( keys %data ) { 
    if( $data{$id}{labeled} ) {
      $data{$id}{y} = $data{$id}{obs_y};
      next; # skip to next record
    }

    $data{$id}{y} = impute( \%data, $data{$id}{obs_x}, $nmatching );
  }

  # compute validity coefficients
  { 
    my(@x_sup,@y_sup);
    my(@x_semi,@y_semi);
    for my $id ( keys %data ) {
      push( @x_sup, $data{$id}{obs_x} ) if( $data{$id}{labeled} );
      push( @y_sup, $data{$id}{y} ) if( $data{$id}{labeled} );
      push( @x_semi, $data{$id}{obs_x} );
      push( @y_semi, $data{$id}{y} );
    }
    $details{$cond}{$rep}{r_sup} = correlation( \@x_sup, \@y_sup );
    $details{$cond}{$rep}{r_semi} = correlation( \@x_semi, \@y_semi );
    printf( "supervised r = %.3f, semi-supervised r = %.3f\n", $details{$cond}{$rep}{r_sup}, $details{$cond}{$rep}{r_semi} ) if( $global_verbose );
  }

} # simulate

# impute - performs score matching imputation
sub impute { 
  my( $data, $score, $nmatch ) = @_;

  die "matching N > M!\n" unless( $nmatch < scalar keys %$data );

  my @matching_ids;
  my $mc = -1;
  do {
    @matching_ids = ();
    $mc++;
    for my $id ( keys %$data ) { 
      next unless( $$data{$id}{labeled} ); # skip unlabeled data
      push(  @matching_ids, $id ) if( abs( $$data{$id}{obs_x} - $score ) <= $mc );
    }
    print "matching crit = $mc, score = $score, n matching = ", scalar @matching_ids, "\n" if( $global_verbose > 100 );
  } until( scalar @matching_ids >= $nmatch );

  # return a random criterion value
  my $id = $matching_ids[rand @matching_ids];
  print "found id = $id, y = $$data{$id}{obs_y}\n" if( $global_verbose > 100 );
  return $$data{$id}{obs_y};

} # impute


sub print_simulaton_options {
  my($options) = @_;

  print<<EOF;
Simulation Options
------------------

number labeled        : $$options{nl}
number unlabeled      : $$options{nu}
population validity   : $$options{pop_r}
criterion reliabiity  : $$options{crit_rel}
predictor reliability : $$options{test_rel}
predictor mean        : $$options{test_mn}
predictor SD          : $$options{test_sd}
replication           : $$options{rep}

EOF

} # print_simulaton_options


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


# Perl cookbook receipe 2.10
# http://web.deu.edu.tr/doc/oreily/perl/cookbook/ch02_11.htm 
sub gaussian_rand {
  my ($u1, $u2);  # uniformly distributed random numbers
  my $w;          # variance, then a weight
  my ($g1, $g2);  # gaussian-distributed numbers

  do {
    $u1 = 2 * rand() - 1;
    $u2 = 2 * rand() - 1;
    $w = $u1*$u1 + $u2*$u2;
  } while ( $w >= 1 );

  $w = sqrt( (-2 * log($w))  / $w );
  $g2 = $u1 * $w;
  $g1 = $u2 * $w;
  # return both if wanted, else just one
  return wantarray ? ($g1, $g2) : $g1;
}


