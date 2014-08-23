
This is a new, improved version of the Perl module, `File::CheckTree`,
which is, in turn, derived from the core Perl function, `validate()`.


AUTHOR
------
File::CheckTree was derived from lib/validate.pl which was
written by Larry Wall.
Revised by Paul Grassie <F<grassie@perl.com>> in 2002.
Revised by Guy Shaw <F<gshaw@acm.org>> in 2014.

IMPROVEMENTS
------------

The main changes are:

    1) Alternative interfaces;

    2) More suitable for tests that have been created dynamically;

    3) Automatic management of duplicative error messages;


Why new interfaces?
-------------------
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


Control of error messages
-------------------------
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


-- Guy Shaw
   Novice.Sandbox@yahoo.com

