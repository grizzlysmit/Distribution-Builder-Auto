use v6.d;
use File::Directory::Tree;
use Gzz::Auto::Common;
use Gzz::Auto::Grammar;
unit class Distribution::Builder::Auto:ver<0.0.1>:auth<Francis Grizzly Smit (grizzly@smit.id.au)>;

=begin pod

=head1 Distribution::Builder::Auto

=begin head2

Table of Contents

=end head2

=item1 L<NAME|#name>
=item1 L<AUTHOR|#author>
=item1 L<VERSION|#version>
=item1 L<TITLE|#title>
=item1 L<SUBTITLE|#subtitle>
=item1 L<COPYRIGHT|#copyright>
=item1 L<Introduction|#introduction>

=NAME Distribution::Builder::Auto 
=AUTHOR Francis Grizzly Smit (grizzly@smit.id.au)
=VERSION 0.0.2
=TITLE Distribution::Builder::Auto
=SUBTITLE A set of B<Raku> module for running fairly arbitary scripts inside the META6.json files B«build» key.

=COPYRIGHT This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0 L<LICENSE|https://github.com/grizzlysmit/Distribution-Builder-Auto/blob/main/LICENSE>


L<Top of Document|#table-of-contents>

=head2 Introduction

This is a set of B<Raku> Modules for running faily arbitary scripts durring the B<Raku> B<zef> install process.



=end pod

has %.meta;


method cmds(IO::Handle:D $handle, Bool:D :$debug = False, *@rest --> Bool:D) {
}

