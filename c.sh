#! /bin/bash --
# by pts@fazekas.hu at Thu Dec 27 15:35:44 CET 2018
set -ex

test -f preamble-5.10.1.pm
test -f patch-5.10.1.patch
test -f config-5.10.1.sh
test -f StaticPreamble.pm

if ! test -f perl-5.10.1.tar.gz; then
  wget -O perl-5.10.1.tar.gz.tmp http://www.cpan.org/src/perl-5.10.1.tar.gz
  mv perl-5.10.1.tar.gz.tmp perl-5.10.1.tar.gz
fi
if ! test -f pts-xstatic-latest.sfx.7z; then
  wget -O pts-xstatic-latest.sfx.7z.tmp http://pts.50.hu/files/pts-xstatic/pts-xstatic-latest.sfx.7z
  chmod +x pts-xstatic-latest.sfx.7z.tmp
  mv pts-xstatic-latest.sfx.7z.tmp pts-xstatic-latest.sfx.7z
fi

if ! test -f pts_chroot_env_qq.sh; then
  wget -O pts_chroot_env_qq.sh.tmp http://raw.githubusercontent.com/pts/pts-chroot-env-qq/master/pts_chroot_env_qq.sh
  chmod +x pts_chroot_env_qq.sh.tmp
  mv pts_chroot_env_qq.sh.tmp pts_chroot_env_qq.sh
fi

# TODO(pts): Add setup instructions for lucid_dir:
if ! test -f lucid_dir/bin/bash; then
  sudo umount lucid_dir/proc ||:
  sudo umount lucid_dir/dev/pts ||:
  rm -rf lucid_dir lucid_dir.tmp
  ./pts_chroot_env_qq.sh pts-debootstrap lucid lucid_dir.tmp  # Ubuntu 10.04 Lucid Lynx.
  mv lucid_dir.tmp lucid_dir
  test -f lucid_dir/bin/bash
  test -x lucid_dir/bin/bash
else
  (cd lucid_dir && ../pts_chroot_env_qq.sh cd) || exit "$?"  # Trigger sudo with password prompt.
fi

if ! test -f lucid_dir/usr/bin/gcc; then
  (cd lucid_dir && ../pts_chroot_env_qq.sh apt-get update) || exit "$?"
  (cd lucid_dir && ../pts_chroot_env_qq.sh apt-get -y install gcc make) || exit "$?"  # gcc-4.4
  test -f lucid_dir/usr/bin/gcc
  test -x lucid_dir/usr/bin/gcc
  test -f lucid_dir/usr/bin/make
  test -x lucid_dir/usr/bin/make
fi

if ! test -f lucid_dir/tmp/perlsrc/Configure; then
  rm -rf lucid_dir/tmp/perl-5.10.1 lucid_dir/tmp/perlsrc
  (cd lucid_dir/tmp && tar xzvf ../../perl-5.10.1.tar.gz) || echo "$?"
  mv lucid_dir/tmp/perl-5.10.1 lucid_dir/tmp/perlsrc
  test -f lucid_dir/tmp/perlsrc/Configure
  test -f lucid_dir/tmp/perlsrc/perl.c
fi

if ! test -f lucid_dir/tmp/perlsrc/pts-xstatic/bin/xstatic; then
  (cd lucid_dir/tmp/perlsrc && ../../../pts-xstatic-latest.sfx.7z -y) || exit "$?"
  test -f lucid_dir/tmp/perlsrc/pts-xstatic/bin/xstatic
  test -x lucid_dir/tmp/perlsrc/pts-xstatic/bin/xstatic
fi

