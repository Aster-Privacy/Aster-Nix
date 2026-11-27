my ($file, $pattern, $key, $block, $start) = @ARGV;
open my $fh, '<', $file or die; my @lines = <$fh>; close $fh;
my $first = (split /\n/, $block)[0];
exit 0 if grep { index($_, $first) >= 0 } @lines;
my $re = qr/$pattern/;
my $begin = 0;
if (defined $start) { my $sr = qr/$start/; ($begin) = grep { $lines[$_] =~ $sr } 0..$#lines; die "no start in $file\n" unless defined $begin; }
for my $i ($begin..$#lines) {
  if ($lines[$i] =~ $re && lc($1) gt lc($key)) {
    splice @lines, $i, 0, $block;
    open my $out, '>', $file or die; print $out @lines; close $out; exit 0;
  }
}
die "no insertion point in $file\n";
