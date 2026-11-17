use v6.*;
unit module Gzz::Auto::Common:ver<0.0.1>:auth<Francis Grizzly Smit (grizzly@smit.id.au)>;
#use experimental :rakuast;
#use MONKEY;
use JSON::Fast;

constant $home is export = $*HOME;


my @symbol-table;

my Str:D $opening-quote = '"';

my Str:D $closing-quote = '"';

my IO::Handle:D $handle = "/dev/null".IO.open: :append, :mode<rw>, :out-buffer(False); # will be opened to `log' later #

my %meta;

my Bool:D $debug = False;

my Str:D  $log    = '/dev/tyy';

my &eval-expr-callback;

sub set-eval-expr-callback(&callback:(Str:D $expr is copy, Bool :$debug = get-debug() --> Str:D), Bool:D :$verbose = False --> Bool:D) is export {
    without &eval-expr-callback {
        &eval-expr-callback = &callback;
        '&eval-expr-callback is now defined'.say if $verbose;
        return True;
    }
    if &callback === &eval-expr-callback {
        '&eval-expr-callback is already set to that value.'.say if $verbose;
        return False;
    }
    &eval-expr-callback = &callback;
    "callback set".say if $verbose;
    return True with &eval-expr-callback;
    return False;
} # sub set-eval-expr-callback(&callback:(Str:D $expr is copy, Bool :$debug = get-debug() --> Str:D), Bool:D :$verbose = False --> Bool:D) is export  #

sub eval-expr(Str:D $expr is copy, Bool :$debug = get-debug() --> Str:D) {
    without &eval-expr-callback {
        "cannot call callback &eval-expr-callback null value".say if $debug;
        return False;
    }
    "callback &eval-expr-callback called".say if $debug;
    return &eval-expr-callback($expr, :$debug);
}

sub get-debug( --> Bool:D) is export {
    return $debug;
}

sub set-opening-quote(Str:D $quote --> Str:D) is export {
    $opening-quote = $quote;
    return $opening-quote;
}

sub get-opening-quote( --> Str:D) is export {
    return $opening-quote;
}

sub set-closing-quote(Str:D $quote --> Str:D) is export {
    $closing-quote = $quote;
    return $closing-quote;
}

sub get-closing-quote( --> Str:D) is export {
    return $closing-quote;
}

my UInt:D $parse-max = 0;

sub get-parse-max( --> UInt:D) {
    return $parse-max;
}

sub set-parse-max(Int:D $cnt --> UInt:D) {
    $parse-max = $cnt;
    return $parse-max;
}

sub get-handle( --> IO::Handle:D) is export {
    return $handle;
}

enum ErrorAction is export <ignoreError leaveVar throwExcept>;

enum VarType     is export <unkown-var variable system-var frame-var const-var function parameter literal class-def class-not-found>;

#`«««
    some useful regexes 
»»»
constant $type-pattern      is export = rx/ \w+ [ [ '-' || '::' ]? \w+ ]* [ ':D' || ':U' ]? /;
constant $id-pattern        is export = rx/ \w+ [ [ '-' || '::' ]? \w+ ]* /;
constant $qualify-access    is export = rx/ [ [ [ '.' || ':' ] \w+ [ [ '-' ]? \w+ ]* ]* || '[' \s* \d \s* ']' ]* /;
constant $path-pattern      is export = rx/ [ \/? <-[\/]>+ [ \/ <-[\/]>+ ]* \/? ] /;
constant $sigil             is export = rx/ [ '$' || '@' || '%' || '&' ] /;  
constant $param-sigil       is export = rx/ [ '$' || '@' || '%' || '&' || '*@' || '*%' || '\\' || '|' ] /;  # leave the last two unimplemented for now #
constant $twigil            is export = rx/ [ '*' || '?' ] /; # that will do for now #
constant $variable          is export = rx/ $sigil [ $twigil ]? $id-pattern /;
constant $scalar-variable   is export = rx/ '$' [ $twigil ]? $id-pattern /;
constant $hash-variable     is export = rx/ '%' [ $twigil ]? $id-pattern /;
constant $array-variable    is export = rx/ '@' [ $twigil ]? $id-pattern /;
constant $function-variable is export = rx/ [ '&' [ $twigil ]? ]? $id-pattern /;
constant $parameter         is export = rx/ [ [ [ $sigil [ $twigil ]? ]? $id-pattern ] ||
                                               [ [ 'self.']? $id-pattern [ '(' [ \s* [ [ $sigil [ $twigil ]? ]? $id-pattern ] [ \s* ','
                                               \s* [ [ $sigil [ $twigil ]? ]? $id-pattern ] ]* ]? ')' ] ] ] /;
constant $parameters        is export = rx/ [ \s* $parameter [ \s* ',' \s* $parameter ]* ]? \s* /;
constant $params            is export = rx/ [ '(' $parameters ')' || ':' $parameters  <?before ';'> ] /;
constant $real-pattern      is export = rx/ [ [ \d* '.' \d+ [ [ 'e' || 'E' ] [ '-' || '+' ]? \d+ ]? ] || [ \d+ [ '.' \d+ [ [ 'e' || 'E' ] [ '-' || '+' ]? \d+ ]? ]? ] ] /;
constant $numeric-pattern   is export = rx/ [ [ [ '-' || '+' ]? $real-pattern ] || [ [ '-' || '+' ]? $real-pattern [ '-' || '+' ] $real-pattern 'i' ] ||
                                                                                                                        [ [ '-' || '+' ]? $real-pattern  'i' ] ] /;

subset Identifier is export of Str where * ~~ rx/ ^ $id-pattern $ /;

subset Variable is export of Str where * ~~ rx/ ^ $variable $ /;

sub isNumeric(Str:D $val --> Bool:D) {
    #`«««
    unless ($val ~~ rx/ ^ $numeric-pattern $ /).Bool {
        return False;
    }
    #»»»
    #«««
    CATCH {
        when X::Str::Numeric { return .Bool; }
        when X::AdHoc        { return .Bool; }
        default {
            #$handle.say: "{.^name}: {.Str}";
            #.rethrow;
            return .Bool;
        }
    }
    my $tmp  = $val.Numeric;
    return True;
    #»»»
}


