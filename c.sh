#! /bin/bash --
# by pts@fazekas.hu at Fri Nov 26 22:15:42 CET 2010
set -ex
export PREFIX=/usr/local/google/more-compiler-i686/bin/i686-
export CC='/usr/local/google/more-compiler-i686/bin/i686-gcc -static'
if ! test -f perl-5.10.1.tar.gz.downloaded; then
  wget -c -O perl-5.10.1.tar.gz http://www.cpan.org/src/perl-5.10.1.tar.gz
  touch perl-5.10.1.tar.gz.downloaded
fi
rm -rf mkperl.tmp
mkdir mkperl.tmp
rm -rf perl-5.10.1
(cd mkperl.tmp && tar xzf ../perl-5.10.1.tar.gz)
mv mkperl.tmp/perl-* mkperl.tmp/perlsrc
chmod +w mkperl.tmp/perlsrc/miniperlmain.c mkperl.tmp/perlsrc/perl.c mkperl.tmp/perlsrc/Configure
(cd mkperl.tmp/perlsrc && patch -p1 <../../pts-perl-static-5.10.1.patch)
cp Configure mkperl.tmp/perlsrc/Configure
(cd mkperl.tmp/perlsrc && ./configure.gnu)
echo 'char mini_preamble[1] = "";' >mkperl.tmp/perlsrc/mini_preamble.h
(cd mkperl.tmp/perlsrc && make miniperl perlmain.c)
mkperl.tmp/perlsrc/miniperl -0777 -ne '$_="BEGIN{eval q\0$_\0}"; my $L=length($_); my%H=("\n"=>"\\n","\0"=>"\\0");s@([\\"\n\0])@exists$H{$1}?$H{$1}:"\\$1"@ge;print"const char mini_preamble[$L] = \"$_\";\n"' <mini-prelude-5.10.1.pm >mkperl.tmp/perlsrc/mini_preamble.h
mkperl.tmp/perlsrc/miniperl -pi -e 's@(do_add_mini_preamble =) 0;@$1 1;@g' mkperl.tmp/perlsrc/perlmain.c
(cd mkperl.tmp/perlsrc && make perl)
cp mkperl.tmp/perlsrc/perl perl-5.10.1
${PREFIX}strip perl-5.10.1
ls -l perl-5.10.1
: All OK.
