use Test::More tests => 10003;

BEGIN {
use_ok( 'Data::Rand' );
}

diag( "Testing Data::Rand $Data::Rand::VERSION" );

my %seen;
for my $c (1 .. 10000) {
    my $rand = rand_data(); # do not use NS so we know export is good as per POD
    ok(!exists $seen{$rand}, "no dupe $c");
    $seen{$rand}++;
}

ok(Data::Rand::rand_data(1,['a']) eq 'a', 'gauranteed dup ok 1');
ok(Data::Rand::rand_data(1,['a']) eq 'a', 'gauranteed dup ok 2');