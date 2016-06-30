#!/usr/bin/env perl

# Syntax highlighting - IPP project
# 2012 Fridolin Pokorny <fridex.devel@gmail.com>

# TODO: remove on deadline
use warnings;
#use diagnostics;
use strict;
use utf8;

use locale;
use Getopt::Long;

################################################################################

# Print simple help.
# @param - printed error message (optional)
# @return - none
sub print_help(;$) {
    print STDERR ${$_[0]} if $_[0];

    print "Highlight syntax specified by regular expresions.\n\n";
    print "Usage: $0 [OPTIONS]\n";
    print "  --help             print this simple help\n";
    print "  --format=FILE      specify FILE with regexp for syntax\n";
    print "  --input=FILE       specify FILE to highlight syntax (UTF-8)\n";
    print "  --output=FILE      specify FILE with highlighted syntax (UTF-8)\n";
    print "  --br               append <br /> tag on end of line\n\n";
    print "Fridolin Pokorny 2012 <fridex.devel\@gmail.com>\n";
    print "Version: 0.2a\n";
}

# Process arguments and check for necessary options.
# @param - none
# @return - reference to hash with processed options
sub check_opt() {
    my ( @opt_help, @opt_input, @opt_output, @opt_format, @opt_br, %param );

    if (! GetOptions('help'       => \@opt_help,
                     'input=s'    => \@opt_input,
                     'output=s'   => \@opt_output,
                     'format=s'   => \@opt_format,
                     'br'         => \@opt_br)
                 or @opt_help or @_ ) {
        print_help();
        exit 1 if not @opt_help or @opt_help > 1;
        exit 1 if @opt_format or @opt_input or @opt_output or @opt_br;
        exit 0;
    }

    if ( @ARGV != 0 ) {
        print_help(\("Unknown option: " . $ARGV[0] . "\n"));
        exit 1;
    }

    # If input is not specified, STDIN is used. If output is not specified,
    # STDOUT is used. Notice there is only one input/output/format file.
    print_help(\"Format file specified badly!\n") and exit 1 if @opt_format  > 1;
    print_help(\"Too many input files!\n")        and exit 1 if @opt_input   > 1;
    print_help(\"Too many output files!\n")       and exit 1 if @opt_output  > 1;
    print_help(\"Too many --br options!\n")       and exit 1 if @opt_br      > 1;

    # Fill hash!
    $param{"fin"}  = $opt_input[0]  if @opt_input;
    $param{"fout"} = $opt_output[0] if @opt_output;
    $param{"br"}   = $opt_br[0]     if @opt_br;
    $param{"fmt"}  = $opt_format[0] if @opt_format;

    return \%param;
}

# Open input, format and output files.
# @param - hash reference with processed options
# @return - none
sub open_files($) {
    if ( exists ${$_[0]}{"fin"} ) {
        open(FIN, "<", ${$_[0]}{"fin"})
            or
            print STDERR "Cannot open input file:" . ${$_[0]}{"fin"} . ": $!\n"
                and exit 2;
    }
    else {
        open(FIN, "<-") or
            print STDERR "Cannot open stdin: $!\n"
                and exit 2;
    }

    if ( exists ${$_[0]}{"fout"} ) {
        open(FOUT, ">", ${$_[0]}{"fout"})
            or
            print STDERR "Cannot open output file:" . ${$_[0]}{"fout"} .": $!\n"
                and exit 3;
    }
    else {
        open(FOUT, ">-") or
            print STDERR "Cannot open stdout: $!\n"
                and exit 2;
    }

    if ( exists ${$_[0]}{"fmt"} ) {
        open(FMT, "<", ${$_[0]}{"fmt"})
            or
            print STDERR "Cannot open format file:" . ${$_[0]}{"fmt"} . ": $!\n"
                and exit 2;
    }
}