sub convert-hash-to-internal-format(%hash is copy --> Hash) is export {
    for %hash.keys -> $key {
        given %hash{$key} {
            when Str {
                if %hash{$key} ~~ rx/ ^ \s* $ / {
                    my Str $val = %hash{$key}.Str;
                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                    my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                    my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                    my @args = %arg1, %arg2, %arg3;
                    dd-handle(|@args);
                    %hash{$key}     = value => $val, type-spec => 'Str', raku-class => True,        null => False, definedness => "D", var => variable, perms => "rw", name => "$key";
                    next;
                }
                die-handle("$?FILE\[$?LINE\] " ~ q<Error: scalar hash should be of the form rx/ ^ '$' [ $twigil ]? $id-pattern $ / >) unless $key ~~ rx/ ^ $variable $ /;
                if isNumeric(%hash{$key}).Bool {
                    given %hash{$key}.Numeric {
                        when Int {
                            $handle.say: "$?FILE\[$?LINE\]";
                            my Int $val = %hash{$key}.Int;
                            my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                            my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                            my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                            my @args = %arg1, %arg2, %arg3;
                            dd-handle(|@args);
                            %hash{$key}     = value => $val, type-spec => 'Int', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                        }
                        when Rat {
                            my Rat $val = %hash{$key}.Rat;
                            my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                            my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                            my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                            my @args = %arg1, %arg2, %arg3;
                            dd-handle(|@args);
                            %hash{$key}     = value => $val, type-spec => 'Rat', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                        }
                        when FatRat {
                            my FatRat $val = %hash{$key}.FatRat;
                            my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                            my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                            my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                            my @args = %arg1, %arg2, %arg3;
                            dd-handle(|@args);
                            %hash{$key}     = value => $val, type-spec => 'FatRat', raku-class => True,     null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                        }
                        when Num {
                            my Num $val = %hash{$key}.Num;
                            my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                            my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                            my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                            my @args = %arg1, %arg2, %arg3;
                            dd-handle(|@args);
                            %hash{$key}     = value => $val, type-spec => 'Num', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                        }
                        when Complex {
                            my Complex $val = %hash{$key}.Complex;
                            my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                            my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                            my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                            my @args = %arg1, %arg2, %arg3;
                            dd-handle(|@args);
                            %hash{$key}     = value => $val, type-spec => 'Complex', raku-class => True,    null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                        }
                        default {
                            my Str $val = %hash{$key}.Str;
                            my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                            my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                            my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                            my @args = %arg1, %arg2, %arg3;
                            dd-handle(|@args);
                            %hash{$key}     = value => $val, type-spec => 'Str', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                        }
                    } # given %hash{$key} #
                } elsif %hash{$key} ~~ rx/ ^ [ '<' $<body> = [ .* ] '>' ] $ / {
                    if isNumeric(~$<body>).Bool {
                        given (~$<body>).Numeric {
                            when Int {
                                my Int $val = (~$<body>).Int;
                                my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                                my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                                my @args = %arg1, %arg2, %arg3;
                                dd-handle(|@args);
                                %hash{$key} =  value => $val, type-spec => 'Int', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                            }
                            when Rat {
                                my Rat $val = (~$<body>).Rat;
                                my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                                my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                                my @args = %arg1, %arg2, %arg3;
                                dd-handle(|@args);
                                %hash{$key} =  value => $val, type-spec => 'Rat', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                            }
                            when Num {
                                my Num $val = (~$<body>).Num;
                                my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                                my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                                my @args = %arg1, %arg2, %arg3;
                                dd-handle(|@args);
                                %hash{$key} =  value => $val, type-spec => 'Num', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                            }
                            when Complex {
                                my Complex $val = (~$<body>).Complex;
                                my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                                my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                                my @args = %arg1, %arg2, %arg3;
                                dd-handle(|@args);
                                %hash{$key} =  value => $val, type-spec => 'Complex', raku-class => True,    null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                            }
                            default {
                                my Str $val = eval-expr((~$<body>).Str);
                                my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                                my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                                my @args = %arg1, %arg2, %arg3;
                                dd-handle(|@args);
                                %hash{$key} =  value => $val, type-spec => 'Str', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                            }
                        } # given %hash{$key} #
                    } else { # if isNumeric(~$<body>).Bool #
                        my Str $val = eval-expr(%hash{$key}.Str);
                        my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                        my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                        my %arg3 = name => "$key", value => $val, place => "$?FILE\[$?LINE\]: ";
                        my @args = %arg1, %arg2, %arg3;
                        dd-handle(|@args);
                        # TODO: finish this #
                        %hash{$key}         =  value => $val, type-spec => 'Str', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                    }
                } else { # if isNumeric(%hash{$key}).Bool ... elsif %hash{$key} ~~ rx/ ^ '<' $<body> = [ .* ] '>' $ / #
                    my Str $val = eval-expr(%hash{$key}.Str);
                    # TODO: finish this #
                    %hash{$key}             =  value => $val, type-spec => 'Str', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
                }
            } # when Str #
            when Int {
                die-handle("$?FILE\[$?LINE\] " ~ q<Error: scalar hash should be of the form rx/ ^ '$' [ $twigil ]? $id-pattern $ / >) unless $key ~~ rx/ ^ $variable $ /;
                my Int $val = %hash{$key}.Int;
                my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                my @args = %arg1, %arg2, %arg3;
                dd-handle(|@args);
                %hash{$key}     =  value => $val, type-spec => 'Int', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
            }
            when Rat {
                die-handle("$?FILE\[$?LINE\] " ~ q<Error: scalar hash should be of the form rx/ ^ '$' [ $twigil ]? $id-pattern $ / >) unless $key ~~ rx/ ^ $variable $ /;
                my Rat $val = %hash{$key}.Rat;
                my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                my @args = %arg1, %arg2, %arg3;
                dd-handle(|@args);
                %hash{$key}     =  value => $val, type-spec => 'Rat', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
            }
            when Num {
                die-handle("$?FILE\[$?LINE\] " ~ q<Error: scalar hash should be of the form rx/ ^ '$' [ $twigil ]? $id-pattern $ / >) unless $key ~~ rx/ ^ $variable $ /;
                my Num $val = %hash{$key}.Num;
                my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                my @args = %arg1, %arg2, %arg3;
                dd-handle(|@args);
                %hash{$key}     =  value => $val, type-spec => 'Num', raku-class => True,        null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
            }
            when Bool {
                die-handle("$?FILE\[$?LINE\] " ~ q<Error: scalar hash should be of the form rx/ ^ '$' [ $twigil ]? $id-pattern $ / >) unless $key ~~ rx/ ^ $variable $ /;
                my Bool $val = %hash{$key}.Bool;
                my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                my %arg3 = name => '$val', value => $val, place => "$?FILE\[$?LINE\]: ";
                my @args = %arg1, %arg2, %arg3;
                dd-handle(|@args);
                %hash{$key}     =  value => $val, type-spec => 'Bool', raku-class => True,       null => False, definedness => "D", var => const-var, perms => "r", name => "$key";
            }
            when Hash {
                my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                my %arg2 = name => "$key", value => %hash{$key}, place => "$?FILE\[$?LINE\]: ";
                my @args =  %arg1, %arg2;
                dd-handle(|@args);
                my %value_ = %hash{$key};
                if all %value_<value type-spec null definedness var perms>:exists  {
                    #`«««#######################################
                    #                                          #
                    #    It is a script variable already so    #
                    #    we check it for sanity and then       #
                    #    load it, after converting the value   #
                    #    field to Raku values of the right     #
                    #    type.                                 #
                    #                                          #
                    #########################################»»»
                    given $key {
                        when rx/ ^ '$' [ $twigil ]? $id-pattern $/ {
                            given %value_<type-spec> {
                                when 'Str' {
                                    my Str $val = %value_<value>;
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => $val, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    if %value_<null> {
                                        die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type Str:D") if %value_<definedness> eq 'D';
                                        $val = Str;
                                    } else {
                                        die-handle("$?FILE\[$?LINE\] Error: defined value cannot exist in variable with type Str:U") if %value_<definedness> eq 'U'; 
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                } # when 'Str' #
                                when 'Int' {
                                    die-handle("$?FILE\[$?LINE\] Error: value is not Numeric") unless isNumeric(%value_<value>).Bool; 
                                    my Int $val = %value_<value>.Int;
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => $val, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    if %value_<null> {
                                        die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type Int:D") if %value_<definedness> eq 'D'; 
                                        $val = Int;
                                    } else {
                                        die-handle("$?FILE\[$?LINE\] Error: defined value cannot exist in variable with type Int:U") if %value_<definedness> eq 'U'; 
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                } # when 'Int' #
                                when 'Rat' {
                                    my Rat $val = %value_<value>.Rat;
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => $val, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    if %value_<null> {
                                        die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type Rat:D") if %value_<definedness> eq 'D'; 
                                        $val = Rat;
                                    } else {
                                        die-handle("$?FILE\[$?LINE\] Error: defined value cannot exist in variable with type Rat:U") if %value_<definedness> eq 'U'; 
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                } # when 'Rat' #
                                when 'FatRat' {
                                    my FatRat $val = %value_<value>.FatRat;
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => $val, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    if %value_<null> {
                                        die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type FatRat:D") if %value_<definedness> eq 'D';
                                        $val = FatRat;
                                    } else {
                                        die-handle("$?FILE\[$?LINE\] Error: defined value cannot exist in variable with type FatRat:U") if %value_<definedness> eq 'U';
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                } # when 'FatRat' #
                                when 'Num' {
                                    my Num $val = %value_<value>.Num;
                                    if %value_<null> {
                                        die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type Num:D") if %value_<definedness> eq 'D'; 
                                        $val = Num;
                                    } else {
                                        die-handle("$?FILE\[$?LINE\] Error: defined value cannot exist in variable with type Num:U") if %value_<definedness> eq 'U'; 
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                } # when 'Num' #
                                when 'Complex' {
                                    my Complex $val = %value_<value>.Complex;
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => $val, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    if %value_<null> {
                                        die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type Complex:D") if %value_<definedness> eq 'D'; 
                                        $val = Complex;
                                    } else {
                                        die-handle("$?FILE\[$?LINE\] Error: defined value cannot exist in variable with type Complex:U") if %value_<definedness> eq 'U'; 
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                } # when 'Complex' #
                                when 'IntStr' {
                                    die-handle("$?FILE\[$?LINE\] Error: value is not Numeric") unless isNumeric(%value_<value>).Bool; 
                                    my IntStr $val = %value_<value>.IntStr;
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => $val, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    if %value_<null> {
                                        die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type IntStr:D") if %value_<definedness> eq 'D'; 
                                        $val = IntStr;
                                    } else {
                                        die-handle("$?FILE\[$?LINE\] Error: defined value cannot exist in variable with type IntStr:U") if %value_<definedness> eq 'U'; 
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                } # when 'IntStr' #
                                when 'NumStr' {
                                    my NumStr $val = %value_<value>.NumStr;
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => $val, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    if %value_<null> {
                                        die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type NumStr:D") if %value_<definedness> eq 'D'; 
                                        $val = NumStr;
                                    } else {
                                        die-handle("$?FILE\[$?LINE\] Error: defined value cannot exist in variable with type NumStr:U") if %value_<definedness> eq 'U'; 
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                } # when 'NumStr' #
                                when 'RatStr' {
                                    my RatStr $val = %value_<value>.RatStr;
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => $val, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    if %value_<null> {
                                        die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type RatStr:D") if %value_<definedness> eq 'D'; 
                                        $val = RatStr;
                                    } else {
                                        die-handle("$?FILE\[$?LINE\] Error: defined value cannot exist in variable with type RatStr:U") if %value_<definedness> eq 'U'; 
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                } # when 'RatStr' #
                                when 'ComplexStr' {
                                    my ComplexStr $val = %value_<value>.ComplexStr;
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => $val, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    if %value_<null> {
                                        die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type ComplexStr:D") if %value_<definedness> eq 'D'; 
                                        $val = ComplexStr;
                                    } else {
                                        die-handle("$?FILE\[$?LINE\] Error: defined value cannot exist in variable with type ComplexStr:U") if %value_<definedness> eq 'U'; 
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                } # when 'ComplexStr' #
                                when 'Hash' { 
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => %value_<value>, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    die-handle("$?FILE\[$?LINE\] Error: Hash in a scaler is not supported.");
                                    #`«««
                                    my Hash $val = %value_<value>.Hash;
                                    if %value_<null> {
                                        if %value_<definedness> eq 'D' {
                                            die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type Hash:D");
                                        } 
                                        $val = Hash;
                                    } else {
                                        #%hash{$key}<value> = $val; # redundant #
                                        next;
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                    #»»»
                                } # when 'Hash' #
                                when 'Array' {
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => %value_<value>, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    die-handle("$?FILE\[$?LINE\] Error: Array in a scaler is not supported.");
                                    #`«««
                                    my Hash $val = %value_<value>.Hash;
                                    if %value_<null> {
                                        if %value_<definedness> eq 'D' {
                                            die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type Hash:D");
                                        } 
                                        $val = Hash;
                                    } else {
                                        #%hash{$key}<value> = $val; # redundant #
                                        next;
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                    #»»»
                                } # when 'Array' #
                                when 'Collation' {
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => %value_<value>, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    my Collation $val = %value_<value>.Collation;
                                    if %value_<null> {
                                        die-handle("$?FILE\[$?LINE\] Error: null value cannot exist in variable with type Str:D") if %value_<definedness> eq 'D'; 
                                        $val = Collation;
                                    } else {
                                        die-handle("$?FILE\[$?LINE\] Error: defined value cannot exist in variable with type Str:U") if %value_<definedness> eq 'U'; 
                                    }
                                    %hash{$key}<value> = $val;
                                    %hash{$key}<name>  = $key;
                                } # when 'Collation' #
                                default {
                                }
                            } # given %value_<type-spec> #
                        } # when rx/ ^ '$' [ $twigil ]? $id-pattern $/ #
                        when rx/ ^ '@' [ $twigil ]? $id-pattern $ / {
                            given %value_<type-spec> {
                                when 'Array' {
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => %value_<value>, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    if %value_<value> ~~ Array  {
                                        my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                        my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                        my %arg3 = name => "$key", value => %value_<value>, place => "$?FILE\[$?LINE\]: ";
                                        my @args =  %arg1, %arg2, %arg3;
                                        dd-handle(|@args);
                                    } else {
                                        die-handle("$?FILE\[$?LINE\] Error: type-spec doesn't match value type!!!!");
                                        #%hash{$key} =   value => %value_, type-spec => 'Hash', raku-class => True,     null => False, definedness => "",  var => variable,  perms => "rw<", name => "$key" ;
                                    }
                                    %hash{$key}<name> = "$key";
                                } # when 'Array' #
                                default {
                                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                                    my %arg3 = name => "$key", value => %value_<value>, place => "$?FILE\[$?LINE\]: ";
                                    my @args =  %arg1, %arg2, %arg3;
                                    dd-handle(|@args);
                                    die-handle("$?FILE\[$?LINE\] Error: type-spec doesn't match variable type!!!!");
                                }
                            } # given %value_<type-spec> #
                        } # when rx/ ^ '@' [ $twigil ]? $id-pattern $ / #
                        when rx/ ^ $function-variable $ / {
                            my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                            my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                            my %arg3 = name => "$key", value => %value_<value>, place => "$?FILE\[$?LINE\]: ";
                            my @args =  %arg1, %arg2, %arg3;
                            dd-handle(|@args);
                            die-handle("Error: cannot have a Hash as a function {$key} should be {$key.subst(rx/ ^ '&' /, '%')} or {$key.subst(rx/ ^ '&' [ $sigil ]? /, '')}!!!");
                        } # when rx/ ^ '&' [ $twigil ]? $id-pattern $ / #
                    } # given $key #
                } else { # if all %value_<value type-spec null definedness var perms>:exists #
                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                    my %arg2 = name => "$key", value => %value_, place => "$?FILE\[$?LINE\]: ";
                    my %arg3 = name => "$key", value => %value_<value>, place => "$?FILE\[$?LINE\]: ";
                    my @args =  %arg1, %arg2, %arg3;
                    dd-handle(|@args);
                    #`«««**************************************
                    #                                         #
                    #    it's just an arbitrary hash not a    #
                    #    install script var so use as the     #
                    #    value field                          #
                    #                                         #
                    #***************************************»»»
                    die-handle("$?FILE\[$?LINE\] " ~ q<Error: Hash variables should be of the form '%' [ $twigil ]? $id-pattern >) unless $key ~~ rx/ ^ '%' [ $twigil ]? $id-pattern $ /;
                    %hash{$key} =   value => %value_, type-spec => 'Hash', raku-class => True,     null => False, definedness => "",  var => variable,  perms => "rw<", name => "$key" ;
                    next;
                } # if all %value_<value type-spec null definedness var perms>:exists ... else ... #
            } # when Hash #
            when Array {
                my @value = @(%hash{$key});
                    my %arg1 = name => '$key', value => $key, place => "$?FILE\[$?LINE\]: ";
                    my %arg2 = name => "$key", value => @value, place => "$?FILE\[$?LINE\]: ";
                    my %arg3 = name => "$key", value => @value[0], place => "$?FILE\[$?LINE\]: ";
                    my @args =  %arg1, %arg2, %arg3;
                    dd-handle(|@args);
                if @value[0] ~~ rx/ ^ [ 'cmds' || 'scope' ] $ / {
                    die-handle("$?FILE\[$?LINE\] " ~ q<Error: functions should be of the form rx/ ^ [ '&' [ $twigil ]? ]? $id-pattern $ / >) unless $key ~~ rx/ ^ $function-variable $ /;
                    %hash{$key} = value => vet-function(@value),  type-spec => 'Function', null => False, definedness => "",  var => function, perms => "x", name => "$key";
                } else {
                    die-handle("$?FILE\[$?LINE\] " ~ q<Error: Array variables should be of the form '@' [ $twigil ]? $id-pattern >) unless $key ~~ rx/ ^ '@' [ $twigil ]? $id-pattern $ /;
                    %hash{$key} = value => convert-array(@value), type-spec => 'Array',  null => False, definedness => "",  var => variable, perms => "rw", name => "$key";
                }
            }
            default {
                die-handle(qq<$?FILE\[$?LINE\] Error: unkown type  { .^name } how did you get that in json >);
                my $val = %hash{$key};
                %hash{$key}     =  value => $val, type-spec => 'Any', raku-class => True,        null => False, definedness => "",  var => variable,  perms => "rw", name => "$key";
            }
        } # given %hash{$key} #
    } # for %hash.keys -> $key #
    return %hash;
} # sub convert-hash-to-internal-format(%hash is copy --> Hash) is export #

sub convert-array(@array is copy --> Array) is export {
    #TODO: Fill this in  #
    return @array;
}

sub vet-function(@fun is copy --> Array) is export {
    # TODO: fuill this in  #
    return @fun;
}

sub convert-to-internal-format(%actions is copy --> Hash) {
    #`«««################################################################
    #                                                                   #
    #                               %vars                               #
    #                                                                   #
    ##################################################################»»»
    if %actions<%vars> ~~ Hash {
        my %vars = %actions<%vars>;
        %vars = convert-hash-to-internal-format(%vars);
        %actions<%vars> = value => %vars, type-spec => 'Frame-var', raku-class => True, null => False, definedness => "D", var => frame-var, perms => "rwx", name => '%vars';
    } else {
        die-handle("$?FILE\[$?LINE\] Error: '\%vars should always be a Hash.");
    }
    #`«««################################################################
    #                                                                   #
    #                          &before function                         #
    #                                                                   #
    ##################################################################»»»
    if (%actions<&before> ~~ Array) && (@(%actions<&before>)[0] ~~ rx/ ^ [ 'cmds' || 'scope' ] $ /) {
        my @before = %actions<&before>;
        %actions<&before> = value => vet-function(@before), type-spec => 'Function', null => False, definedness => "D", var => function, perms => "x", name => '&before';
    } else {
        die-handle("$?FILE\[$?LINE\] " ~ q<Error: `&before' should always be an Array, with first element of either 'cmds' or 'scope'.>);
    }
    #`«««################################################################
    #                                                                   #
    #                            Body paths                             #
    #                                                                   #
    ##################################################################»»»
    if (%actions<@body-paths> ~~ Array) && (%actions<@body-paths>.map( { $_ ~~ Hash } ).reduce( &infix:<&&> ) ) {
        my @body-paths = %actions<@body-paths>[0];
        my %arg1 = name => '@body-paths', value => @body-paths, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args);
        unless @body-paths ~~ Array {
            $handle.say: qq<Error: \@body-paths is nolonger an Array!!!!>;
            my %arg1 = name => '@body-paths', value => @body-paths, place => "$?FILE\[$?LINE\]: ";
            my @args;
            @args.push:  %arg1;
            dd-handle(|@args);
        }
        dd @body-paths;
        my @res;
        for @body-paths.keys -> $ind {
            unless @body-paths[$ind] ~~ Hash {
                my %arg1 = name => '$ind', value => $ind, place => "$?FILE\[$?LINE\]: ";
                my %arg2 = name => '@body-paths[$ind]', value => @body-paths[$ind], place => "$?FILE\[$?LINE\]: ";
                my @args = %arg1, %arg2;
                dd-handle(|@args);
            }
            my %elt = @body-paths[$ind];
            my %arg1 = name => '$ind', value => $ind, place => "$?FILE\[$?LINE\]: ";
            my %arg2 = name => '%elt', value => %elt, place => "$?FILE\[$?LINE\]: ";
            my @args = %arg1, %arg2;
            dd-handle(|@args);
            my %val = convert-hash-to-internal-format(%elt);
            @res.push: %val;
        }
        %actions<@body-paths> = value => @res, type-spec => 'Array', raku-class => True, null => False, definedness => "D", var => variable, perms => "rwx", name => '@body-paths';
        my %arg3 = name => '@res', value => @res, place => "$?FILE\[$?LINE\]: ";
        my %arg4 = name => '%actions<@body-paths>', value => %actions<@body-paths>, place => "$?FILE\[$?LINE\]: ";
        my @args-d = %arg3, %arg4;
        dd-handle(|@args-d);
    } else {
        die-handle("$?FILE\[$?LINE\] " ~ q<Error: `@body-paths' should always be an Array, of Hashes.>);
    }
    #`«««################################################################
    #                                                                   #
    #                            &body function                         #
    #                                                                   #
    ##################################################################»»»
    my %arg1 = name => '%actions<&body>', value => %actions<&body>, place => "$?FILE\[$?LINE\]: ";
    my @args;
    @args.push: %arg1;
    dd-handle(|@args);
    if (%actions<&body> ~~ Array) && (@(%actions<&body>)[0] ~~ rx/ ^ [ 'cmds' || 'scope' ] $ /) {
        my @body = %actions<&body>;
        unless @body ~~ Array {
            $handle.say: qq<Error: \@body is nolonger an Array!!!!>;
            my %arg1 = name => '&body', value => @body, place => "$?FILE\[$?LINE\]: ";
            my @args;
            @args.push:  %arg1;
            dd-handle(|@args);
        }
        %actions<&body> = value => vet-function(@body), type-spec => 'Function', null => False, definedness => "D", var => function, perms => "x", name => '&body';
    } else {
        my $msg = q<Error: `&body' should always be an Array, with first element of either 'cmds' or 'scope'.>;
        die-handle("$?FILE\[$?LINE\] {$msg}");
    }
    #`«««################################################################
    #                                                                   #
    #                           &after function                         #
    #                                                                   #
    ##################################################################»»»
    my %arg2 = name => '%actions<&after>', value => %actions<&after>, place => "$?FILE\[$?LINE\]: ";
    my @args1;
    @args1.push: %arg2;
    dd-handle(|@args1);
    if (%actions<&after> ~~ Array) && (@(%actions<&after>)[0] ~~ rx/ ^ [ 'cmds' || 'scope' ] $ /) {
        my @after = %actions<&after>;
        unless @after ~~ Array {
            $handle.say: qq<Error: \@after is nolonger an Array!!!!>;
            my %arg1 = name => '&after', value => @after, place => "$?FILE\[$?LINE\]: ";
            my @args;
            @args.push:  %arg1;
            dd-handle(|@args);
        }
        %actions<&after> = value => vet-function(@after), type-spec => 'Function', null => False, definedness => "D", var => function, perms => "x", name => '&after';
    } else {
        die-handle("$?FILE\[$?LINE\] " ~ q<Error: `&after'-paths should always be an Array, with first element of either 'cmds' or 'scope'.>);
    }
    #`«««################################################################
    #                                                                   #
    #                         All the other keys                        #
    #                                                                   #
    ##################################################################»»»
    my @keys = %actions.keys.grep( { $_ !~~ rx/ ^ [ '%vars' || '&before' || '@body-paths' || '&body' || '&after' ] $ / } );
    my %arg3 = name => '@keys', value => @keys, place => "$?FILE\[$?LINE\]: ";
    my @args2;
    @args2.push:  %arg3;
    dd-handle(|@args2);
    for @keys -> $key {
        $handle.say: qq<I have got here>;
        my %arg1 = name => "$key", value => %actions{$key}, place => "$?FILE\[$?LINE\]: ";
        my @args;
        @args.push:  %arg1;
        dd-handle(|@args);
        given %actions{$key} {
            when Hash {
                unless $key ~~ rx/ ^ $hash-variable $ / {
                    my Str:D $msg = q<Error: a hash variable must follow the pattern rx ^ '%' [ $sigil ]? $id-pattern $ / >;
                    die-handle("$?FILE\[$?LINE\] {$msg} you supplied \`{$key}'");
                }
                my %hash = convert-hash-to-internal-format(%actions{$key});
                %actions{$key} = value => %hash, type-spec => 'Frame-var', raku-class => True, null => False, definedness => "D", var => frame-var, perms => "rwx", name => '%hash';
            } # when Hash #
            when Array {
                my @array = @(%actions{$key}.flat);
                if @array[0] ~~ rx/ ^ [ 'cmds' || 'scope' ] $ / {
                    unless $key ~~ rx/ ^ $function-variable $ / {
                        my Str:D $msg = q<Error: a function variable must follow the pattern rx ^ [ '&' [ $sigil ]? ]? $id-pattern $ / >;
                        die-handle("$?FILE\[$?LINE\] {$msg} you supplied \`{$key}'");
                    }
                    my @fun = vet-function(@array);
                    %actions{$key} = value => @fun, type-spec => 'Function', raku-class => True, null => False, definedness => "D", var => function, perms => "x", name => "$key";
                } else {
                    unless $key ~~ rx/ ^ $array-variable $ / {
                        my Str:D $msg = q<Error: an array variable must follow the pattern rx ^ '@' [ $sigil ]? $id-pattern $ / >;
                        die-handle("$?FILE\[$?LINE\] {$msg} you supplied \`{$key}'");
                    }
                    my @array-val = convert-array(@array);
                    %actions{$key} = value => @array-val, type-spec => 'Array', raku-class => True, null => False, definedness => "D", var => variable, perms => "rwx", name => "$key";
                }
            } # when Array #
            when List {
                my @array = @(%actions{$key}.flat);
                if @array[0] ~~ rx/ ^ [ 'cmds' || 'scope' ] $ / {
                    unless $key ~~ rx/ ^ $function-variable $ / {
                        my Str:D $msg = q<Error: a function variable must follow the pattern rx ^ [ '&' [ $sigil ]? ]? $id-pattern $ / >;
                        die-handle("$?FILE\[$?LINE\] {$msg} you supplied \`{$key}'");
                    }
                    my @fun = vet-function(@array);
                    %actions{$key} = value => @fun, type-spec => 'Function', raku-class => True, null => False, definedness => "D", var => function, perms => "x", name => "$key";
                } else {
                    unless $key ~~ rx/ ^ $array-variable $ / {
                        my Str:D $msg = q<Error: an array variable must follow the pattern rx ^ '@' [ $sigil ]? $id-pattern $ / >;
                        die-handle("$?FILE\[$?LINE\] {$msg} you supplied \`{$key}'");
                    }
                    my @array-val = convert-array(@array);
                    %actions{$key} = value => @array-val, type-spec => 'Array', raku-class => True, null => False, definedness => "D", var => variable, perms => "rwx", name => "$key";
                }
            } # when List #
            default {
                my Str:D $msg = q<Error: a Hash, Function or  an Array variable must be supplied >;
                die-handle("$?FILE\[$?LINE\] {$msg} you supplied \`{%actions{$key}.^name}'");
            }
        }
    }
    return %actions;
} #`««« sub convert-to-internal-format(%actions is copy) »»»

sub common-init(IO::Handle:D $handle_, %meta_ is copy, Bool $debug_ = False --> Bool:D) is export {
    $handle = $handle_;
    if !(%meta_<actions>:exists && (%meta_<actions> ~~ Hash)) {
        die-handle("$?FILE\[$?LINE\] " ~ q<Error: `%!meta<build><actions>' must exist and must be a Hash.>);
    }
    my %actions           = convert-to-internal-format(%meta_<actions>);
    %meta_<actions>       = %actions;
    my       %base-frame  = %actions;
    my       @keys        = %actions.keys;
    my Str:D $log_        = %meta_<log>;
    @symbol-table.push: %base-frame;
    my %vars  = %meta_<actions><%vars>;
    my %frame = %vars<value>;
    @symbol-table.push: %frame;

    $debug  = $debug_;
    $log    = $log_;
    my %arg1 = name => '@symbol-table', value => @symbol-table, place => "$?FILE\[$?LINE\]: ";
    my %arg2 = name => '$log', value => $log, place => "$?FILE\[$?LINE\]: ";
    my %arg3 = name => '$debug', value => $debug, place => "$?FILE\[$?LINE\]: ";
    my %arg4 = name => '%meta_<actions><%vars>', value => %meta_<actions><%vars>, place => "$?FILE\[$?LINE\]: ";
    my %arg5 = name => '%meta_<actions><%vars><value>', value => %(%meta_<actions><%vars>)<value>, place => "$?FILE\[$?LINE\]: ";
    my %arg6 = name => '%vars', value => %vars, place => "$?FILE\[$?LINE\]: ";
    my %arg7 = name => '%base-frame', value => %base-frame, place => "$?FILE\[$?LINE\]: ";
    my %arg8 = name => '%actions', value => %actions, place => "$?FILE\[$?LINE\]: ";
    my %arg9 = name => '%frame', value => %frame, place => "$?FILE\[$?LINE\]: ";
    my %arg10 = name => '@keys', value => @keys, place => "$?FILE\[$?LINE\]: ";
    my @args = %arg1, %arg2, %arg3, %arg4, %arg5, %arg6, %arg7, %arg8, %arg9, %arg10;
    dd-handle(|@args) if $debug;
    return True;
}

sub symbol-table-add(IO::Handle:D $handle, %frame, Bool:D :$debug = get-debug() --> Bool:D) is export {
    @symbol-table.push: %frame;
}

sub pop-symbol-table( --> Hash) is export {
    return @symbol-table.pop;
}

sub ls-l(IO::Handle:D $handle, Bool:D :$debug = get-debug(), Bool:D :$tree = False, *@args --> Bool:D) is  export {
    my Proc $r;
    if shell 'which exa' {
        my @cmd = 'exa', '-F', ($tree ?? '-laahigHb' !! '-lahigHTb'), '--color-scale', '--time-style=full-iso', '--icons=always';
        @cmd.push: @args if @args;
        $handle.say: qq[$?FILE\[$?LINE\] {@cmd.join(' ')}.] if $debug;
        $r = run |@cmd, :out($handle), :err($handle)        if $debug;
    } else {
        my @cmd = 'ls', '--color=auto', '-Flaghi', '--color';
        @cmd.push: @args if @args;
        $handle.say: qq[$?FILE\[$?LINE\] {@cmd.join(' ')}.] if $debug;
        $r = run |@cmd, :out($handle), :err($handle)        if $debug;
    }
    return $debug && ($r.exitcode == 0);
} #`««« sub ls-l(IO::Handle:D $handle, Bool:D :$debug = get-debug(), *@args --> Bool:D) is  export »»»




sub die-handle(Str:D $msg, IO::Handle:D :$handle is copy = get-handle() --> Bool) is  export {
    with %meta«build»«log» {
        if %meta«build»«log» ~~ rx/ ^^ '/dev/null' $$ / {
            $handle = "/dev/tty".IO.open: :append, :mode<rw>, :out-buffer(False);
        }
    }
    $handle.say: $msg;
    X::AdHoc.from-slurpy(10, False, $msg).throw;
}

sub unwrap(Str:D $expr is copy --> Str:D) is export {
    $expr ~~ s/ ^ '{' \s* ( .* ) \s* '}' $ /$0/;
    return $expr;
}

#`«««
class Mac is Macro {
    macro expr-to-type( Str $arg ) {
        return EVAL($arg);
    }
}
#»»»

sub null-value(Str:D $type-spec is copy, Bool :$debug = get-debug() --> Mu:U) is export {
    $type-spec ~~ s:g/ [ ':D' || ':U' ] //;
    given $type-spec {
        when 'Str' { return Str; }
        when 'Int' { return Int; }
        when 'Num' { return Num; }
        when 'Rat' { return Rat; }
        when 'FatRat' { return FatRat; }
        when 'Complex' { return Complex; }
        when 'IntStr' { return IntStr; }
        when 'NumStr' { return NumStr; }
        when 'RatStr' { return RatStr; }
        when 'ComplexStr' { return ComplexStr; }
        when 'Hash' { return Hash; }
        when 'Date' { return Date; }
        when 'DateTime' { return DateTime; }
        when 'Duration' { return Duration; }
        when 'Instant' { return Instant; }
        when 'IO::Path' { return IO::Path; }
        when 'Kernel' { return Kernel; }
        when 'Distro' { return Distro; }
        when 'VM' { return VM; }
        when 'Raku' { return Raku; }
        when 'IO::Spec' { return IO::Spec; }
        when 'Thread' { return Thread; }
        when 'ThreadPoolScheduler' { return ThreadPoolScheduler; }
        when 'Collation' { return Collation; }
        when 'Bool' { return Bool; }
        when 'Array' { return Array; }
        when 'Collation' { return Collation; }
        when 'Regex' { return Regex; }
        when 'Distribution::Path' { return Distribution::Path; }
        when 'Distribution::Hash' { return Distribution::Hash; }
        when 'Distribution::Resource' { return Distribution::Resource; }
        when 'Encoding::Registry' { return Encoding::Registry; }
        when 'Whatever' { return Whatever; }
        when 'Unkown' { return  Any; }
        when 'Any' { return Any; }
        default { return Any; }
    }
    #`«««
    my expr-to-type('Array[Hash[Str]]') @a;
    return @a.^type;
    #»»»
} # sub null-value(Str:D $type-spec is copy, Bool :$debug = get-debug() --> Mu:U) is export #

sub look-up-class(Identifier:D $name --> Hash) {
    my %result = class-not-found => True, value => 'class-not-found', var => class-not-found;
    given $name {
        when 'IntStr' { %result = value => IntStr.^name, type-spec => IntStr.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'RatStr' { %result = value => RatStr.^name, type-spec => RatStr.^name, raku-class => True, 
                                                                         null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'NumStr' { %result = value => NumStr.^name, type-spec => NumStr.^name, raku-class => True, 
                                                                         null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'ComplexStr' { %result = value => ComplexStr.^name, type-spec => ComplexStr.^name, raku-class => True, 
                                                                         null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Str' { %result = value => Str.^name, type-spec => Str.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Int' { %result = value => Int.^name, type-spec => Int.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Rat' { %result = value => Rat.^name, type-spec => Rat.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'FatRat' { %result = value => FatRat.^name, type-spec => FatRat.^name, raku-class => True, 
                                                                        null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Num' { %result = value => Num.^name, type-spec => Num.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Complex' { %result = value => Complex.^name, type-spec => Complex.^name, raku-class => True,
                                                                        null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Date' { %result = value => Date.^name, type-spec => Date.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'DateTime' { %result = value => DateTime.^name, type-spec => DateTime.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Duration' { %result = value => Duration.^name, type-spec => Duration.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Duration' { %result = value => Duration.^name, type-spec => Duration.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Instant' { %result = value => Instant.^name, type-spec => Instant.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'IO::Path' { %result = value => IO::Path.^name, type-spec => IO::Path.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Kernel' { %result = value => Kernel.^name, type-spec => Kernel.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Distro' { %result = value => Distro.^name, type-spec => Distro.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'VM' { %result = value => VM.^name, type-spec => VM.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Raku' { %result = value => Raku.^name, type-spec => Raku.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'IO::Spec' { %result = value => IO::Spec.^name, type-spec => IO::Spec.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Thread' { %result = value => Thread.^name, type-spec => Thread.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'ThreadPoolScheduler' { %result = value => ThreadPoolScheduler.^name, type-spec => ThreadPoolScheduler.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Collation' { %result = value => Collation.^name, type-spec => Collation.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Regex' { %result = value => Regex.^name, type-spec => Regex.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Distribution::Path' { %result = value => Distribution::Path.^name, type-spec => Distribution::Path.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Distribution::Hash' { %result = value => Distribution::Hash.^name, type-spec => Distribution::Hash.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Distribution::Resource' { %result = value => Distribution::Resource.^name, type-spec => Distribution::Resource.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Hash' { %result = value => Hash.^name, type-spec => Hash.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Map' { %result = value => Map.^name, type-spec => Map.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Array' { %result = value => Array.^name, type-spec => Array.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'List' { %result = value => List.^name, type-spec => List.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Encoding::Registry' { %result = value => Encoding::Registry.^name, type-spec => Encoding::Registry.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Whatever' { %result = value => Whatever.^name, type-spec => Whatever.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Any' { %result = value => Any.^name, type-spec => Any.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
        when 'Mu' { %result = value => Mu.^name, type-spec => Mu.^name, raku-class => True, 
                                                                          null => True, definedness => 'U', var => class-def, perms => 'r', name => $name; }
    }
    #`«««#######################################################################
    #                                                                          #
    #   The following assumes I will eventually impliment user defined types   #
    #                                                                          #
    #########################################################################»»»
    for @symbol-table.reverse()  -> %sym {
        %result = %sym{$name} if %sym{$name}:exists;
        last if %result;
    }
    return %result;
} # sub look-up-class(Str:D $name --> Hash) #

sub my-variable(Variable:D $name, $value, Str:D :$type-spec is copy = 'Any', VarType:D :$var is copy = variable,
                        Str:D :$perms = 'rw', Bool:D :$raku-class is copy = True --> Bool:D) {
    my Bool:D $null = True;
    with $value {
        $null = False;
    }
    my %class-spec = look-up-class($value.^name);
    if %class-spec<var> ~~ class-not-found {
        return False;
    } else {
        $raku-class = %class-spec<raku-class>;
        #$type-spec  = $value.^name;
    }
    my Str:D $def = '';
    if $type-spec ~~ rx/ ^ $<type-spec> = [ $id-pattern ] [ ':' $<def> = [ 'D' || 'U' ] ]? $ / {
        with ~$<def> {
            $def = ~$<def>;
        }
        $type-spec = ~$<type-spec>;
    }
    my %spec = value => $value, type-spec => $type-spec, raku-class => $raku-class, null => $null, definedness => $def, var => $var, perms => $perms, name => $name;

    @symbol-table[*-1]{$name} = %spec;
    return True;
}

sub our-variable(Variable:D $name, $value, Str:D :$type-spec is copy = 'Any', VarType:D :$var is copy = variable,
                        Str:D :$perms = 'rw', Bool:D :$raku-class is copy = True --> Bool:D) {
    my Bool:D $null = True;
    with $value {
        $null = False;
    }
    my %class-spec = look-up-class($value.^name);
    if %class-spec<var> ~~ class-not-found {
        return False;
    } else {
        $raku-class = %class-spec<raku-class>;
        #$type-spec  = $value.^name;
    }
    my Str:D $def = '';
    if $type-spec ~~ rx/ ^ $<type-spec> = [ $id-pattern ] [ ':' $<def> = [ 'D' || 'U' ] ]? $ / {
        with ~$<def> {
            $def = ~$<def>;
        }
        $type-spec = ~$<type-spec>;
    }
    my %spec = value => $value, type-spec => $type-spec, raku-class => $raku-class, null => $null, definedness => $def, var => $var, perms => $perms, name => $name;

    @symbol-table[0]{$name} = %spec;
    return True;
}

sub get-value(Variable:D $name) is export {
    my %spec = resolve-symbol($name);
    die-handle(qq<Error: may even not be a symbol.>) unless all %spec<value var null type-spec raku-class perms definedness>:exists;
    return %spec<value>;
}

sub get-var(Variable:D $name --> VarType:D) is export {
    my %spec = resolve-symbol($name);
    die-handle(qq<Error: may even not be a symbol.>) unless all %spec<value var null type-spec raku-class perms definedness>:exists;
    return %spec<var>;
}

sub get-raku-class(Variable:D $name --> Bool:D) is export {
    my %spec = resolve-symbol($name);
    die-handle(qq<Error: may even not be a symbol.>) unless all %spec<value var null type-spec raku-class perms definedness>:exists;
    return %spec<raku-class>;
}

sub get-perms(Variable:D $name --> Str:D) is export {
    my %spec = resolve-symbol($name);
    die-handle(qq<Error: may even not be a symbol.>) unless all %spec<value var null type-spec raku-class perms definedness>:exists;
    return %spec<perms>;
}

sub get-type-spec(Variable:D $name --> Str:D) is export {
    my %spec = resolve-symbol($name);
    die-handle(qq<Error: may even not be a symbol.>) unless all %spec<value var null type-spec raku-class perms definedness>:exists;
    return %spec<type-spec>;
}

sub get-definedness(Variable:D $name --> Str:D) is export {
    my %spec = resolve-symbol($name);
    die-handle(qq<Error: may even not be a symbol.>) unless all %spec<value var null type-spec raku-class perms definedness>:exists;
    return %spec<definedness>;
}

sub let-variable(Variable:D $name, :$value is copy = get-value($name), Str:D :$type-spec is copy = get-type-spec($name), VarType:D :$var is copy = get-var($name),
                        Str:D :$perms = get-perms($name), Bool:D :$raku-class is copy = get-raku-class($name), Str:D :$definedness = get-definedness($name) --> Bool:D) {
    my Str:D $def    = '';
    if $var ~~ unkown-var {
        return False;
    }
    my Bool:D $null = True;
    $null = False with $value;

    my %spec = value => $value, type-spec => $type-spec, raku-class => $raku-class, null => $null, definedness => $definedness, var => $var, perms => $perms, name => $name;

    @symbol-table[*-1]{$name} = %spec;
    return True;
}

sub resolve-symbol(Variable:D $name --> Hash) is export {
    my %result;
    for @symbol-table.reverse()  -> %sym {
        %result = %sym{$name} if %sym{$name}:exists;
        last if %result;
    }
    without %result {
        given $name {
            when '$log'                 { %result = value => $log,                 type-spec => 'Str', raku-class => True,       null => False, definedness => "D", 
                                                    var => const-var, perms => "r", name => '$log';  }
            when '$debug'               { %result = value => $debug,               type-spec => 'Bool', raku-class => True,      null => False, definedness => "D", 
                                                    var => const-var, perms => "r", name => '$debug';  }
            when '$HOME'|'$*HOME'       { %result = value => $*HOME,               type-spec => 'Str', raku-class => True,       null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*HOME';  }
            when '$*ENV'                { %result = value => $*ENV,                type-spec => 'Hash', raku-class => True, null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*ENV';  }
            when '$*INIT-INSTANT'       { %result = value => $*INIT-INSTANT,       type-spec => 'Instant', raku-class => True,   null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*INIT-INSTANT';  }
            when '$*TZ'                 { %result = value => $*TZ,                 type-spec => 'Int', raku-class => True,       null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*TZ';  }
            when '$*CWD'                { %result = value => $*CWD,                type-spec => 'IO::Path', raku-class => True,  null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*CWD';  }
            when '$*KERNEL'             { %result = value => $*KERNEL,             type-spec => 'Kernel', raku-class => True,    null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*KERNEL';  }
            when '$*DISTRO'             { %result = value => $*DISTRO,             type-spec => 'Distro', raku-class => True,    null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*DISTRO'; }
            when '$*VM'                 { %result = value => $*VM,                 type-spec => 'VM', raku-class => True,        null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*VM'; }
            when '$*RAKU'               { %result = value => $*RAKU,               type-spec => 'Raku', raku-class => True,      null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*RAKU'; }
            when '$*PID'                { %result = value => $*PID,                type-spec => 'Int', raku-class => True,       null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*PID'; }
            when '$*PROGRAM-NAME'       { %result = value => $*PROGRAM-NAME,       type-spec => 'Str', raku-class => True,       null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*PROGRAM-NAME'; }
            when '$*PROGRAM'            { %result = value => $*PROGRAM,            type-spec => 'IO::Path', raku-class => True,  null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*PROGRAM'; }
            when '$*EXECUTABLE-NAME'    { %result = value => $*EXECUTABLE-NAME,    type-spec => 'Str', raku-class => True,       null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*EXECUTABLE-NAME'; }
            when '$*EXECUTABLE'         { %result = value => $*EXECUTABLE,         type-spec => 'IO::Path', raku-class => True,  null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*EXECUTABLE'; }
            when '$*USER'               { %result = value => $*USER,               type-spec => 'IntStr', raku-class => True,    null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*USER'; }
            when '$*GROUP'              { %result = value => $*GROUP,              type-spec => 'IntStr', raku-class => True,    null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*GROUP'; }
            when '$*SPEC'               { %result = value => $*SPEC,               type-spec => 'IO::Spec', raku-class => True,  null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*SPEC'; }
            when '$*TMPDIR'             { %result = value => $*TMPDIR,             type-spec => 'IO::Path', raku-class => True,  null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'r', name => '$*'; }
            when '$*DEFAULT-READ-ELEMS' { %result = value => $*DEFAULT-READ-ELEMS, type-spec => 'Int', raku-class => True,       null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'rw', name => '$*TMPDIR'; }
            when '$*COLLATION'          { %result = value => $*COLLATION,          type-spec => 'Collation', raku-class => True, null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'rw', name => '$*COLLATION'; }
            when '$*RAT-OVERFLOW'       { %result = value => $*RAT-OVERFLOW,       type-spec => 'Num', raku-class => True,       null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'rw', name => '$*RAT-OVERFLOW'; }
            when '$*TOLERANCE'          { %result = value => $*TOLERANCE,          type-spec => 'Num', raku-class => True,       null => False, definedness => 'D',  
                                                    var => system-var,  perms => 'rw', name => '$*TOLERANCE'; }
            default                     { %result = value => 'undefined',          type-spec => 'Unkown', raku-class => Any,    null => True,  definedness => 'U',   
                                                    var => unkown-var,  perms => 'r', name => "$name"; }
        }
    }
    return %result;
} # sub resolve-symbol(IO::Handle:D $handle, Bool:D $debug, Str $name --> Hash) is export #

sub stringify-gist(%spec, Bool :$debug = get-debug() --> Str:D) is export {
    my Str:D $result = "Any";
    given %spec«type-spec» {
        when 'Mu'|'Mu:D'|'Mu:U' { $result = %spec«null» ?? 'Mu' !! qq[{%spec«value».gist}]; }
        when 'Any'|'Any:D'|'Any:U' { $result = %spec«null» ?? 'Any' !! qq[{%spec«value».gist}]; }
        when 'Str'|'Str:D'|'Str:U' { $result = %spec«null» ?? 'Str' !! qq[{%spec«value».gist}]; }
        when 'Bool'|'Bool:D'|'Bool:U' { $result = %spec«null» ?? 'Bool' !! (%spec«value» ?? qq["True"] !! qq["False"]); }
        when 'Int'|'Int:D'|'Int:U' { $result = %spec«null» ?? 'Int' !! qq[{%spec«value».Int.gist}]; }
        when 'Num'|'Num:D'|'Num:U' { $result = %spec«null» ?? 'Num' !! qq[{%spec«value».Num.gist}]; }
        when 'Rat'|'Rat:D'|'Rat:U' { $result = %spec«null» ?? 'Rat' !! qq[{%spec«value».Rat.gist}]; }
        when 'FatRat'|'FatRat:D'|'FatRat:U' { $result = %spec«null» ?? 'FatRat' !! qq[{%spec«value».FatRat.gist}]; }
        when 'Cool'|'Cool:D'|'Cool:U' { $result = %spec«null» ?? 'Cool' !! qq[{%spec«value».Cool.gist}]; }
        when 'UInt'|'UInt:D'|'UInt:U' { $result = %spec«null» ?? 'UInt' !! qq[{%spec«value».UInt.gist}]; }
        when 'Complex'|'Complex:D'|'Complex:U' { $result = %spec«null» ?? 'Complex' !! qq[{%spec«value».Complex.gist}]; }
        when 'Array' {
            $result = %spec«null» ?? "Array" !! qq[{%spec«value».gist}];
        }
        when 'List' {
            $result = %spec«null» ?? "List" !! qq[{%spec«value».gist}];
        }
        when 'Hash' {
            $result = %spec«null» ?? "Hash" !! qq[{%spec«value».gist}];
        }
        when 'Map' {
            $result = %spec«null» ?? qq[Map] !! qq[{%spec«value».gist}];
        }
        when 'Bag' {
            $result = %spec«null» ?? "Bag" !! qq[{%spec«value».gist}];
        }
        when 'Set' {
            $result = %spec«null» ?? qq[Set] !! qq[{%spec«value».gist}];
        }
        when 'IO::Path'|'IO::Path:D' { $result = %spec«null» ?? 'IO::Path' !! qq[{%spec«value».Str.IO.gist}]; }
        when 'IO::Handle'|'IO::Handle:D' { $result = %spec«null» ?? 'IO::Handle' !! qq[{%spec«value».gist}]; }
        default {
            my Str:D $tmp = %spec«type-spec»;
            $tmp ~~ s/ ( \w+ [ [ '-' || '::' ]? \w+ ]* ) [ ':D' || ':U' ] $ /$0/;
            $result = %spec«null» ?? $tmp !! qq[{%spec«value».gist}];
        }
    }
    return $result;
} # sub stringify-gist(%spec, Bool :$debug = get-debug() --> Str:D) is export #

sub stringify-Str(%spec, Bool :$debug = get-debug() --> Str:D) is export {
    my Str:D $result = "Any";
    my Regex $type-pattern = rx/ \w+ [ [ '-' || '::' ]? \w+ ]* [ ':D' || ':U' ]? /;
    given %spec«type-spec» {
        when 'Mu'|'Mu:D'|'Mu:U' { $result = %spec«null» ?? 'Mu' !! qq[{%spec«value».Str}]; }
        when 'Any'|'Any:D'|'Any:U' { $result = %spec«null» ?? 'Any' !! qq[{%spec«value».Str}]; }
        when 'Str'|'Str:D'|'Str:U' { $result = %spec«null» ?? 'Str' !! qq[{%spec«value».Str}]; }
        when 'Bool'|'Bool:D'|'Bool:U' { $result = %spec«null» ?? 'Bool' !! (%spec«value» ?? qq["True"] !! qq["False"]); }
        when 'Int'|'Int:D'|'Int:U' { $result = %spec«null» ?? 'Int' !! qq[{%spec«value».Int.Str}]; }
        when 'Num'|'Num:D'|'Num:U' { $result = %spec«null» ?? 'Num' !! qq[{%spec«value».Num.Str}]; }
        when 'Rat'|'Rat:D'|'Rat:U' { $result = %spec«null» ?? 'Rat' !! qq[{%spec«value».Rat.Str}]; }
        when 'FatRat'|'FatRat:D'|'FatRat:U' { $result = %spec«null» ?? 'FatRat' !! qq[{%spec«value».FatRat.Str}]; }
        when 'Cool'|'Cool:D'|'Cool:U' { $result = %spec«null» ?? 'Cool' !! qq[{%spec«value».Cool.Str}]; }
        when 'UInt'|'UInt:D'|'UInt:U' { $result = %spec«null» ?? 'UInt' !! qq[{%spec«value».UInt.Str}]; }
        when 'Complex'|'Complex:D'|'Complex:U' { $result = %spec«null» ?? 'Complex' !! qq[{%spec«value».Complex.Str}]; }
        when 'Array' {
            $result = %spec«null» ?? "Array" !! qq[{%spec«value».Str}];
        }
        when 'List' {
            $result = %spec«null» ?? "List" !! qq[{%spec«value».Str}];
        }
        when 'Hash' {
            $result = %spec«null» ?? "Hash" !! qq[{%spec«value».Str}];
        }
        when 'Map' {
            $result = %spec«null» ?? qq[Map] !! qq[{%spec«value».Str}];
        }
        when 'Bag' {
            $result = %spec«null» ?? "Bag" !! qq[{%spec«value».Str}];
        }
        when 'Set' {
            $result = %spec«null» ?? qq[Set] !! qq[{%spec«value».Str}];
        }
        when 'IO::Path'|'IO::Path:D' { $result = %spec«null» ?? 'IO::Path' !! qq[{%spec«value».Str.IO.Str}]; }
        when 'IO::Handle'|'IO::Handle:D' { $result = %spec«null» ?? 'IO::Handle' !! qq[{%spec«value».Str}]; }
        default {
            my Str:D $tmp = %spec«type-spec»;
            $tmp ~~ s/ ( \w+ [ [ '-' || '::' ]? \w+ ]* ) [ ':D' || ':U' ] $ /$0/;
            $result = %spec«null» ?? $tmp !! qq[{%spec«value».Str}];
        }
    }
    return $result;
} # sub stringify-Str(%spec, Bool :$debug = get-debug() --> Str:D) is export #

sub stringify-raku(%spec, Bool :$debug = get-debug() --> Str:D) {
    my Str:D $result = "Any";
    my Regex $type-pattern = rx/ \w+ [ [ '-' || '::' ]? \w+ ]* [ ':D' || ':U' ]? /;
    given %spec«type-spec» {
        when 'Mu'|'Mu:D'|'Mu:U' { $result = %spec«null» ?? 'Mu' !! qq[{%spec«value».raku}]; }
        when 'Any'|'Any:D'|'Any:U' { $result = %spec«null» ?? 'Any' !! qq[{%spec«value».raku}]; }
        when 'Str'|'Str:D'|'Str:U' { $result = %spec«null» ?? 'Str' !! qq[{%spec«value».raku}]; }
        when 'Bool'|'Bool:D'|'Bool:U' { $result = %spec«null» ?? 'Bool' !! (%spec«value» ?? qq["True"] !! qq["False"]); }
        when 'Int'|'Int:D'|'Int:U' { $result = %spec«null» ?? 'Int' !! qq[{%spec«value».Int.raku}]; }
        when 'Num'|'Num:D'|'Num:U' { $result = %spec«null» ?? 'Num' !! qq[{%spec«value».Num.raku}]; }
        when 'Rat'|'Rat:D'|'Rat:U' { $result = %spec«null» ?? 'Rat' !! qq[{%spec«value».Rat.raku}]; }
        when 'FatRat'|'FatRat:D'|'FatRat:U' { $result = %spec«null» ?? 'FatRat' !! qq[{%spec«value».FatRat.raku}]; }
        when 'Cool'|'Cool:D'|'Cool:U' { $result = %spec«null» ?? 'Cool' !! qq[{%spec«value».Cool.raku}]; }
        when 'UInt'|'UInt:D'|'UInt:U' { $result = %spec«null» ?? 'UInt' !! qq[{%spec«value».UInt.raku}]; }
        when 'Complex'|'Complex:D'|'Complex:U' { $result = %spec«null» ?? 'Complex' !! qq[{%spec«value».Complex.raku}]; }
        when 'Array' {
            $result = %spec«null» ?? "Array" !! qq[{%spec«value».raku}];
        }
        when 'List' {
            $result = %spec«null» ?? "List" !! qq[{%spec«value».raku}];
        }
        when 'Hash' {
            $result = %spec«null» ?? "Hash" !! qq[{%spec«value».raku}];
        }
        when 'Map' {
            $result = %spec«null» ?? qq[Map] !! qq[{%spec«value».raku}];
        }
        when 'Bag' {
            $result = %spec«null» ?? "Bag" !! qq[{%spec«value».raku}];
        }
        when 'Set' {
            $result = %spec«null» ?? qq[Set] !! qq[{%spec«value».raku}];
        }
        when 'IO::Path'|'IO::Path:D' { $result = %spec«null» ?? 'IO::Path' !! qq[{%spec«value».Str.IO.raku}]; }
        when 'IO::Handle'|'IO::Handle:D' { $result = %spec«null» ?? 'IO::Handle' !! qq[{%spec«value».raku}]; }
        default {
            my Str:D $tmp = %spec«type-spec»;
            $tmp ~~ s/ ( \w+ [ [ '-' || '::' ]? \w+ ]* ) [ ':D' || ':U' ] $ /$0/;
            $result = %spec«null» ?? $tmp !! qq[{%spec«value».raku}];
        }
    }
    return $result;
} # sub stringify-raku(%spec, Bool :$debug = get-debug() --> Str:D) is export #

sub stringify(%spec, Bool :$debug = get-debug() --> Str:D) is export {
    return stringify-raku(%spec, :$debug);
} # sub stringify(%spec, Bool :$debug = get-debug() --> Str:D) is export #

sub dd-like(IO::Handle $handle, Bool $debug, Bool:D :$file-line = True, *@var-names --> Bool:D) is export {
    $handle.print: "$?FILE\[$?LINE\] " if $file-line;
    for @var-names -> $name {
        my %spec = resolve-symbol($name);
        my Str:D $definedness = %spec«definedness» ?? ':' ~ %spec«definedness» !! '';
        $handle.say: "{%spec«type-spec»}{$definedness} $name == {stringify-raku(%spec, :$debug)}";
    }
    return True;
}

sub dd-handle(IO::Handle :$handle = get-handle(), Bool:D :$file-line = True, Bool:D :$double-space = True, *@var-names --> Bool:D) is export {
    $handle.print: "$?FILE\[$?LINE\] " if $file-line;
    for @var-names -> %spec {
        my $place  = %spec<place> // 'place-unkown';
        my $name   = %spec<name> // 'name-unkown';
        my $value  = %spec<value> // 'value-unkown';
        my $type   = $value.^name;
        $handle.say() if $double-space;
        $handle.say: "{$place}: {$type} $name == {$value.raku}";
        $handle.say() if $double-space;
    }
}

sub access-array(IO::Handle $handle, @array, Str:D $access-spec, Bool:D :$debug = get-debug() --> Array) is export {
    my Regex $qualify-access = rx/ [ [ [ '.' || ':' ] \w+ [ [ '-' ]? \w+ ]* ]* || '[' \s* \d \s* ']' ]* /;
    if $access-spec ~~ rx/ ^ $<head> = [ [ '.' || ':' ] [ \w+ [ [ '-' ]? \w+ ]* ]* ] $<tail> = [ [ $qualify-access ]? ] $ / {
        my Str:D $head = ~($<head>) // '';
        my Str:D $tail = ~($<tail>) // '';
        if $head ne '' {
            given $head {
                when '.kv' {
                    return @array.kv if $tail eq '';
                    return access-array($handle, @array.kv, $tail, :$debug);
                }
                when '.flat' {
                    return @array.flat if $tail eq '';
                    return access-array($handle, @array.flat, $tail, :$debug);
                }
                when '.List' {
                    return @array.List if $tail eq '';
                    return access-array($handle, @array.List, $tail, :$debug);
                }
                when '.Slip' {
                    return @array.Slip if $tail eq '';
                    return access-array($handle, @array.Slip, $tail, :$debug);
                }
                default { return @array; }
            }
        } else {
            return @array;
        }
    }  else {
        return @array;
    }
} # sub access-array(IO::Handle $handle, @array, Str:D $access-spec, Bool:D :$debug = get-debug() --> Array) is export #

sub resolve-dir(Str:D $dir, IO::Handle $handle, Bool $relitive-to-home = True --> Str) is export {
    die-handle("$?FILE\[$?LINE\] bad value") without $dir;
    my Str $Dir = ~$dir;
    #$Dir.say;
    $Dir = $home if $Dir eq '~';
    $Dir = $home if $Dir ~~ rx/ ^ '{' \s* '$*HOME' \s* '}' $ /;
    $Dir = $home if $Dir ~~ rx/ ^ '{' \s* '$HOME' \s* '}' $ /;
    $Dir ~~ s:g/ '{' \s* '$HOME' \s* '}' /$home/;
    $Dir ~~ s:g/ '{' \s* '$*HOME' \s* '}' /$home/;
    $Dir = $home if $Dir ~~ rx/ ^ '$*HOME' $ /;
    $Dir = $home if $Dir ~~ rx/ ^ '$HOME' $ /;
    $Dir ~~ s! ^ '~' \/ !$home\/!;
    $Dir ~~ s! ^^ '$HOME' \/ !$home\/!;
    $Dir ~~ s! ^^ '$*HOME' \/ !$home\/!;
    if $Dir ~~ rx! ^^ $<start> = [ '~' <-[ \/ ]> +  ] \/ ! {
        my Str $start = ~$<start>;
        given $start {
            when '~root' { $Dir ~~ s! ^^ '~' !\/!; }
            default {
                my Str @candidates = dir('/home', test => { "/home/$_".IO.d && $_ ne '.' && $_ ne '..' }).map: { $_.Str };
                my Str $start_d = $start.substr(1);
                my Str @cands = @candidates.grep: { rx/ \/ $start_d $$ / };
                if @cands == 1 {
                    my Str $candidate = @cands[0];
                    $Dir ~~ s! ^^ $start \/ !$candidate\/!;
                } else {
                    "cannot resolve $start".say;
                    return $dir;
                }
            }
        }
    }
    $Dir = "$home/$Dir" if $relitive-to-home && $Dir !~~ rx! ^^ \/ !;
    #$Dir.say;
    return $Dir;
} # multi sub resolve-dir(Str:D $dir, Bool $relitive-to-home = True --> Str) is export #

sub parse-string(Str:D $str-lit is copy, UInt :$count is copy = 0, Str:D :$opening-quote = '"',
                                                                   Str:D :$closing-quote = '"',
                                                                   Bool :$interpretable = True,
                                                                   ErrorAction:D :$action = ignoreError --> Str:D) is export {
    $count++;
    die-handle("$?FILE\[$?LINE\] Error: parse-string() recursion too deep \$count: $count exceeds \$parse-max $parse-max") if $count > $parse-max;
    my Str:D $result = '';
    my $begin-brace = '{';
    my $end-brace   = '}';
    my Str:D $pattern0-str = qq[ <-[\$\\$begin-brace]> ];
    my Regex $pattern0     = rx/ <$pattern0-str> /;
    my Str:D $pattern1-str = qq[ <[\$\\$begin-brace]> ];
    my Regex $pattern1     = rx/ <$pattern1-str> /;
    while $str-lit ~~ rx/ ^ $<start> = [ [ $pattern0 ]* ] [ $<bs> = [ $pattern1 ] $<next> = [ . ] ]? $<tail> = [ .* ] $ / {
        with ~$<start> {
            $result ~= ~$<start>;
        }
        with ~$<tail> {
            $str-lit = ~$<tail>;
        } else {
            $str-lit = '';
        }
        with ~$<bs> {
            given ~$<bs> {
                when '\\' {
                    with ~$<next> {
                        given ~$<next> {
                            when '0' { $result            ~= "\0"; }
                            when 'a' { $result            ~= "\a"; }
                            when 'b' { $result            ~= "\b"; }
                            when 'e' { $result            ~= "\e"; }
                            when 'f' { $result            ~= "\f"; }
                            when 'n' { $result            ~= "\n"; }
                            when 'r' { $result            ~= "\r"; }
                            when 't' { $result            ~= "\t"; }
                            when '$' { $result            ~= '$'; }
                            when rx/ <[\{\[\(\<«»\>\)\]\}]> / { $result ~= ~$<next>; }
                            when $opening-quote { $result ~= $opening-quote; }
                            when $closing-quote { $result ~= $closing-quote; }
                            default { $result             ~= ~$<next>; }
                        } # given ~$<next> #
                    } # with ~$<next> #
                } # when '\\' #
                when '$' {
                    if $interpretable {
                        my $tmp = ~$<next> ~ $str-lit;
                        if $tmp ~~ rx/ ^ $<var> = [ [ $twigil ]? $id-pattern ] $<rest> = [ .* ] $ / {
                            my Str:D $var  = '$' ~ ~$<var>;
                            my %spec = resolve-symbol($var);
                            unless %spec«null» {
                                if %spec«type-spec» eq 'Str' {
                                    $result ~= parse-string(%spec«value», :$count, :$opening-quote, :$closing-quote, :$interpretable);
                                } else {
                                    $result ~= %spec«value».Str;
                                }
                            }
                            with ~$<rest> {
                                $str-lit = ~$<rest>;
                            } else {
                                $str-lit = '';
                            }
                        } else {
                            my $var = '$' ~ ~$<next>;
                            my %spec = resolve-symbol($var);
                            unless %spec«null» {
                                if %spec«type-spec» eq 'Str' {
                                    $result ~= parse-string(%spec«value», :$count, :$opening-quote, :$closing-quote, :$interpretable);
                                } else {
                                    $result ~= %spec«value».Str;
                                }
                            }
                            given $action {
                                when ignoreError { #`«$result ~= '$' ~ ~$<next>;» }
                                when leaveVar    { $result ~= '$' ~ ~$<next>; }
                                when throwExcept {
                                    die-handle(qq[$?FILE\[$?LINE\] Error: variable \`$var' not found.]);
                                }
                            }
                        }
                    } else {
                        $result ~= '$';
                        with ~$<next> {
                            $str-lit = ~$<next> ~ $str-lit;
                        }
                    }
                }
                when $begin-brace #`« now look for an unquoted '$end-brace' » {
                    my $tmp = ~$<next> ~ $str-lit;
                    if $interpretable {
                        if $tmp ~~ rx/ ^ $<expr> = [ .*  ] <!before [ [ '\\\\' ]* '\\' ] > $begin-brace $<rest> = [ .* ] $ / {
                            my Str:D $expr = ~$<expr> // '';
                            my Str   $rest = ~$<rest>;
                            $result ~= eval-expr($expr);
                            $str-lit = $rest with $rest;
                        } else {
                            given $action {
                                when ignoreError {
                                    $result ~= eval-expr($tmp);
                                    $str-lit = '';
                                    last;
                                }
                                when leaveVar    {
                                    $result ~= $tmp;
                                    $str-lit = '';
                                    last;
                                }
                                when throwExcept {
                                    die-handle("$?FILE\[$?LINE\] unclosed \`{~$<bs>}'!");
                                }
                            } # given $action #
                        } # if $tmp ~~ rx/ ^ $<expr> = [ .*  ] <!before [ [ '\\\\' ]* '\\' ] > $begin-brace $<rest> = [ .* ] $ / ... else ... #
                    } else { # if $interpretable #
                        $result ~= '{';
                        if ~$<next> eq '}' {
                            $result ~= ~$<next>;
                        } else {
                            $str-lit = $tmp;
                        }
                    } # if $interpretable #
                } #`««« when $begin-brace #`« now look for an unquoted '$end-brace' » »»»
            } # given ~$<bs> #
        } # with ~$<bs> #
    } #`««« while $str-lit ~~ rx/ ^ $<start> = [ <-[\\\${]>* ] [ $<bs> = [ '\\\${' ] $<next> = [ .? ] $<tail> = [ .* ] ]? $ /
                                                                         #`« look for '\' '}' or '$' lack of a closing '}' is an error » »»»
    return $result;
} #`««« sub parse-string(Str:D $str-lit is copy, UInt :$count is copy = 0, Str:D :$opening-quote = '"',
                                                                   Str:D :$closing-quote = '"',
                                                                   Bool :$interpretable = True,
                                                                   ErrorAction:D :$action --> Str:D) is export »»»