method scope(IO::Handle:D $handle, %frame, Bool:D :$debug = False, *@rest --> Bool:D) {
    my Bool:D $result = False;
    my Proc $r;
    symbol-table-add($handle, %frame, :$debug); 
    for @rest -> @cmd is copy {
        my Str:D $first = @cmd.shift;
        given $first {
            when 'for' {
                my Str $identifier;
                my Str $rest;
                die-handle("$?FILE\[$?LINE\] Error: \`for' expected arguments got nothing") unless @cmd.tail(*-1);
                my Str $arg = @cmd.shift;
                die-handle("$?FILE\[$?LINE\] Error: invalid argument {$arg.raku} to \`for'.") without $arg;
                die-handle("$?FILE\[$?LINE\] Error: invalid argument empty string or blank spaces supplied as argument to \`for'.") if $arg.trim eq '';
                die-handle("$?FILE\[$?LINE\] Error: invalid argument to \`for' expected \`Str' ref to Array got {$arg.raku} of type \`{$arg.^name}'.") unless $arg.does(Stringy);
                $arg = resolve($handle, $arg, :$debug);
                if $arg.does(Str) {
                    given $arg {
                        when rx/ ^ $<identifier> = [ '@' [ $twigil ]? $id-pattern ] $<access-spec> = [ $qualify-access ] $ / {
                            $identifier  = ~($<identifier>)         // Str;
                            my Str $access-spec = ~($<access-spec>) // Str;
                            my %spec     = resolve-symbol($identifier);
                            my @value;
                            if %spec«null» {
                                $result &&= False;
                                die-handle(qq[$?FILE\[$?LINE\] Error: for called on a null symbol]);
                            } else {
                                given %spec«type-spec» {
                                    when rx/ ^ $<type> = [ [ $type-pattern ]? ] \s+ 'Array' $<type2> = [ [ '[' $type-pattern ']' ]? ] $ / {
                                        my @res = |@(%spec«value»);
                                        my $peek = @cmd[0];
                                        @cmd.shift if $peek eq '->'; # skip punct #
                                        my $place-holder = @cmd.pop;
                                        my @args = self.access-array($handle, :$debug, @res, $access-spec);
                                        for @args -> %arg {
                                            symbol-table-add($handle, { $place-holder => %arg }, :$debug); 
                                            if self.scope($handle, %arg, :$debug, |@cmd) {
                                                $handle.say: "$?FILE\[$?LINE\] for loop succeeded" if $debug;
                                                $result &&= True;
                                            } else {
                                                $handle.say: "$?FILE\[$?LINE\] for loop failed" if $debug;
                                                $result &&= False;
                                            }
                                            pop-symbol-table; # pop { $place-holder => %arg } #
                                        } # for @args -> %arg #
                                    } # when rx/ ^ $<type> = [ [ $type-pattern ]? ] \s+ 'Array' $<type2> = [ [ '[' $type-pattern ']' ]? ] $ / #
                                } # given %spec«type-spec» #
                            } # if %spec«null» ... else ... #
                        } # when rx/ ^ $<identifier> = [ '@' [ $twigil ]? $id-pattern ] $<access-spec> = [ $qualify-access ] $ / #
                        default {
                            die-handle("$?FILE\[$?LINE\] Syntax error: for should be followed by an array,  found: \`$arg'");
                        }
                    } # given $arg #
                } elsif $arg.does(List) {
                    die-handle("$?FILE\[$?LINE\] Error: 'for' expects an array ref you supplied an array of commands.");
                } else { # if $arg.does(Str) #
                    die-handle("$?FILE\[$?LINE\] Error: 'for' expects an array got {$arg.^name}");
                } # if $arg.does(Str) ... else ... #
                $result &&= True;
            } # when 'for' #
            when 'cd'|'chdir' {
                my Str $identifier;
                my Str:D $arg = @cmd.shift;
                given $arg {
                    when rx/ ^ $<identifier> = [ [ '$' [ $twigil ]? $id-pattern ]? ] $ / {
                        $identifier = ~($<identifier>) // Str;
                        with $identifier {
                            my %spec    = resolve-symbol($identifier);
                            my Str:D $value = '';
                            if %spec«null» {
                                die-handle(qq[$?FILE\[$?LINE\] Error: for called on a null symbol]);
                            } else {
                                $value = resolve($handle, %spec«value», :$debug);
                                $result &&= $value.IO.chdir.Bool;
                                $handle.print("$?FILE\[$?LINE\] pwd == ") if $debug; run('pwd', :out($handle), :err($handle)) if $debug; $handle.say('') if $debug;
                            }
                        }
                    }
                }
            } # when 'cd'|'chdir' #
            when 'mkdir' {
                my Str $identifier;
                my Str:D $arg = @cmd.shift;
                given $arg {
                    when rx/ ^ $<identifier> = [ [ '$' [ $twigil ]? $id-pattern ]? ] $ / {
                        $identifier = ~($<identifier>) // Str;
                        with $identifier {
                            my %spec    = resolve-symbol($identifier);
                            my Str:D $value = '';
                            if %spec«null» {
                                die-handle(qq[$?FILE\[$?LINE\] Error: for called on a null symbol]);
                            } else {
                                $value = resolve($handle, %spec«value», :$debug);
                                $result &&= $value.IO.mkdir.Bool;
                                $handle.print("$?FILE\[$?LINE\] pwd == ") if $debug; run('pwd', :out($handle), :err($handle)) if $debug; $handle.say('') if $debug;
                            }
                        }
                    }
                    when rx/ ^ $path-pattern $ / {
                        $result &&= $arg.IO.mkdir.Bool;
                    }
                    default { 
                        $handle.say: "Error: bad value for path, expected path or scalar, got \`$arg'.";
                        die-handle(qq[$?FILE\[$?LINE\] Error: bad value for path, expected path or scalar, got \`$arg'.]);
                    }
                }
            } # when $first ~~ 'mkdir' #
            when 'debug' {
                $result &&= self.cmds($handle, :$debug, |@cmd) if $debug;
            } # when 'debug' #
            when 'pwd' {
                my Str $identifier;
                if @cmd {
                    $r = run('pwd', :out($handle), :err($handle));
                } else {
                    die-handle(qq[$?FILE\[$?LINE\] Error: extra arguments for pwd expected 0 got {+@cmd}]);
                }
            } # when 'pwd' #
            when 'rmtree' {
                my Str $identifier;
                my Str:D $arg = @cmd.shift;
                given $arg {
                    when rx/ ^ $<identifier> = [ [ '$' [ $twigil ]? $id-pattern ]? ] $ / {
                        $identifier = ~($<identifier>) // Str;
                        with $identifier {
                            my %spec    = resolve-symbol($identifier);
                            my Str:D $value = '';
                            if %spec«null» {
                                die-handle(qq[$?FILE\[$?LINE\] Error: for called on a null symbol]);
                            } else {
                                $value = resolve($handle, %spec«value», :$debug);
                                $result &&= $value.IO.mkdir.Bool;
                                $handle.print("$?FILE\[$?LINE\] pwd == ") if $debug; run('pwd', :out($handle), :err($handle)) if $debug; $handle.say('') if $debug;
                            }
                        }
                    }
                }
            } # when 'rmtree' #
            when 'pwd' {
                my Str $identifier;
                if @cmd {
                    die-handle(qq[$?FILE\[$?LINE\] Error: extra arguments for pwd expected 0 got {+@cmd}]);
                } else {
                    $r = run('pwd', :out($handle), :err($handle));
                }
            } # when $first ~~ 'cd' #
            when 'pwd' {
                my Str $identifier;
                if @cmd {
                    $r = run('pwd', :out($handle), :err($handle));
                } else {
                    die-handle(qq[$?FILE\[$?LINE\] Error: extra arguments for pwd expected 0 got {+@cmd}]);
                }
            } # when $first ~~ 'cd' #
            when 'pwd' {
                my Str $identifier;
                if @cmd {
                    $r = run('pwd', :out($handle), :err($handle));
                } else {
                    die-handle(qq[$?FILE\[$?LINE\] Error: extra arguments for pwd expected 0 got {+@cmd}]);
                }
            } # when $first ~~ 'cd' #
            when 'pwd' {
                my Str $identifier;
                if @cmd {
                    $r = run('pwd', :out($handle), :err($handle));
                } else {
                    die-handle(qq[$?FILE\[$?LINE\] Error: extra arguments for pwd expected 0 got {+@cmd}]);
                }
            } # when $first ~~ 'cd' #
            when 'pwd' {
                my Str $identifier;
                if @cmd {
                    $r = run('pwd', :out($handle), :err($handle));
                } else {
                    die-handle(qq[$?FILE\[$?LINE\] Error: extra arguments for pwd expected 0 got {+@cmd}]);
                }
            } # when $first ~~ 'cd' #
        } # given $first #
    } # for @rest -> @cmd is copy #
    pop-symbol-table; # remove %frame #
    return $result;
}




method build(IO() $work-dir = $*CWD --> Bool:D) {
    my Bool:D $debug = False;
    with %!meta«build»«debug» {
        $debug = %!meta«build»«debug».Bool;
    }
    my IO::Path:D $log = "/dev/null".IO;
    with %!meta«build»«log» {
        my Str:D $tmp = %!meta«build»«log»;
        if $tmp eq '/dev/tty' {
            $log = $tmp.IO;
        } else {
            my IO::Handle:D $handle-tmp = "/dev/tty".IO.open: :append, :mode<rw>, :out-buffer(False);
            $log = resolve-dir($tmp, $handle-tmp).IO;
        }
    }
    $log.dirname.IO.mkdir if $debug && $log.path !~~ rx@ ^^ '/dev/' .* $$ @;
    #my $log = "/dev/tty".IO;
    #my IO::Handle:D $handle = $log.open: :append, :create, :mode<rw>;
    my Bool:D $create = $log !~~ rx@ ^^ '/dev/' .* $$ @;
    my IO::Handle:D $handle = $log.open: :append, :$create, :mode<rw>, :out-buffer(False);
    if $log ~~ rx@ ^ '/dev/tty' $ @ {
        $*OUT.open: :append, :mode<rw>, :out-buffer(False);
        $*ERR.open: :append, :mode<rw>, :out-buffer(False);
    } else {
        $*OUT = $handle;
        $*ERR = $handle;
    }
    
    my Proc $r;
    $handle.say: '%!meta = ', %!meta.raku if $debug;
    my %meta = %!meta<build>;
    
    common-init($handle, %meta, $debug);
    $handle.say: '%meta = ', %meta.raku if $debug;
    #«««
    die-handle("$?FILE\[$?LINE\] You need CMake to install this package!") unless shell 'which cmake';
    die-handle("$?FILE\[$?LINE\] You need Make to install this package!") unless shell 'which make';
    die-handle(qq[$?FILE\[$?LINE\] field "actions" must be supplied inside field "build"]) without %meta«actions»;
    die-handle(qq[$?FILE\[$?LINE\] field "%vars" must be supplied inside field "«build»«actions»"]) without %meta«actions»<%vars>;
    die-handle(qq[$?FILE\[$?LINE\] field "&before" must be supplied inside field "«build»«actions»"]) without %meta«actions»<&before>;
    die-handle(qq[$?FILE\[$?LINE\] field "@body-paths" must be supplied inside field "«build»«actions»"]) without %meta«actions»<@body-paths>;
    die-handle(qq[$?FILE\[$?LINE\] field "&body" must be supplied inside field "«build»«actions»"]) without %meta«actions»<&body>;
    die-handle(qq[$?FILE\[$?LINE\] field "&after" must be supplied inside field "«build»«actions»"]) without %meta«actions»<&after>;
    #»»»

    True;
} # method build(IO() $work-dir = $*CWD)  #