# Translate regexp to perl regexp.
# @param - regexp reference to be translated
# @return - none
sub syntax_format2perlre(\$) {
    my ( $string ) = @_;
    my ( $idx, $count, $char, $tmp);

    return if not $$string; # Empty rule.

    #print "\tRegexp before: $$string\n";

    # http://perldoc.perl.org/perlre.html
    # Escape special in perlre listed in format file.
    $$string =~ s/\\/\\\\/g;
    $$string =~ s/\?/\\\?/g;
    $$string =~ s/\{/\\\{/g;
    $$string =~ s/\}/\\\}/g;
    $$string =~ s/\^/\\\^/g;
    $$string =~ s/\$/\\\$/g;
    $$string =~ s/\[/\\\[/g;
    $$string =~ s/\]/\\\]/g;

    # Escaping special chars.
    # Brackets are used to group escaped chars to apply simple rule for
    # escaping. It is easy to determinate if char is escaped in next rules.
    # %%%%%%%%%!
    # (%%)(%%)(%%)(%%)%! => `!' is escaped and it is easy to figure it out!
    $$string =~ s/%%/\(%%\)/g;
    $$string =~ s/(^|[^%])%\)/$1\\\)/g;
    $$string =~ s/(^|[^%])%\(/$1\\\(/g;

    $$string =~ s/(\\\\)/(\(\\\\\))/g;

    # Cannot concatenate empty string.
    if ( $$string =~ /((^|[^%])\.$)|(^\.)|((^|[^%])\.\.)|((^|[^%])\.\*)|((^|[^%])\.\+)/
            or
         $$string =~ /(^|[^%])\(\.|(^|[^%])\.\)|((^|[^%])\.\|)|((^|[^%])\|\.)/ ) {
        print STDERR "Unable to concatenate empty string!\n";
        print STDERR "Check your format file!\n";
        exit 4;
    }

    if ( $$string =~ /(^|[^%])!$/ ) {
        print STDERR "Unable to negate empty string!\n";
        print STDERR "Check your format file!\n";
        exit 4;
    }

    if ( $$string =~ /(^|[^\\])\(\)/ ) {
        print STDERR "Empty string in brackets not allowed!\n";
        print STDERR "Check your format file\n";
        exit 4;
    }

    # Replace negation - e.g. !a => [^a]
    while ( $$string =~ /(^|[^%])!([^%])/ ) {
        $$string =~ s/(^|[^%])!([^%])/$1\[\^$2\]/g;
        $char = substr($$string, $+[2], 1);
        if ( $char eq "!" or $char eq "(" or $char eq "."
             or $char eq "|" or $char eq "+" or $char eq "*") {
            print STDERR "Bad escape sequence!\n";
            print STDERR "Check your format file\n";
            exit 4;
        }
    }

    # Escape sequence check is done later.
    $$string =~ s/(^|[^%])!(%.)/$1\[\^$2\]/g; # !%x => [^(%x)]

    $$string =~ s/(^|[^%])\./$1/g;  # A.B => AB
    $$string =~ s/%\./\\\./g;       # %.  => \.

    $$string =~ s/%\!/!/g;          # %! => !
    $$string =~ s/%\|/\\\|/g;       # %| => \|
    $$string =~ s/%\*/\\\*/g;       # %* => \*
    $$string =~ s/%\+/\\\+/g;       # %+ => \+
    $$string =~ s/%\(/\\\(/g;       # %( => \(
    $$string =~ s/%%/%/g;           # %% => %

    # Translate escape sequences.
    $$string =~ s/%s/( |\\t|\\n|\\r|\\f|\\v)/g;
    $$string =~ s/%a/(\.|\\\n)/g;
    $$string =~ s/%d/([0-9])/g;
    $$string =~ s/%l/([a-z])/g;
    $$string =~ s/%L/([A-Z])/g;
    $$string =~ s/%w/([a-z]|[A-Z])/g;
    $$string =~ s/%W/([a-z]|[A-Z]|[0-9])/g;
    $$string =~ s/%t/\t/g;
    $$string =~ s/%n/\n/g;

    # Now there should be only (%) in regexp. If there is another escape
    # sequence, an error occurred.
    if ( $$string =~ /%[^\)]|%$/ ) {
        print STDERR "Unknown escape sequence!\n";
        print STDERR "Check your format file\n";
        exit 4;
    }

    # Disable Perl's posssessive RE and bonus implementation.
    # ** => *
    # ++ => +
    # *+ => *
    # +* => *
    $$string =~ s/\\\\/(\\\\)/g;
    my $end = 0;
    while (not $end) {
        $end = 1;
        while ($$string =~ /(^|[^\\])\+\+/) {
            $$string =~ s/(^|[^\\])\+\+/$1\+/g;
            $end = 0;
        }

        while ($$string =~ /(^|[^\\])\*\*/) {
            $$string =~ s/(^|[^\\])\*\*/$1\*/g;
            $end = 0;
        }

        while ($$string =~ /(^|[^\\])\*\+/) {
            $$string =~ s/(^|[^\\])\*\+/$1\*/g;
            $end = 0;
        }

        while ($$string =~ /(^|[^\\])\*\+/) {
            $$string =~ s/(^|[^\\])\+\*/$1\*/g;
            $end = 0;
        }
    }

    #print "\t\tRegexp after: $$string\n";
}

# Check for disallowed regexp combinations.
# @param - regexp to be checked
sub syntax_check_regexp(\$) {
    my ( $string ) = @_;

    return if not $$string; # Empty rule.

    if ( $$string =~ /(^)(\+|\*)/ ) {
        print STDERR "Empty string iteration!\n";
        print STDERR "Check your format file\n";
        exit 4;
    }

    if ( $$string =~ /\((\+|\*)/ ) {
        print STDERR "Empty string iteration!\n";
        print STDERR "Check your format file\n";
        exit 4;
    }

    if ( $$string =~ /(!!)|(!\()|(!\+)|(!\*)|(!\|)/ ) {
        print STDERR "Empty string negation!\n";
        print STDERR "Check your format file\n";
        exit 4;
    }

    if ( $$string =~ /([^\\]!$)/ ) {
        print STDERR "Nothing to negate!\n";
        print STDERR "Check your format file\n";
        exit 4;
    }

    if ( $$string =~ /([^\\]\|$)|(^\|)/ ) {
        print STDERR "Unknown alternation. Empty string?!\n";
        print STDERR "Check your format file\n";
        exit 4;
    }

    if ( $$string =~ /(^|[^\\])\(\)/ ) {
        print STDERR "Empty string in brackets not allowed!\n";
        print STDERR "Check your format file\n";
        exit 4;
    }

    if ( $$string =~ /((^|[^\\])\|\|)|(^\|)|((^|[^\\])\|$)|((^|[^\\])\(\|)/
            or
        $$string =~ /((^|[^\\])\|\))|((^|[^\\])\|\*)|((^|[^\\])\|\+)/ ) {
        print STDERR "Bad alternative!\n";
        print STDERR "Check your format file\n";
        exit 4;
    }

    # Check brackets count.
    my ( $char, $idx, $count );
    $count = 0;
    for ( $idx = 0; $idx < length $$string and $count >= 0; $idx += 1 ) {
        $char = substr($$string, $idx, 1);
        if ( $char eq "(" ) {

            if ( $idx != 0 ) {
                $char = substr($$string, $idx - 1, 1);
                $count++ if $char ne "\\";
            } else { $count++ }

        } elsif ( $char eq ")" ) {
            if ( $idx != 0 ) {
                $char = substr($$string, $idx - 1, 1);
                $count-- if $char ne "\\" or
                            ($char eq "\\" and substr($$string, $idx - 2, 1) eq "\\");
            } else { $count = -1; }

        }
    }

    if ( $count != 0 ) {
        print STDERR "Bracket collision!\n";
        exit 4;
    }
}

# Create string suitable to be used before and after text defined by regexp.
# @param - format from format file
# @param - 1 if start tag, 0 if end tag is generated
# @return - string with HTML tags
sub syntax_get_tags(\$$) {
    my ( $format, $start ) = @_;
    my ( @options, $stringtag );

    if ( not  $$format ) {
        print STDERR "Empty format option not allowed!\n";
        exit 4;
    }

    $stringtag = "";
    if ($$format =~ /,(\t| )*,/ or $$format =~ /,$/) {
        print STDERR "Syntax error in format file!\n";
        exit 4;
    }

    @options = split(/,/, $$format);
    for my $option ( @options ) {
    # Note closing tags are appended in reverse order!
        if ( $option ) {
            $option =~ s/^\s*//g; # remove white-spaces from format option.
            $option =~ s/\s*$//g; # remove white-spaces from format option.
            if ( $option =~ /^bold$/ ) {

                if ( $start ) { $stringtag .= "<b>" }
                else { $stringtag = "</b>" . $stringtag }

            } elsif ( $option =~ /^italic$/ ) {

                if ( $start ) { $stringtag .= "<i>" }
                else { $stringtag = "</i>" . $stringtag }

            } elsif ( $option =~ /^underline$/ ) {

                if ( $start ) { $stringtag .= "<u>" }
                else { $stringtag = "</u>" . $stringtag }

            } elsif ( $option =~ /^teletype$/ ) {

                if ( $start ) { $stringtag .= "<tt>" }
                else { $stringtag = "</tt>" . $stringtag }

            } elsif ( $option =~ /^size:(\d+)$/ ) {
                if ( $1 == 0 or $1 > 7 ) {
                    print STDERR "Bad size\n";
                    exit 4;
                }

                if ( $start ) {
                    $stringtag .= "<font size=$1>"
                } else {
                    $stringtag = "</font>" . $stringtag
                }

            } elsif ( $option =~ /^color:([ABCDEF0123456789]{6})$/ ) {
                if ( $start ) { $stringtag .= "<font color=#$1>" }
                else { $stringtag = "</font>" . $stringtag }

            } else {
                print STDERR "Unkown format option: `$option'\n";
                exit 4;
            }
        } else {
            print STDERR "Empty format!\n";
            exit 4;
        }
    }

    return $stringtag;
}

# Add new syntax rule parsed from input file to array of rules.
# @param - array reference with syntax rules
# @param - line reference from format file
# @return - none
sub syntax_format(\@\$) {
    my ( $regexp, $line ) = @_;
    my ( $rule, $format );
    my ( $start_tag, $end_tag);

    # Split line. Regexp should not contain \t directly!
    chomp( $$line );
    ( $rule, $format ) = split(/\t+/, $$line, 2);

    syntax_format2perlre($rule);
    syntax_check_regexp($rule);

    # Add rule to to array of rules.
    # First position is a regexp. Second is reserved for opening tags and last,
    # third, is used for ending HTML tags.
    $start_tag = syntax_get_tags($format, 1);
    $end_tag = syntax_get_tags($format, 0);

    push(@$regexp, [$rule, $start_tag, $end_tag]) if $rule;
}

# Compute indexes and put them to an array.
# @param - array reference to stored indexes
# @param - array reference with prepared regexps
# @param - input text to apply regexp and compute indexes
# @return - none
sub syntax_indexes(\@\@\@\$) {
    my ( $indexes, $indexes_end, $regexp, $input ) = @_;
    my ( $rule );

    return if not $$input; # Empty input, nothing to do! :'(

    foreach $rule ( @$regexp ) {
        while ( $$input =~ /($rule->[0])/g ) {
            # Each item in index list consists of position (index) in the text
            # to place starting tag ($rule->[1]) or ending tag ($rule->[2]).
            if ( $-[0] != $+[0] ) { # do not allow empty strings
                push(@$indexes, [$-[0], $rule->[1]]);
                push(@$indexes_end, [$+[0], $rule->[2]]);
            }
        }
    }
}

# Print input text to output file and place HTML tags on specified position.
# @param - input text
# @param - computed indexes with HTML tags to be placed
# @param - 1 to print <br/> on EOL, 0 otherwise
sub syntax_print(\$\@\@$) {
    my ( $input, $indexes, $indexes_end, $print_br ) = @_;
    my ( $char, $tag, $idx );

    return if not $$input; # Empty input... :'(

    @$indexes_end = reverse(@$indexes_end); # End tags are placed in reverse order!

    for ( $idx = 0; $idx < length $$input; ++$idx ) {
        $char = substr($$input, $idx, 1);

        foreach $tag ( @$indexes_end ) {
            print FOUT $tag->[1] if $idx == $tag->[0];
        }

        # Check for HTML tags to add before char.
        foreach $tag ( @$indexes ) {
            print FOUT $tag->[1] if $idx == $tag->[0];
        }

        # Print <br/> tag if --br option was set.
        if ($char eq "\n") {
            if ( $print_br ) { print FOUT "<br />\n" }
            else { print FOUT "\n" }
        }
        else { print FOUT $char };
    }

    foreach $tag ( @$indexes_end ) {
        print FOUT $tag->[1] if $tag->[0] == length($$input);
    }

    # Append tags which are after original EOF.
    foreach $tag ( @$indexes ) {
        print FOUT $tag->[1] if $tag->[0] == length($$input);
    }
}

# Highlight syntax.
# @param - hash reference with processed options
# @return - none
sub syntax($) {
    my ( $param ) = @_;
    my ( @indexes, @indexes_end, $line, @regexp, $input );

    if ( exists $$param{"fmt"} ) {
        syntax_format(@regexp, $line) while $line = <FMT>;
    }

    # Whole file has to be stored in memory. Line-based processing is not
    # posible in easy way because of `%n' regexp.
    $input .= $line while $line = <FIN>;
    syntax_indexes(@indexes, @indexes_end, @regexp, $input);
    syntax_print($input, @indexes, @indexes_end, exists ${$_[0]}{"br"});
}

# Close opened files.
# @param - hash reference with processed options
# @return - none
sub close_files($) {
    close FIN    or warn "Closing input file failed!\n";
    close FOUT   or warn "Closing output file failed!\n";

    if ( exists ${$_[0]}{"fout"} ) {
        close FMT    or warn "Closing format file failed!\n";
    }
}

################################################################################

my $param; # Processed options.

$param = check_opt();
open_files($param);
syntax($param);
close_files($param);

