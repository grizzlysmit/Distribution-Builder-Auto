unit module Gzz::Auto::Grammar:ver<0.0.1>:auth<Francis Grizzly Smit (grizzly@smit.id.au)>;

INIT my $debug-grammar = False;
use Gzz::Auto::Common;
####################################
#                                  #
#  To turn On or Off debugging     #
#  Comment or Uncomment this       #
#  following line.                 #
#                                  #
####################################
#INIT $debug-grammar = True; use Grammar::Debugger;

#use Grammar::Tracer;
INIT "Grammar::Debugger is on".say if $debug-grammar;

sub digits(Str:D $Base --> Regex) {
    my UInt:D $base = $Base.UInt;
    given $base {
        when 2..10 {
            my Str:D $bound = chr(ord('0') + $base - 1);
            my Str:D $pattern = "<[0..{$base}]>";
            return rx/ <$pattern>+ /;
        }
        when 11 { return rx/ [ <[0..9]> || 'a' || 'A' ]+ /; }
        when 12..36 {
            my Str:D $upper = chr(ord('A') + $base - 1);
            my Str:D $lower = chr(ord('a') + $base - 1);
            my Str:D $pattern = "<[0..9] + [a..{$lower}] + [A..{$upper}]>";
            return rx/ <$pattern>+ /;
        }
        default {
            die-handle("Error: base out of range valid values are 2..36 you gave me base == {$base}");
        }
    }
}

sub close-quote(Str:D $quote --> Str:D) {
    my Str:D $result = $quote;
    given $quote {
        when '[' { $result = ']'; }
        when '«' { $result = '»'; }
        when '(' { $result = ')'; }
        when '{' { $result = ']'; }
        when '[' { $result = '}'; }
        when '<' { $result = '>'; }
        default  { $result = $quote; }
    }
    set-opening-quote($quote);
    set-closing-quote($result);
    return $result;
}

sub mk-regex(Str:D $close-quote --> Regex) {
    my Str:D $pattern = qq[ '{$close-quote}' ];
    return rx/ <$pattern> /;
}

sub mkbody-regex(Str:D $quote --> Regex) {
    my Str:D $pattern = qq« [ <-[$quote]>+ [ [ [ '\\\\' ]* \\ <[$quote]> ]+ <-[$quote]>+ ]* ]? »;
    return rx/ <$pattern> /;
}

sub apply-modifiers(%obj, @modifiers --> Any) {
    given %obj<type-spec> {
    }
    # TODO : fill this in #
}

sub apply-subscripts(%obj, @subscripts --> Any) {
    given %obj<value> {
        when Array { }
        when Hash  { }
        when Positional  { }
        when Associative  { }
        default    {
            die-handle("Error: cannot apply subscripts to scalars");
        }
    }
}

