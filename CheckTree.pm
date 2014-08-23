
package File::CheckTree;

use 5.006;
use warnings;
use strict;
use Exporter;
use Cwd qw(abs_path cwd);
use File::Spec;

our $VERSION = '4.4';
our @ISA     = qw(Exporter);
our @EXPORT  = qw(validate check_tree check_tree_list check_tree_parse);
our @EXPORT_OK = qw(explain_tests);

=head1 NAME

validate - run many filetest checks on a tree

=head1 SYNOPSIS

    use File::NewCheckTree;

    my $tests_string = q{
        /vmunix                 -e || die
        /boot                   -e || die
        /bin                    cd
            sh                  -ex
            sh                  !-ug
        /usr                    -d || warn "What happened to $file?\n"
    });

    my @tests_array = (
        [ '/vmunix', '-e || die' ],
        [ '/boot',   '-e || die' ],
        [ '/bin',    'cd' ],
            [ 'sh',     '-ex'  ],
            [ 'sh',     '!-ug' ],
    );

    $num_warnings = check_tree($tests_string);

    $num_warnings = check_tree(\@tests_array);


=head1 DESCRIPTION
This is a new, improved (IMHO) version of Perl module, File::CheckTree.

The intact original File::CheckTree documentation follows.
After that, there is a description of the changes from
Paul Grassie's version 4.4, along with some rationale.

The validate() routine takes a single multiline string consisting of
directives, each containing a filename plus a file test to try on it.
(The file test may also be a "cd", causing subsequent relative filenames
to be interpreted relative to that directory.)  After the file test
you may put C<|| die> to make it a fatal error if the file test fails.
The default is C<|| warn>.  The file test may optionally have a "!' prepended
to test for the opposite condition.  If you do a cd and then list some
relative filenames, you may want to indent them slightly for readability.
If you supply your own die() or warn() message, you can use $file to
interpolate the filename.

Filetests may be bunched:  "-rwx" tests for all of C<-r>, C<-w>, and C<-x>.
Only the first failed test of the bunch will produce a warning.

The routine returns the number of warnings issued.

=head1 AUTHOR

File::CheckTree was derived from lib/validate.pl which was
written by Larry Wall.
Revised by Paul Grassie <F<grassie@perl.com>> in 2002.
Revised by Guy Shaw <F<gshaw@acm.org>> in 2014.

=head1 HISTORY

File::CheckTree used to not display fatal error messages.
It used to count only those warnings produced by a generic C<|| warn>
(and not those in which the user supplied the message).  In addition,
the validate() routine would leave the user program in whatever
directory was last entered through the use of "cd" directives.
These bugs were fixed during the development of perl 5.8.
The first fixed version of File::CheckTree was 4.2.

=head1 NEW IN THIS EDITION
The main changes are:

1) Alternative interfaces;

2) More suitable for tests that have been created dynamically;

3) Automatic management of duplicative error messages;

=head2 Why new interfaces?
The original validate() function looks fine, at first.
If you lay out the big string of test specifications,
you can even indent things to make it clear what tests
are inside a subdirectory.  But, my real-world experience
is that test of prerequisite files are rarely static,
and known in advance.  The name of some top-level directory
might have come from the environment, or command-line
arguments, or a configuration file.  Other tests are
relative to that directory.

One can always build a big string.  Perl has many
ways to do that.  But modern Perl also has arrays,
references, objects, and complex data structures.
Sometimes, it is more appropriate to pass in a set
of test using an array of lines or an array of
{ filename, test } pairs.

Under the covers, the big string passed into
validate() get chopped up into individual lines.
So, the new interfaces to pass an array of lines,
and to pass in an array of pairs, comes almost for
free, in terms of implementation costs.
The functionality was there; it is just that there
was no way to get at it directly.  It seems a shame
to have functionaly hidden.  So close, yet far away.

I imagine that if validate() were a more recent
invention, it would have had interfaces that include
"Modern Perl" data types.

=head2 Control of error messages
Whenever a test fails, if the failure was due
to a problem with any directory in a given path,
and not just the final component, then the top-most
directory prefix that is responsible for the error
is recorded.  Error messages are suppressed for
any further tests that fail and that involve a
directory prefix for which an error has already
been reported.  But, further tests are performed,
and errors are reported for tests that are independent
of the fault cones of known bad directories.

=cut

