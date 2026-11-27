my $file = shift;
local $/; open my $fh, '<', $file or die; my $s = <$fh>; close $fh;
exit 0 if $s =~ /services\.aster-bridge/;
my $line = "- [Aster Bridge](https://github.com/Aster-Privacy/Aster-Bridge), a local IMAP, SMTP, JMAP, POP3, and CardDAV bridge for Aster Mail. Available as [services.aster-bridge](#opt-services.aster-bridge.enable).\n";
$s =~ /(## New Modules[^\n]*\n\n(?:<!--[^\n]*-->\n\n)?)/ or die "no New Modules heading in $file\n";
my $head = $1;
$s =~ s/\Q$head\E- Create the first release note entry in this section!\n/$head$line/
  or $s =~ s/\Q$head\E/$head$line\n/;
open my $out, '>', $file or die; print $out $s; close $out;