grammar ExprBase is export {
    token expr             { ^ [ <obj> <modifiers>? ] $ }
    token obj              {   [ [ <leadin> <identifier> || <value> ] <subscripts>? ] }
    token leadin           {   [ <sigil> <twigil>? ] }
    token sigil            { [ '$' || '@' || '%' || '&' ] }
    token twigil           { [ '*' || '?' ] }
    token subscripts       { [ <subscript>+ ] }
    token subscript        { [ <sub-array> || <sub-hash> ] }
    token sub-array        { [ '[' <ind-number> ']' ] }
    token ind-number       { [ <int-lit> || <expr> ] }
    token sub-hash         { [ '<' <sub-angle> '>' || '«' <sub-dbbl-angle> '»' ] }
    token sub-angle        { [ <string-lit> || <expr> ] }
    token sub-dbbl-angle   { [ <string-lit> || <expr> ] }
    token modifiers        { [ [ <modifiers-dots> || <modifier-colon> ] ] } 
    token modifiers-dots   { [ <modifiers-closed> <modifier-open> || <modifiers-closed> || <modifier-open> ] } 
    token modifiers-closed { [ <modifier-closed>+ ] } 
    token modifier-closed  { [ [ '.' ] <identifier> <params-brackets>? ] } 
    token modifier-open    { [ [ '.' ] <identifier> <params-colon> ] } 
    token modifier-colon   { [ [ ':' ] <identifier> ] } 
    token identifier       { [ \w+ [ [ '-' || '::' ] \w+ ]* ] }
    token params-brackets  { [ '(' \s* <parameters>? ')' ] }
    token params-colon     { [ ':' \s+ <parameters> <?before [ ';' || $ ] > ] }
    token parameters       { [ <parameter> <more-parameters> ] }
    token more-parameters  { [ [ ',' \s* <parameter> \s* ]+ ] }
    token parameter        { [ <parameter-pos> || <optional> ] }
    token parameter-pos    { [ <expr> ] }
    token optional         { [ <colon-opt> || <colon-variable> || <fat-comma-form> || <identifier-param> ] }
    token colon-opt        { [ ':' <bang>? <identifier> ] }
    token colon-variable   { [ ':' <bang>? <variable> ] }
    token bang             { [ '!' ] }
    token fat-comma-form   { [ <identifier> \s* '=>' \s* <expr> ] }
    token variable         { [ <sigil> [ <twigil> ]? <identifier> ] }
    token identifier-param { [ ':' <identifier> '(' <expr> ')' ] }
    token value            { [ <string-lit> || <int-lit> || <num-lit> || <rat-lit> || <complex-lit> || <path-lit> || <allomorph-lit> ] }
    token allomorph-lit    { [ '<' <int-lit> '>' || '<' <num-lit> '>' || '<' <rat-lit> '>' || '<' <complex-lit> '>' ] }
    token string-lit       { [ <dbl-str-lit> || <sngl-str-lit> || <str-q-lit> || <str-qq-lit> || <str-null> ] }
    token dbl-str-lit      { [ '"' [ <-[\"]>+ [ [ '\\\\' ]* [ '\\"' ]+ <-[\"]>+ ]* ]? '"' ] }
    token sngl-str-lit     { [ '\'' [ <-[\']>+ [ [ '\\\\' ]* [ '\\\'' ]+ <-[\']>+ ]* ]? '\'' ] }
    token str-q-lit        { [ 'q'  ( <-[ 0..9 a..z A..Z + \- _ \* ]> ) <{mkbody-regex(close-quote($0))}> <{mk-regex(close-quote($0))}> ] }
    token str-qq-lit       { [ 'qq' ( <-[ 0..9 a..z A..Z + \- _ \* ]> ) <{mkbody-regex(close-quote($0))}> <{mk-regex(close-quote($0))}> ] }
    token str-null         { [ 'Str' ] }
    token int-lit          { [ <dec-lit> || <oct-lit> || <hex-lit> || <bin-lit> || <adverbial-lit> || <int-null> ] }
    token dec-lit          { [ [ '-' || '+' || '0d' ]? \d+ [ '_' \d+ ]* ] }
    token oct-lit          { [ [ '0o' ] <[0..7]>+ [ '_' <[0..7]>+ ]* ] }
    token hex-lit          { [ [ '0x' || '0X' ] <xdigit>+ [ '_' <xdigit>+ ]* ] }
    token bin-lit          { [ [ '0b' ] <[0..1]>+ [ '_' <[0..1]>+ ]* ] }
    token adverbial-lit    { [ ':' ( \d+ [ '_' \d+ ]* ) '<' <{digits($0)}> '>' ] }
    token int-null         { [ 'Int' ] }
    token num-lit          { [ [ <mantissa> <num-e> <exponent> ] || <num-null> ] }
    token num-e            { [ 'e' || 'E' ] }
    token mantissa         { [ [ '-' || '+' ]? \d+ [ '.' \d+ ]?  ] }
    token exponent         { [ [ '-' || '+' ]? \d+ ] }
    token num-null         { [ 'Num' ] }
    token rat-lit          { [ <Rat-lit> || <rat-null> ] }
    token Rat-lit          { [ [ '-' || '+' ]? [ \d+ '.' \d+ || \d+ '/' \d+ ] ] }
    token rat-null         { [ 'Rat' ] }
    token path-lit         { [ <path-lit-d> || <path-lit-new> || <path-null> ] }
    token path-lit-d       { [ <string-lit> '.IO' ] }
    token path-lit-new     { [ 'IO::Path.new(' \s* <string-lit> \s* ')' ] }
    token path-null        { [ 'IO::Path' ] }
    token complex-lit      { [ <complx-lit> || <comp-lit> || <cmplex-null> ] }
    token complx-lit       { [ <real-lit>  <imag-lit> 'i' ] }
    token comp-lit         { [ 'Complex.new(' \s* <real> \s* ',' \s* <imag> \s* ')' ] }
    token real             { [ <int-lit> || <rat-lit> || <num-lit> ] }
    token imag             { [ <int-lit> || <rat-lit> || <num-lit> ] }
    token real-lit         { [ [ '+' || '-' ]? \d+ [ '_' \d+ ]* [ '.' \d+ [ '_' \d+ ]* ]? [ [ 'e' || 'E' ] [ '+' || '-' ]? \d+ [ '_' \d+ ]* ]? ] }
    token imag-lit         { [ [ '-' || '+' ]  \d+ [ '_' \d+ ]* [ '.' \d+ [ '_' \d+ ]* ]? [ [ 'e' || 'E' ] [ '-' || '+' ]? \d+ [ '_' \d+ ]* ]? ] }
    token cmplex-null      { [ 'Complex' ] }
} # grammar ExprBase is export #

role ExprBaseActions is export {
    method mantissa($/) {
        my $mantissa = ~$/;
        my %arg1 = name => '$mantissa', value => $mantissa, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $mantissa;
    }
    method num-e($/) {
        my $num-e = ~$/;
        my %arg1 = name => '$num-e', value => $num-e, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $num-e;
    }
    method exponent($/) {
        my $exponent = ~$/;
        my %arg1 = name => '$exponent', value => $exponent, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $exponent;
    }
    method num-null($/) {
        my $num-null = ~$/;
        if $num-null eq 'Num' {
            $num-null = Num;
        } else {
            die-handle("$?FILE\[$?LINE\] weird how did we get here $num-null is a strange value for a Num.");
        }
        my %arg1 = name => '$num-null', value => $num-null, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $num-null;
    }
    method num-lit($/) {
        my $num-lit = ($/<mantissa>.made ~ $/<num-e>.made ~ $/<exponent>.made).Num;
        my %arg1 = name => '$num-lit', value => $num-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $num-lit;
    }
    method real($/) {
        my $real;
        if $/<int-lit> {
            $real = $/<int-lit>.made;
        } elsif $/<rat-lit> {
            $real = $/< rat-lit>.made;
        } elsif $/<num-lit> {
            $real = $/<num-lit>.made;
        }
        my %arg1 = name => '$real', value => $real, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $real;
    }
    method imag($/) {
        my $imag;
        if $/<int-lit> {
            $imag = $/<int-lit>.made;
        } elsif $/<rat-lit> {
            $imag = $/< rat-lit>.made;
        } elsif $/<num-lit> {
            $imag = $/<num-lit>.made;
        }
        my %arg1 = name => '$imag', value => $imag, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $imag;
    }
    method comp-lit($/) {
        my $comp-lit = Complex.new($/<real>.made, $/<imag>.made);
        my %arg1 = name => '$comp-lit', value => $comp-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $comp-lit;
    }
    method real-lit($/) {
        my $real-lit = (~$/).Num;
        my %arg1 = name => '$real-lit', value => $real-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $real-lit;
    }
    method imag-lit($/) {
        my $imag-lit = ~$/;
        $imag-lit ~~ s/ 'i' $ //;
        $imag-lit = $imag-lit.Num if $imag-lit ne 'Num';
        my %arg1 = name => '$imag-lit', value => $imag-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $imag-lit;
    }
    method complx-lit($/) {
        my $complx-lit;
        my $real = $/<real-lit>.made;
        my $imag = $/<imag-lit>.made;
        with $real {
            with $imag {
                $complx-lit = Complex.new($real, $imag);
            } else {
                $complx-lit = Complex.new($real, 0);
            }
        } else {
            with $imag {
                $complx-lit = Complex.new(0, $imag);
            } else {
                $complx-lit = Complex;
            }
        }
        my %arg1 = name => '$real', value => $real, place => "$?FILE\[$?LINE\]: ";
        my %arg2 = name => '$imag', value => $imag, place => "$?FILE\[$?LINE\]: ";
        my %arg3 = name => '$complx-lit', value => $complx-lit, place => "$?FILE\[$?LINE\]: ";
        my @args =  %arg1, %arg2, %arg3;
        dd-handle(|@args) if $debug-grammar;
        make $complx-lit;
    } # method complx-lit($/) #
    method cmplex-null($/) {
        my $cmplex-null = ~$/;
        if $cmplex-null eq 'Complex' {
            $cmplex-null = Complex;
        } else {
            die-handle("$?FILE\[$?LINE\] weird how did we get here $cmplex-null is a strange value for a complex numbber.");
        }
        my %arg1 = name => '$cmplex-null', value => $cmplex-null, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $cmplex-null;
    }
    method complex-lit($/) {
        my $complex-lit;
        if $/<comp-lit> {
            $complex-lit = $/<comp-lit>.made;
        } elsif $/<complx-lit> {
            $complex-lit = $/<complx-lit>.made;
        } elsif $/<cmplex-null> {
            $complex-lit = $/<cmplex-null>.made;
        }
        my %arg1 = name => '$complex-lit', value => $complex-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $complex-lit;
    }
    method Rat-lit($/) {
        my $Rat-lit = (~$/).Rat;
        my %arg1 = name => '$Rat-lit', value => $Rat-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $Rat-lit;
    }
    method rat-null($/) {
        my $rat-null = ~$/;
        if $rat-null eq 'Rat' {
            $rat-null = Rat;
        } else {
            die-handle("$?FILE\[$?LINE\] weird how did we get here $rat-null is a strange value for a Rat.");
        }
        my %arg1 = name => '$rat-null', value => $rat-null, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $rat-null;
    }
    method rat-lit($/) {
        my $rat-lit;
        if $/<Rat-lit> {
            $rat-lit = $/<Rat-lit>.made;
        } elsif $/<rat-null> {
            $rat-lit = $/<rat-null>.made;
        }
        my %arg1 = name => '$rat-lit', value => $rat-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $rat-lit;
    }
    method dec-lit($/) {
        my $dec-lit = (~$/).Int;
        my %arg1 = name => '$dec-lit', value => $dec-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $dec-lit;
    }
    method oct-lit($/) {
        my $oct-lit = (~$/).Int;
        my %arg1 = name => '$oct-lit', value => $oct-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $oct-lit;
    }
    method hex-lit($/) {
        my $hex-lit = (~$/).Int;
        my %arg1 = name => '$hex-lit', value => $hex-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $hex-lit;
    }
    method bin-lit($/) {
        my $bin-lit = (~$/).Int;
        my %arg1 = name => '$bin-lit', value => $bin-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $bin-lit;
    }
    method adverbial-lit($/) {
        my $adverbial-lit = (~$/).Int;
        my %arg1 = name => '$adverbial-lit', value => $adverbial-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $adverbial-lit;
    }
    method int-null($/) {
        my $int-null;
        if $int-null eq 'Int' {
            $int-null = Int;
        } else {
            die-handle("$?FILE\[$?LINE\] weird how did we get here $int-null is a strange value for a Int.");
        }
        my %arg1 = name => '$int-null', value => $int-null, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $int-null;
    }
    method int-lit($/) {
        my %int-lit;
        if $/<dec-lit> {
            %int-lit = value => $/<dec-lit>.made,       type-spec => 'Int', null => False, definedness => '', var => literal, perms => "r", name => "";
        } elsif $/<oct-lit> {
            %int-lit = value => $/<oct-lit>.made,       type-spec => 'Int', null => False, definedness => '', var => literal, perms => "r", name => "";
        } elsif $/<hex-lit> {
            %int-lit = value => $/<hex-lit>.made,       type-spec => 'Int', null => False, definedness => '', var => literal, perms => "r", name => "";
        } elsif $/<bin-lit> {
            %int-lit = value => $/<bin-lit>.made,       type-spec => 'Int', null => False, definedness => '', var => literal, perms => "r", name => "";
        } elsif $/<adverbial-lit> {
            %int-lit = value => $/<adverbial-lit>.made, type-spec => 'Int', null => False, definedness => '', var => literal, perms => "r", name => "";
        } elsif $/<int-null> {
            %int-lit = value => $/<int-null>.made,      type-spec => 'Int', null => True,  definedness => '', var => literal, perms => "r", name => "";
        }
        my %arg1 = name => '%int-lit', value => %int-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %int-lit;
    } # method int-lit($/) #
    method allomorph-lit($/) {
        my %allomorph-lit;
        if $/<int-lit> {
            my %spec    = $/<int-lit>.made;
            my $int-lit = %spec<value>;
            with $int-lit {
                %allomorph-lit = value => <$int-lit>, type-spec => 'IntStr', raku-class => True, null => False, definedness => '', var => literal, perms => "r", name => "";
            } else {
                %allomorph-lit = value => IntStr,     type-spec => 'IntStr', raku-class => True, null => True,  definedness => '', var => literal, perms => "r", name => "";
            }
        } elsif $/<num-lit> {
            my $num-lit = $/<num-lit>.made;
            with $num-lit {
                %allomorph-lit = value => <$num-lit>, type-spec => 'NumStr', raku-class => True, null => False, definedness => '', var => literal, perms => "r", name => "";
            } else {
                %allomorph-lit = value => NumStr,     type-spec => 'NumStr', raku-class => True, null => True,  definedness => '', var => literal, perms => "r", name => "";
            }
        } elsif $/<ral-lit> {
            my $rat-lit = $/<ral-lit>.made;
            with $rat-lit {
                %allomorph-lit = value => <$ral-lit>, type-spec => 'RatStr', raku-class => True, null => False, definedness => '', var => literal, perms => "r", name => "";
            } else {
                %allomorph-lit = value => RatStr,     type-spec => 'RatStr', raku-class => True, null => True,  definedness => '', var => literal, perms => "r", name => "";
            }
        } elsif $<complex-lit> {
            my $complex-lit = $/<complex-lit>.made;
            with $complex-lit {
                %allomorph-lit = value => <$complex-lit>, type-spec => "ComplexStr", raku-class => True, null => False, definedness => "", var => literal, perms => "r", name => "";
            } else {
                %allomorph-lit = value => ComplexStr,     type-spec => "ComplexStr", raku-class => True, null => True,  definedness => "", var => literal, perms => "r", name => "";
            }
        }
        my %arg1 = name => '%allomorph-lit', value => %allomorph-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %allomorph-lit;
    } # method allomorph-lit($/) #
    method dbl-str-lit($/) {
        my $dbl-str-lit = ~$/;
        $dbl-str-lit ~~ s/ ^ '"' //;
        $dbl-str-lit ~~ s/ '"' $ //;
        my Str:D $closing-quote = '"';
        my Str:D $opening-quote = '"';
        $dbl-str-lit = parse-string($dbl-str-lit, :$opening-quote, :$closing-quote, :interpretable);
        my %arg1 = name => '$opening-quote', value => $opening-quote, place => "$?FILE\[$?LINE\]: ";
        my %arg2 = name => '$closing-quote', value => $closing-quote, place => "$?FILE\[$?LINE\]: ";
        my %arg3 = name => '$dbl-str-lit', value => $dbl-str-lit, place => "$?FILE\[$?LINE\]: ";
        my @args =  %arg1, %arg2, %arg3;
        dd-handle(|@args) if $debug-grammar;
        make $dbl-str-lit;
    }
    method sngl-str-lit($/) {
        my $sngl-str-lit = ~$/;
        $sngl-str-lit ~~ s/ ^ "'" //;
        $sngl-str-lit ~~ s/ "'" $ //;
        my Str:D $closing-quote = "'";
        my Str:D $opening-quote = "'";
        $sngl-str-lit = parse-string($sngl-str-lit, :$opening-quote, :$closing-quote, :!interpretable);
        my %arg1 = name => '$opening-quote', value => $opening-quote, place => "$?FILE\[$?LINE\]: ";
        my %arg2 = name => '$closing-quote', value => $closing-quote, place => "$?FILE\[$?LINE\]: ";
        my %arg3 = name => '$sngl-str-lit', value => $sngl-str-lit, place => "$?FILE\[$?LINE\]: ";
        my @args =  %arg1, %arg2, %arg3;
        dd-handle(|@args) if $debug-grammar;
        make $sngl-str-lit;
    }
    method str-q-lit($/) {
        my $str-q-lit = ~$/;
        die-handle("$?FILE\[$?LINE\] Error: q string form must start with 'q' {$str-q-lit.substr(0, 1)} found???") if $str-q-lit.substr(0, 1) eq 'q';
        $str-q-lit = $str-q-lit.substr(1); # trim off the 'q' #
        my Str:D $opening-quote = $str-q-lit.substr(0, 1);
        my Str:D $closing-quote = close-quote($opening-quote);
        die-handle("$?FILE\[$?LINE\] Error: wrong closing char expected $closing-quote but got {$str-q-lit.substr(*-1)}???") if $str-q-lit.substr(*-1) ne $closing-quote;
        $str-q-lit = $str-q-lit.substr(1, *-1); # trim off the 'opening and closing quote chars' #
        $str-q-lit = parse-string($str-q-lit, :$opening-quote, :$closing-quote, :!interpretable);
        my %arg1 = name => '$opening-quote', value => $opening-quote, place => "$?FILE\[$?LINE\]: ";
        my %arg2 = name => '$closing-quote', value => $closing-quote, place => "$?FILE\[$?LINE\]: ";
        my %arg3 = name => '$str-q-lit', value => $str-q-lit, place => "$?FILE\[$?LINE\]: ";
        my @args =  %arg1, %arg2, %arg3;
        dd-handle(|@args) if $debug-grammar;
        make $str-q-lit;
    }
    method str-qq-lit($/) {
        my $str-qq-lit = ~$/;
        die-handle("$?FILE\[$?LINE\] Error: qq string form must start with 'qq' {$str-qq-lit.substr(0, 2)} found") if $str-qq-lit.substr(0, 2) eq 'qq';
        $str-qq-lit = $str-qq-lit.substr(2); # trim off the 'qq' #
        my Str:D $opening-quote = $str-qq-lit.substr(0, 1);
        my Str:D $closing-quote = close-quote($opening-quote);
        die-handle("$?FILE\[$?LINE\] Error: wrong closing char expected $closing-quote but got {$str-qq-lit.substr(*-1)}???") if $str-qq-lit.substr(*-1) ne $closing-quote;
        $str-qq-lit = $str-qq-lit.substr(1, *-1); # trim off the 'opening and closing quote chars' #
        $str-qq-lit = parse-string($str-qq-lit, :$opening-quote, :$closing-quote, :interpretable);
        my %arg1 = name => '$opening-quote', value => $opening-quote, place => "$?FILE\[$?LINE\]: ";
        my %arg2 = name => '$closing-quote', value => $closing-quote, place => "$?FILE\[$?LINE\]: ";
        my %arg3 = name => '$str-qq-lit', value => $str-qq-lit, place => "$?FILE\[$?LINE\]: ";
        my @args =  %arg1, %arg2, %arg3;
        dd-handle(|@args) if $debug-grammar;
        make $str-qq-lit;
    }
    method str-null($/) {
        my $str-null = ~$/;
        if $str-null ne 'Str' {
            die-handle("$?FILE\[$?LINE\] Error: this is imposible howed we get here, what is this {$str-null}???");
        } else {
            $str-null = Str;
        }
        my %arg1 = name => '$str-null', value => $str-null, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $str-null;
    }
    method string-lit($/) {
        my $string-lit;
        if $/<dbl-str-lit> {
            $string-lit = $/<dbl-str-lit>.made;
        } elsif $/<sngl-str-lit> {
            $string-lit = $/<sngl-str-lit>.made;
        } elsif $/<str-q-lit> {
            $string-lit = $/<str-q-lit>.made;
        } elsif $/<str-qq-lit> {
            $string-lit = $/<str-qq-lit>.made;
        } elsif $/<str-null> {
            $string-lit = $/<str-null>.made;
        }
        my %arg1 = name => '$string-lit', value => $string-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $string-lit;
    }
    method path-lit-d($/) {
        my $path-lit-d = ~$/<str-lit>.made.IO;
        my %arg1 = name => '$path-lit-d', value => $path-lit-d, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $path-lit-d;
    }
    method path-lit-new($/) {
        my $path-lit-new = IO::Path.new(~$/<str-lit>.made);
        my %arg1 = name => '$path-lit-new', value => $path-lit-new, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $path-lit-new;
    }
    method path-null($/) {
        my $path-null = ~$/;
        if $path-null ne 'IO::Path' {
            die-handle("$?FILE\[$?LINE\] Error: this is imposible howed we get here, what is this {$path-null}???");
        } else {
            $path-null = IO::Path;
        }
        my %arg1 = name => '$path-null', value => $path-null, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $path-null;
    }
    method path-lit($/) {
        my $path-lit;
        if $/<path-lit-d> {
            my $path-lit = $/<path-lit-d>.made;
        } elsif $/<path-lit-new> {
            my $path-lit = $/<path-lit-new>.made;
        } elsif $/<path-null> {
            my $path-lit = $/<path-null>.made;
        }
        my %arg1 = name => '$path-lit', value => $path-lit, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $path-lit;
    }
    method value($/) {
        my %value;
        if $/<string-lit> {
            my $string-lit = $/<string-lit>.made;
            with $string-lit {
                %value = value => $string-lit, type-spec => 'Str', raku-class => True, null => False, definedness => ', var => literal, perms => "r", name => ""';
            } else {
                %value = value => Str,         type-spec => 'Str', raku-class => True, null => True,  definedness => '', var => literal, perms => "r", name => "";
            }
        } elsif $/<path-lit> {
            my $path-lit = $/<path-lit>.made;
            with $path-lit {
                %value = value => $path-lit,    type-spec => 'Int', raku-class => True, null => False, definedness => '', var => literal, perms => "r", name => "";
            } else {
                %value = value => Int,         type-spec => 'Int', raku-class => True, null => True,  definedness => '', var => literal, perms => "r", name => "";
            }
        } elsif $/<int-lit> {
            my %value  = $/<int-lit>.made;
        } elsif $/<num-lit> {
            my $num-lit = $/<num-lit>.made;
            with $num-lit {
                %value = value => $num-lit,    type-spec => 'Num', raku-class => True, null => False, definedness => '', var => literal, perms => "r", name => "";
            } else {
                %value = value => Num,         type-spec => 'Num', raku-class => True, null => True,  definedness => '', var => literal, perms => "r", name => "";
            }
        } elsif $/<ral-lit> {
            my $rat-lit = $/<rat-lit>.made;
            with $rat-lit {
                %value = value => $rat-lit,    type-spec => 'Rat', raku-class => True, null => False, definedness => '', var => literal, perms => "r", name => "";
            } else {
                %value = value => Rat,         type-spec => 'Rat', raku-class => True, null => True,  definedness => '', var => literal, perms => "r", name => "";
            }
        } elsif $/<complex-lit> {
            my $complex-lit = $/<complex-lit>.made;
            with $complex-lit {
                %value = value => $complex-lit, type-spec => "Complex", raku-class => True, null => False, definedness => "", var => literal, perms => "r", name => "";
            } else {
                %value = value => Complex,     type-spec => "Complex", raku-class => True, null => True,  definedness => "", var => literal, perms => "r", name => "";
            }
        } elsif $/<allomorph-lit> {
            %value = $/<allomorph-lit>.made;
        }
        my %arg1 = name => '%value', value => %value, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %value;
    } # method value($/) #
    method bang($/) {
        my Bool:D $bang = ~$/ eq '!';
        my %arg1 = name => '$bang', value => $bang, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $bang;
    }
    method identifier($/) {
        my $identifier = ~$/;
        my %arg1 = name => '$identifier', value => $identifier, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $identifier;
    }
    method colon-opt($/) {
        my %colon-opt;
        my $identifier = '$' ~ $/<identifier>.made;
        %colon-opt = value => $identifier, type-spec => 'Bool', raku-class => True, null => False, definedness => "", var => parameter, perms => "r", name => "$identifier";
        if $/<bang> {
            %colon-opt<bang> = $/<bang>.made;
        }
        my %arg1 = name => '%colon-opt', value => %colon-opt, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %colon-opt;
    }
    method sigil($/) {
        my $sigil = ~$/;
        my %arg1 = name => '$sigil', value => $sigil, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $sigil;
    }
    method twigil($/) {
        my $twigil = ~$/;
        my %arg1 = name => '$twigil', value => $twigil, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $twigil;
    }
    method variable($/) {
        my $variable = $/<sigil>.made;
        if $/<twigil> {
            $variable ~= $/<twigil>.made;
        }
        $variable ~= $/<identifier>.made;
        my %arg1 = name => '$variable', value => $variable, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $variable;
    }
    method colon-variable($/) {
        my %colon-variable;
        my $variable = $/<variable>.made;
        my %spec       = resolve-symbol($variable);
        my $val = %spec<value>;
        %colon-variable = value => $val, type-spec => 'YetTobeResolved', raku-class => Any, null => False, definedness => "", var => parameter, perms => "r", name => "$variable";
        %colon-variable<variable-type> = $variable.substr(0, 1);
        if $/<bang> {
            %colon-variable<bang>  = $/<bang>.made;
        }
        my %arg1 = name => '%colon-variable', value => %colon-variable, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %colon-variable;
    }
    method identifier-param($/) {
        my %identifier-param;
        my $identifier = $/<identifier>.made;
        my %expr = $/<expr>.made;
        %identifier-param  = value => %expr, type-spec => 'YetTobeResolved', raku-class => Any, null => False, definedness => "", var => parameter, perms => "r", name => "$identifier";
        %identifier-param<variable-type> = 'YetTobeResolved';
        my %arg1 = name => '%identifier-param', value => %identifier-param, place => "$?FILE\[$?LINE\]: ";
        my %arg2 = name => '%identifier-param', value => %identifier-param, place => "$?FILE\[$?LINE\]: ";
        my %arg3 = name => '%identifier-param', value => %identifier-param, place => "$?FILE\[$?LINE\]: ";
        my @args = %arg1, %arg2, %arg3;
        dd-handle(|@args) if $debug-grammar;
        make %identifier-param;
    }
    method fat-comma-form($/) {
        my %fat-comma-form;
        my $identifier = '$' ~ $/<identifier>.made;
        my %spec       = $/<expr>.made;
        my $type-spec  = %spec<type-spec>;
        %fat-comma-form = value => %spec<value>, type-spec => $type-spec, null => False, definedness => "D", var => parameter, perms => "r", name => "$identifier";
        my %arg1 = name => '%fat-comma-form', value => %fat-comma-form, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %fat-comma-form;
    }
    method optional($/) {
        my %optional;
        if $/<colon-opt> {
            %optional = $/<colon-opt>.made;
        } elsif $/<dollar-colon> {
            %optional = $/<dollar-colon>.made;
        } elsif $/<fat-comma-form> {
            %optional = $/<fat-comma-form>.made;
        }
        my %arg1 = name => '%optional', value => %optional, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %optional;
    }
    method parameter($/) {
        my %parameter;
        if $/<parameter-pos> {
            %parameter = $/<parameter-pos>.made;
        } elsif $/<optional> {
            %parameter = $/<optional>.made;
        }
        my %arg1 = name => '%parameter', value => %parameter, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %parameter;
    }
    method parameter-pos($/) {
        my %parameter-pos = $/<obj>.made;
        if $/<modifiers> {
            my @modifiers = $/<modifiers>.made;
            %parameter-pos = apply-modifiers(%parameter-pos, @modifiers);
        }
        my %arg1 = name => '%parameter-pos', value => %parameter-pos, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %parameter-pos;
    }
    method params-colon($/) {
        my @params-colon = $/<parameters>.made;
        my %arg1 = name => '@params-colon', value => @params-colon, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make @params-colon;
    }
    method params-brackets($/) {
        my @params-brackets = $/<parameters>.made;
        my %arg1 = name => '@params-brackets', value => @params-brackets, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make @params-brackets;
    }
    method leadin($/) {
        my $leadin = $/<sigil>.made;
        if $/<twigil> {
            $leadin ~= $<twigil>.made;
        }
        my %arg1 = name => '$leadin', value => $leadin, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make $leadin;
    }
    method ind-number($/) {
        my %ind-number;
        if $/<int-lit> {
            %ind-number = $/<int-lit>.made;
        } elsif $/<expr> {
            %ind-number = $/< expr>.made;
        }
        make %ind-number;
    }
    method sub-array($/) {
       my %sub-array = $/<ind-number>.made;
        my %arg1 = name => '%sub-array', value => %sub-array, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
       make %sub-array; 
    }
    method sub-angle($/) {
        my %sub-angle;
        if $/<string-lit> {
            %sub-angle = $/<string-lit>;
        } elsif $/<expr> {
            %sub-angle = $/<expr>.made;
        }
        my %arg1 = name => '%sub-angle', value => %sub-angle, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %sub-angle;
    }
    method sub-dbbl-angle($/) {
        my %sub-dbbl-angle;
        if $/<string-lit> {
            %sub-dbbl-angle = $/<string-lit>;
        } elsif $/<expr> {
            %sub-dbbl-angle = $/<expr>.made;
        }
        my %arg1 = name => '%sub-dbbl-angle', value => %sub-dbbl-angle, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %sub-dbbl-angle;
    }
    method sub-hash($/) {
        my %sub-hash;
        if $/<string-lit> {
            %sub-hash = $/<sub-angle>.made;
        } elsif $/<expr> {
            %sub-hash = $/<sub-angle>.made;
        }
        my %arg1 = name => '%sub-hash', value => %sub-hash, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %sub-hash;
    }
    method subscript($/) {
        my %subscript;
        if $/<sub-array> {
            %subscript = $/<sub-array>.made;
        } elsif $/<sub-hash> {
            %subscript = $/<sub-hash>.made;
        }
        my %arg1 = name => '%subscript', value => %subscript, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %subscript;
    }
    method subscripts($/) {
        my @subscripts = $/<subscript>».made;
        my %arg1 = name => '@subscripts', value => @subscripts, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make @subscripts;
    }
    method obj($/) {
        my %obj;
        if $/<leadin>  && $/<identifier> {
            my $var = $/<leadin>.made ~ $/<identifier>.made;
            %obj    = resolve-symbol($var);
        } elsif $/<value> {
            %obj    = $/<value>.made;
        }
        if $/<subscripts>  {
            my @subscripts = $/<subscript>».made;
            %obj = apply-subscripts(%obj, @subscripts);
        }
        my %arg1 = name => '%obj', value => %obj, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %obj;
    }
    method modifier-colon($/) {
        my %modifier-colon = applicator => ':', modifier => $/<identifier>.made;
        my %arg1 = name => '%modifier-colon', value => %modifier-colon, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %modifier-colon;
    }
    method modifier-closed($/) {
        my %modifier-closed;
        my $identifier = $/<identifier>.made;
        if $/<params-brackets> {
            my %params = identifier => $identifier, params => $<params-brackets>.made;
            %modifier-closed = applicator => '.', modifier => %params;
        } else {
            my %modifier = identifier => $identifier;
            %modifier-closed = applicator => '.', modifier => %modifier;
        }
        my %arg1 = name => '$identifier', value => $identifier, place => "$?FILE\[$?LINE\]: ";
        my %arg2 = name => '%modifier-closed', value => %modifier-closed, place => "$?FILE\[$?LINE\]: ";
        my @args = %arg1, %arg2;
        dd-handle(|@args) if $debug-grammar;
        make %modifier-closed;
    }
    method modifier-open($/) {
        my %modifier-open;
        my $identifier = $/<identifier>.made;
        my %params = identifier => $identifier, params => $<params-colon>.made;
        %modifier-open = applicator => '.', modifier => %params;
        my %arg1 = name => '$identifier', value => $identifier, place => "$?FILE\[$?LINE\]: ";
        my %arg2 = name => '%params', value => $params, place => "$?FILE\[$?LINE\]: ";
        my %arg3 = name => '%modifier-open', value => %modifier-open, place => "$?FILE\[$?LINE\]: ";
        my @args = %arg1, %arg2, %arg3;
        dd-handle(|@args) if $debug-grammar;
        make %modifier-open;
    }
    method modifiers-closed($/) {
        my @modifiers-closed = $/<modifier-closed>».made;
        my %arg1 = name => '@modifiers-closed', value => @modifiers-closed, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make @modifiers-closed;
    }
    method modifiers-dots($/) {
        my @modifiers-dots;
        if $/<modifiers-closed> && $/<modifier-open> {
            @modifiers-dots = $/<modifiers-closed>.made;
            @modifiers-dots.push: $/<modifier-open>.made;
        } elsif $/<modifiers-closed> {
            @modifiers-dots = $/<modifiers-closed>.made;
        } elsif $/<modifier-open> {
            @modifiers-dots.push: $/<modifier-open>.made;
        }
        my %arg1 = name => '@modifiers-dots', value => @modifiers-dots, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
       make @modifiers-dots; 
    }
    method modifiers($/) {
        my @modifiers;
        if $/<modifier-dots> {
            @modifiers = $/<modifier-dots>.made;
        } elsif $/<modifier-colon> {
            @modifiers.push: $/<modifier-colon>.made;
        }
        my %arg1 = name => '@modifiers', value => @modifiers, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make @modifiers;
    }
    method expr($/) {
        my %expr = $/<obj>.made;
        if $/<modifiers> {
            my @modifiers = $/<modifiers>.made;
            %expr = apply-modifiers(%expr, @modifiers);
        }
        my %arg1 = name => '%expr', value => %expr, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        make %expr;
    }
} # role ExprBaseActions is export #

grammar Expr is ExprBase is export {
    token TOP  { [ ^ <expr> $ ] }
}

class  ExprAction does ExprBaseActions is export {
    method TOP($made) {
        my %TOP = $made<expr>.made;
        my %arg1 = name => '%TOP', value => %TOP, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        $made.make: %TOP;
    }
}

grammar Modifer is ExprBase is export {
    token TOP { [ ^ <modifiers> $ ] }
}

class ModiferAction does ExprBaseActions is export {
    method TOP($made) {
        my @modifiers = $made<modifiers>.made;
        my %arg1 = name => '@modifiers', value => @modifiers, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args) if $debug-grammar;
        $made.make: @modifiers;
    }
}

sub eval-expr(Str:D $expr is copy, Bool :$debug = get-debug() --> Str:D) is export {
    return $expr;
    # TODO: finish this #
    my Str:D $result = '';
    my $current;
    if $expr ~~ rx/ ^ $<id> = [ '$' [ $twigil ]? $id-pattern ] $<tail> = [ .* ] $ / {
        my Str:D $identifier = ~$<id>;
        my %spec = resolve-symbol($identifier);
        if %spec«type-spec» eq 'Unknown' {
            $result = '';
        } else {
            if %spec«null» {
                $result = null-value(%spec«type-spec», :$debug) if %spec«null»;
                die-handle("$?FILE\[$?LINE\] Error $identifier resolves to null value.");
            } else {
                $current = %spec«value»;
            }
        }
        $expr = ~$<tail> // '';
    }
    while $expr ne '' && $expr ~~ rx/ ^ $<member> =[ [ '.' || ':' ] $id-pattern [ $params ]? ] $<tail> = [ [ [ '.' || ':' ] $id-pattern [ $params ]? ]* ] $ / {
    }
    return $result;
}

sub resolve(Str:D $result is copy, Bool:D :$debug = get-debug() --> Str:D) is export {
    return $result;
    # TODO: finish this using grammar #
    while $result ~~ rx/ $<expr> = [ '{' \s* '$' [ $twigil ]? $id-pattern [ [ '.' || ':' ] $id-pattern [ $params ]? ]* \s* '}' ] / {
        my Str:D $expr = ~$<expr>;
        my $value = eval-expr(unwrap($expr, :get-handle), :$debug);
        $result ~~ s/ <$expr> /$value/;
    }
    $result ~~ s:g/ ('{') '{' /$0/;
    $result ~~ s:g/ ('}') '}' /$0/;
    while $result ~~ rx/ $<var> = [ '$' [ $twigil ]? $id-pattern <wb> ] / {
    }
    return $result;
}

CHECK {
    set-eval-expr-callback(&eval-expr, :verbose);
}