if ! test -f lucid_dir/tmp/perlsrc/Makefile; then
  (cd lucid_dir/tmp/perlsrc && patch -p1 <../../../patch-5.10.1.patch) || exit "$?"
  # !! What manual changes are we making to config-5.10.1.sh?
  ## SUXX: -Dusedl=n enables lots of modules linked statically
  ## !! Also add the .pm files for Fcntl IO Socket Sys/Hostname.
  ## !! Generate lib/ and list of all possible modules.
  ##(cd lucid_dir/tmp/perlsrc && ./pts_chroot_env_qq.sh sh Configure -ds -e -Dusedl=n -Dstatic_ext="") || exit "$?"
  ##(cd lucid_dir/tmp/perlsrc && ./pts_chroot_env_qq.sh sh Configure -ds -e -Dusedl=n -Dstatic_ext="Cwd File/Glob") || exit "$?"
  ##(cd lucid_dir/tmp/perlsrc && ./pts_chroot_env_qq.sh sh Configure -ds -e -Dusedl=n -Dstatic_ext="Cwd File/Glob Fcntl IO Socket Sys/Hostname B Compress/Raw/Bzip2 Compress/Raw/Zlib Data/Dumper Devel/DProf Devel/PPPort Devel/Peek Digest/MD5 Digest/SHA Encode Filter/Util/Call Hash/Util Hash/Util/FieldHash I18N/Langinfo IO/Compress IPC/SysV List/Util MIME/Base64 Math/BigInt/FastCalc Opcode POSIX PerlIO/encoding PerlIO/scalar PerlIO/via SDBM_File Storable Sys/Syslog Text/Soundex Time/HiRes Time/Piece Unicode/Normalize attrs mro re threads threads/shared Encode/Byte Encode/CN Encode/EBCDIC Encode/JP Encode/KR Encode/Symbol Encode/TW Encode/Unicode") || exit "$?"
  ##(cd lucid_dir/tmp/perlsrc && ./pts_chroot_env_qq.sh sh Configure -ds -e -Dusedl=y) || exit "$?"
  cp -a config-5.10.1.sh lucid_dir/tmp/perlsrc/config.sh
  (cd lucid_dir/tmp/perlsrc && ../../../pts_chroot_env_qq.sh sh Configure -S) || exit "$?"  # Reads config.sh, runs **/*.SH to generate other files (e.g. Makefile).
  test -f lucid_dir/tmp/perlsrc/Makefile
fi

if ! test -f lucid_dir/tmp/perlsrc/preamble.pm; then
  cat StaticPreamble.pm preamble-5.10.1.pm >lucid_dir/tmp/perlsrc/preamble.pm
fi

if ! test -f lucid_dir/tmp/perlsrc/miniperl; then
  (cd lucid_dir/tmp/perlsrc && PATH="$PWD/pts-xstatic/bin:$PATH" ../../../pts_chroot_env_qq.sh make miniperl) || exit "$?"
  # !! bootstrap: lucid_dir/tmp/perlsrc/miniperl -w -I. -e0 -mStaticPreamble=set stdin <lucid_dir/tmp/perlsrc/preamble.pm
  lucid_dir/tmp/perlsrc/miniperl -w -I. -e0 -mStaticPreamble=set ''  # Just strip and truncate (make the miniperl executable 16 MiB smaller).
  test -f lucid_dir/tmp/perlsrc/miniperl
  test -x lucid_dir/tmp/perlsrc/miniperl
fi

if ! test -f lucid_dir/tmp/perlsrc/perl; then
  # '.' in @INC is needed by `make perl'.
  lucid_dir/tmp/perlsrc/miniperl -w -I. -e0 -mStaticPreamble=set 'unshift @INC, "."'  # Just strip and truncate (make the miniperl executable 16 MiB smaller).
  # !! At some point no pts_chroot_env_qq.sh.
  (cd lucid_dir/tmp/perlsrc && PATH="$PWD/pts-xstatic/bin:$PATH" ../../../pts_chroot_env_qq.sh make perl) || exit "$?"
  # Too early to specify: -Minteger -Mstrict
  lucid_dir/tmp/perlsrc/perl -w -I. -e0 -mStaticPreamble=set stdin <lucid_dir/tmp/perlsrc/preamble.pm
  lucid_dir/tmp/perlsrc/miniperl -w -I. -e0 -mStaticPreamble=set ''  # Just strip and truncate (make the miniperl executable 16 MiB smaller).
fi

lucid_dir/tmp/perlsrc/perl -e'exit(0)'
lucid_dir/tmp/perlsrc/perl -e'use integer; exit(0)'
lucid_dir/tmp/perlsrc/perl -e'glob("*")'
# lucid_dir/tmp/perlsrc/miniperl is also (partially) useful: it doesn't have
# any C extensions (e.g. File::Glob needed by glob("*").
cp lucid_dir/tmp/perlsrc/perl staticperl-5.10.1

if test -e lucid_dir/proc/self; then
  sudo umount lucid_dir/proc ||:
fi
if test -e lucid_dir/dev/pts/ptmx; then
  sudo umount lucid_dir/dev/pts ||:
fi

ls -l staticperl-5.10.1

: c.sh OK.