my %Val_Message = (
    'r' => "is not readable by uid $>.",
    'w' => "is not writable by uid $>.",
    'x' => "is not executable by uid $>.",
    'o' => "is not owned by uid $>.",
    'R' => "is not readable by you.",
    'W' => "is not writable by you.",
    'X' => "is not executable by you.",
    'O' => "is not owned by you.",
    'e' => "does not exist.",
    'z' => "does not have zero size.",
    's' => "does not have non-zero size.",
    'f' => "is not a plain file.",
    'd' => "is not a directory.",
    'l' => "is not a symbolic link.",
    'p' => "is not a named pipe (FIFO).",
    'S' => "is not a socket.",
    'b' => "is not a block special file.",
    'c' => "is not a character special file.",
    'u' => "does not have the setuid bit set.",
    'g' => "does not have the setgid bit set.",
    'k' => "does not have the sticky bit set.",
    'T' => "is not a text file.",
    'B' => "is not a binary file."
);

my %fault_dirs = ();
my $Warnings;
my $options;

sub explain_tests {
    my ($fh, $pfx) = @_;

    print {$fh} $pfx, $_, '  ', $Val_Message{$_}, "\n"  for sort keys %Val_Message;
}

sub record_fault_cone {
    my ($file) = @_;
    my $abs_file;
    my ($vol, $dir, $sfn);
    my $prev_dir;

    $abs_file = abs_path($file);
    $abs_file = $file;
    ($vol, $dir, $sfn) = File::Spec->splitpath($abs_file);
    $dir =~ s{/$}{};    # XXX Unix-specific
    
# - print "file=$file\n";
# - print "abs_file=$abs_file\n";
# - print "dir=$dir, sfn=$sfn\n";
    $prev_dir = $dir;
    while (defined($dir) && $dir ne '' && ! -d $dir) {
        # - print $dir, "\n";
        $prev_dir = $dir;
        ($vol, $dir, $sfn) = File::Spec->splitpath($dir);
        $dir =~ s{/$}{};    # XXX Unix-specific
    }

    return if (-d $prev_dir);

    $fault_dirs{$prev_dir} = 1;

    if (! -e $prev_dir) {
        warn "$prev_dir does not exist.\n";
    }
    elsif (! -d $prev_dir) {
        warn "$prev_dir is not a directory.\n";
        system('ls', '-dlh', $prev_dir);
    }
}

sub in_fault_cone {
    my ($file) = @_;
    my $dir;

    for $dir (keys %fault_dirs) {
        my $pfx;

        next  if (length($dir) > length($file));
        $pfx = substr($file, 0, length($dir) + 1);
        $pfx =~ s{/$}{};
        return 1  if ($dir eq $pfx);
    }
    return 0;
}

sub valmess {
    my ($disposition, $test, $file) = @_;
    my $ferror;
    my $exists;

    return if ($Warnings && in_fault_cone($file));
    if ($test =~ / ^ (!?) -(\w) \s* $ /x) {
        my ($neg, $ftype) = ($1, $2);

        $ferror = "$file $Val_Message{$ftype}";

        if ($neg eq '!') {
            $ferror =~ s/ is not / should not be / ||
            $ferror =~ s/ does not / should not / ||
            $ferror =~ s/ not / /;
        }
    }
    else {
        $ferror = "Can't do $test $file.\n";
    }

    $exists = -e $file;
    if (exists($options->{ls}) && $exists) {
        system('ls', '-dlh', $file);
    }
    die "$ferror\n" if $disposition eq 'die';
    warn "$ferror\n";
    if (!$exists) {
        record_fault_cone($file);
    }
}

# Given a list of strings,
# return a reference to a list of [ file, test ] pairs.
# Little or no testing is done of the internal structure and
# validity of the test.  check_tree() will do that work.
#
sub check_tree_list {
    my @pairs = ();

    for my $check ($@) {
        my ($file, $test);

        # skip blanks/comments
        next if $check =~ /^\s*#/ || $check =~ /^\s*$/;

        # split a line like "/foo -r || die"
        # so that $file is "/foo", $test is "-rwx || die"
        # so that $file is "/foo", $test is "-r || die"
        # (making special allowance for quoted filenames).
        if ($check =~ m/^\s*"([^"]+)"\s+(.*?)\s*$/ or
            $check =~ m/^\s*'([^']+)'\s+(.*?)\s*$/ or
            $check =~ m/^\s*(\S+?)\s+(\S.*?)\s*$/)
        {
            ($file, $test) = ($1, $2);
        }
        else {
            die "Malformed line: '$check'";
        }
        ($file, $test) = split(' ', $check, 2);   # special whitespace split
        push(@pairs, [ $file, $test ]);
    }

    return \@pairs;
}
 
 
# Given a string suitable for validate(),
# return a reference to a list of [ file, test ] pairs.
# Little or no testing is done of the internal structure and
# validity of the test.  check_tree() will do that work.
#
sub check_tree_parse {
    return check_tree_list(split /\n/, $_[0]);
}

