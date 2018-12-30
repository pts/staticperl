staticperl: statically linked Perl 5.10 for i386 Linux and FreeBSD
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
staticperl is a stripped-down version of Perl 5.10 precompiled and statically
linked for Linux i386 (CPU model i686) and amd64 systems. staticperl has all
C and Perl code embedded in the executable binary, so it doesn't read any
external files (except for /dev/urandom and /dev/null) to operate.
Typical use cases of staticperl are embedded and rescue Linux systems (e.g.
where glibc is not available) and Docker images.

staticperl is based on Perl 5.10.1, but it contains only a few standard Perl
modules (e.g. integer, warnings, File::Glob and Cwd). Most notably,
Encoding, Fcntl and Socket are missing. It's possible but tricky to modify
the compilation script (c.sh) to add more modules. It's possible to add more
Perl code, see below how.

staticperl is linked against uClibc using pts-xstatic
(https://github.com/pts/pts-clang-xstatic/blob/master/README.pts-xstatic.txt),
that's why the binary size is so small.

Usage
~~~~~
On a Linux i386 or amd64 system, run

  $ wget -O  staticperl http://github.com/pts/staticperl/releases/download/v2/staticperl-5.10.1.v2
  $ chmod +x staticperl
  $ ./staticperl -e 'print "Hello, World!\n"
  Hello, World!

How to add more Perl modules
~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Use this command to get Perl code defining the Perl modules within the
staticperl executable:

  $ ./staticperl-5.10.1 -e0 -mStaticPreamble=get >mypreamble.pm

You can edit (extend) the file mypreamble.pm, and then update the
executable using this command:

  $ ./staticperl-5.10.1 -e0 -mStaticPreamble=set stdin <mypreamble.pm

Be careful, syntax errors are not checked, and thus a wrong preamble may
render your staticperl binary useless.

Please note that comments in the beginning of (possibly indented) lines are
removed as part of the =set operation above.

Please note that getting and adding Perl modules (with -mStaticPreamble=...)
works only if the executable isn't compressed (e.g. with UPX).

The initial preamble is the concatenation of the files in the repository:

  $ cat StaticPreamble.pm preamble-5.10.1.pm >mypreamble.pm

Please note that it's not possible to add C extensions (.xs, .so) to
staticperl without recompiling it, i.e. modifying and running c.sh.

Executable compression
`~~~~~~~~~~~~~~~~~~~~~
It's possible to compress the staticperl executable with UPX. If done so
(with `upx --best --lzma'), the file size goes down from 1.102 MiB to 0.416
MiB.

Please note that getting and adding Perl modules (with -mStaticPreamble=...)
works only if the executable isn't compressed (e.g. with UPX). If it is, you
need to decompress it first.

Alternatives
~~~~~~~~~~~~
There is another project called staticperl with automation for adding
arbitrary Perl modules and C extensions from CPAN:
https://metacpan.org/pod/distribution/App-Staticperl/staticperl.pod

__END__
