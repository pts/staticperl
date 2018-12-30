package StaticPreamble; BEGIN { $INC{"StaticPreamble.pm"} = "StaticPreamble.pm" }
BEGIN {
sub import {
  my @args = (@_, @ARGV);
  # Ignore name of the module, 'StaticPreamble'.
  my $i = 1;
  my $data;
  if (@args >= $i + 2 and $args[$i] eq 'set') {
    $data = $args[$i + 1];
    $i += 2;
    $data = join('', <STDIN>) if $data eq "--stdin" or $data eq "stdin";
  } elsif (@args > $i and $args[$i] eq 'get') {
    ++$i;
  } else {
    die "fatal: Missing or unknown command.\n";
  }
  my $fn;
  if (@args > $i) {
    $fn = $args[$i++];
  } else {
    $fn = $^X;
    die "fatal: Missing slash: $fn\n" if $fn !~ m@/@;
  }
  die "fatal: Too many command-line arguments.\n" if $i != @args;
  if (defined($data)) {
    # Remove comments.
    $data =~ s@^[ \t]*#.*\n?@@mg;
    $data =~ s@[\s;]+\Z(?!\n)@@;
    $data .= substr($data, -1) eq '}' ? "\n1" : "\n;1" if
        substr($data, -1) ne '1';
    $data =~ s@\\@\\\\@g;
    $data =~ s@\0@\\\0@g;
    # We need the eval q\0...\0, because everything in PL_Preambleav after
    # an unescaped \n is ignored. But inside q... it's OK.
    # !! Get rid of @INC.
    $data = "BEGIN{eval q\0$data\0;die\$\@if\$\@}";
    # print $data; exit;
  }
  my $f;
  # Not using '+<' to avoid ETXTBSY on $^X.
  die "fatal: Open $fn: $!\n" if !open($f, '<', $fn);
  my $got;
  die "fatal: Read $fn: $!\n" if !($got = sysread($f, $_, 8192));
  die "fatal: Not a 32-bit MSB-first ELF v1 file.\n" if
      $got < 0x54 or !m@\A\x7fELF\x01\x01\x01@;
  my($e_phoff, $e_shoff, $e_flags, $e_ehsize, $e_phentsize, $e_phnum,
     $e_shentsize, $e_shnum, $e_shstrndx) = unpack('x28V3v6', $_);
  die "fatal: Bad e_phentsize.\n" if $e_phentsize != 0x20;
  die "fatal: Expected an exectuable ELF file.\n" if vec($_, 16, 8) != 2;
  $i = $e_phoff;
  die "fatal: Program header too long.\n" if (($got - $i) >> 5) < $e_phnum;
  my $phend = $i + ($e_phnum << 5);  my $tofs = $phend;
  my($data_i, $data_p_offset);
  for (; $i < $phend; $i += 32) {
    my($p_type, $p_offset, $p_vaddr, $p_paddr, $p_filesz, $p_memsz, $p_flags,
       $p_align) = unpack('V8', substr($_, $i, 32));
    next if $p_type != 1;  # PT_LOAD.
    # Prevent upx CantPackException: Go-language PT_LOAD.
    # Prevent invalid Phdr p_offset; (without upx --force-exece).
    if (0 < $p_offset and $p_offset < 0x1000) {
      $p_vaddr -= $p_offset;
      $p_paddr -= $p_offset;
      $p_filesz += $p_offset;
      $p_memsz += $p_offset;
      $p_offset = 0;
      substr($_, $i, 32) = pack('V8', $p_type, $p_offset, $p_vaddr, $p_paddr,
                                $p_filesz, $p_memsz, $p_flags, $p_align);
    }
    if ($p_offset + $p_filesz > $tofs) {
      ($data_i, $data_p_offset) = ($i, $p_offset);
      $tofs = $p_offset + $p_filesz;
    }
  }
  # ei_osabi = GNU/Linux.
  vec($_, 7, 8) = 3;
  # e_shoff = 0.
  substr($_, 32, 4) = "\0\0\0\0";
  # e_shnum = e_shstrndx = 0.
  substr($_, 48, 4) = "\0\0\0\0";
  die "fatal: Missing PT_LOAD sections.\n" if !defined($data_i);
  die "fatal: Seek near end $fn: $!\n" if
      (sysseek($f, $tofs - 8, 0) or 0) != $tofs - 8;
  my $buf;
  die "fatal: Read near end $fn: $!\n" if (sysread($f, $buf, 8) or 0) != 8;
  my($size2, $capacity) = unpack('VV', $buf);
  die "fatal: Size larger than capacity.\n" if $size2 > $capacity;
  die "fatal: Size2 too large.\n" if $size2 >> 31;
  die "fatal: Old data does not fit in executable.\n" if
      $phend + 13 + $size2 > $tofs;
  my $data_size = length($data);
  die "fatal: New data too long: new_size=$data_size capacity=$capacity"
      if defined($data) and $data_size > $capacity;
  die "fatal: Seek to data $fn: $!\n" if
      (sysseek($f, $tofs - 12 - $size2, 0) or 0) != $tofs - 12 - $size2;
  die "fatal: Read size $fn: $!\n" if (sysread($f, $buf, 4) or 0) != 4;
  my($size) = unpack('V', $buf);
  die "fatal: Size too large.\n" if $size > $size2;
  if (defined($data)) {
    substr($data, 0, 0) = pack('V', $data_size);
    $data .= pack('VV', $data_size, $capacity);
    $data_p_filesz = $tofs - $size2 + $data_size - $data_p_offset;
    substr($_, $data_i + 16, 4) = pack('V', $data_p_filesz);
    my $of;
    # Not modifying $fn to avoid ETXTBSY on $^X.
    unlink("$fn.tmp");
    die "fatal: Open output $fn.tmp: $!\n" if !open($of, '>', "$fn.tmp");
    die "fatal: Write $fn.tmp: $!\n" if
        (syswrite($of, $_, $phend) or 0) != $phend;
    die "fatal: Seek to phend $fn: $!\n" if
        (sysseek($f, $phend, 0) or 0) != $phend;
    for (my $copy_size = $tofs - 12 - $size2 - $phend; $copy_size > 0;) {
      my $asize = $copy_size > 65536 ? 65536 : $copy_size;
      die "fatal: Read copy from $fn: $!\n" if
          (sysread($f, $buf, $asize) or 0) != $asize;
      die "fatal: Write copy to $fn.tmp: $!\n" if
          (syswrite($of, $buf, $asize) or 0) != $asize;
      $copy_size -= $asize;
    }
    die "fatal: Write data to $fn.tmp: $!\n" if
        (syswrite($of, $data, length($data)) or 0) != length($data);
    die "fatal: Close $fn.tmp: $!\n" if !close($of);
    close($f);
    my @stat = stat($fn);
    die "fatal: Stat $fn: %!\n" if !@stat;
    my $mode = $stat[2] & 0777;
    die "fatal: Chmod $fn.tmp: $!\n" if !chmod($mode, "$fn.tmp");
    die "fatal: Rename to $fn: $!\n" if !rename("$fn.tmp", "$fn");
  } else {
    die "fatal: Read old data $fn: $!\n" if
        (sysread($f, $data, $size) or 0) != $size;
    close($f);
    die "fatal: Bad old data prefix.\n".substr($data,0,100) if
        $data !~ s@\ABEGIN\{(?:[\@]INC=\(\); ?)?eval q\0@@;
    die "fatal: Bad old data suffix.\n" if
        $data !~ s@\n+;?1;?\n?\0; ?die\$[\@]if\$\@\}\n?\Z(?!\n)@\n1;\n@;
    my %r = ("\\"=>"\\", "0"=>"\0");
    $data =~ s@\\([\\\0])@$r{$1}@ge;
    print $data;
  }
}
}
1;