# Check a list of tests, somewhat like File::CheckTree::validate(),
# but with multiple ways of accepting arguments and with some options.
#
# The tests can be given as:
#   1. A reference to an array of [ file, test ] pairs;
#   2. A reference to a hash of { file => test };
#   3. A string, just like that given to validate().
#
sub check_tree {
    my $args_type;
    my $tests;

    $args_type = ref $_[0];
    if (!defined($args_type) || $args_type eq '') {
        if (@_ > 1) {
            # More than 1 argument, and $_[0] is not a ref.
            # Arguments are individual tests.
            #
            $tests = check_tree_parse(@_);
        }
        else {
            $tests = check_tree_list(@_);
        }
    }
    elsif ($args_type eq 'ARRAY') {
        $tests = $_[0];
        $options = $_[1];
    }
    else {
        die(
            "check_tree(", join (', ', map { ref $_ || "\"$_\"" } @_), "):\n",
            "    Bad argument signature.\n",
            "    \$args_type = ${args_type}.\n",
        );
    }

    defined($options)  or  $options = { };

    $options->{ls} = 1;      # XXX for testing purposes only

    my ($starting_dir, $file, $test, $cwd, $oldwarnings);

    $starting_dir = cwd();

    $cwd = "";
    $Warnings = 0;

    foreach my $check (@$tests) {
        my ($file, $test) = @$check;
        my ($testlist, @testlist);

        # Todo:
        # should probably check for invalid directives and die
        # but earlier versions of File::CheckTree did not do this either

        # change a $test like "!-ug || die" to "!-Z || die",
        # capturing the bundled tests (e.g. "ug") in $2
        if ($test =~ s/ ^ (!?-) (\w{2,}) \b /$1Z/x) {
            $testlist = $2;
            # split bundled tests, e.g. "ug" to 'u', 'g'
            @testlist = split(//, $testlist);
        }
        else {
            # put in placeholder Z for stand-alone test
            @testlist = ('Z');
        }

        # will compare these two later to stop on 1st warning w/in a bundle
        $oldwarnings = $Warnings;

        foreach my $one (@testlist) {
            # examples of $test: "!-Z || die" or "-w || warn"
            my $this = $test;

            # expand relative $file to full pathname if preceded by cd directive
            $file = File::Spec->catfile($cwd, $file)
                    if $cwd && !File::Spec->file_name_is_absolute($file);

            # put filename in after the test operator
            $this =~ s/(-\w\b)/$1 "\$file"/g;

            # change the "-Z" representing a bundle with the $one test
            $this =~ s/-Z/-$one/;

            # if it's a "cd" directive...
            if ($this =~ /^cd\b/) {
                # add "|| die ..."
                $this .= ' || die "cannot cd to $file\n"';
                # expand "cd" directive with directory name
                $this =~ s/\bcd\b/chdir(\$cwd = '$file')/;
            }
            else {
                # add "|| warn" as a default disposition
                $this .= ' || warn' unless $this =~ /\|\|/;

                # change a generic ".. || die" or ".. || warn"
                # to call valmess instead of die/warn directly
                # valmess will look up the error message from %Val_Message
                $this =~ s/ ^ ( (\S+) \s+ \S+ ) \s* \|\| \s* (die|warn) \s* $
                          /$1 || valmess('$3', '$2', \$file)/x;
            }

            {
                # count warnings, either from valmess or '-r || warn "my msg"'
                # also, call any pre-existing signal handler for __WARN__
                my $orig_sigwarn = $SIG{__WARN__};
                local $SIG{__WARN__} = sub {
                    ++$Warnings;
                    if ( $orig_sigwarn ) {
                        $orig_sigwarn->(@_);
                    }
                    else {
                        warn "@_";
                    }
                };

                # do the test
                eval $this;

                # re-raise an exception caused by a "... || die" test
                if (my $err = $@) {
                    # in case of any cd directives, return from whence we came
                    if ($starting_dir ne cwd()) {
                        chdir($starting_dir) || die "$starting_dir: $!";
                    }
                    die $err;
                }
            }

            # stop on 1st warning within a bundle of tests
            last if $Warnings > $oldwarnings;
        }
    }

    # in case of any cd directives, return from whence we came
    if ($starting_dir ne cwd()) {
        chdir($starting_dir) || die "chdir $starting_dir: $!";
    }

    return $Warnings;
}

sub validate {
    return check_tree(@_);
}

1;
