#! /usr/bin/python
# by pts@fazekas.hu at Sun Dec 30 00:16:58 CET 2018

"""Removes section headers and unnecessary parts from an ELF32 executable
and sets the data string."""

import struct
import sys


def sstrip_elf32_executable_and_set_data(filename, data=None):
  """Removes section headers and unnecessary parts from an ELF32 executable
  and optionally sets the data string.

  It also changes ei_osabi to GNU/Linux.

  Args:
    filename: Input filename. The file ill be modified in place.
    data: str to set the data string to or None to keep the original data
        string.
  """
  if not (data is None or isinstance(data, str)):
    raise TypeError
  f = open(filename, 'rb+')
  try:
    ehdata = f.read(0x34)
    if len(ehdata) != 0x34:
      raise ValueError
    # https://en.wikipedia.org/wiki/Executable_and_Linkable_Format
    if not ehdata.startswith('\x7fELF\1\1\1'):
      raise ValueError('Not a 32-bit MSB-first ELF v1 file.')
    (e_phoff, e_shoff, e_flags, e_ehsize, e_phentsize, e_phnum, e_shentsize,
     e_shnum, e_shstrndx) = struct.unpack('<LLLHHHHHH', ehdata[0x1c : 0x34])
    if e_phentsize != 0x20:
      raise ValueError
    if ehdata[0x10] != '\2':
      raise ValueError('Expected an executable file.')
    if e_phnum >> 7:  # Typically there is 1 or 2 in statically linked exec.
      raise ValueError('Too many program header entries.')
    f.seek(e_phoff)
    phdata = f.read(0x20 * e_phnum)
    if len(phdata) != 0x20 * e_phnum:
      raise ValueError
    truncate_ofs = min_ofs = max(0x34, e_phoff + 0x20 * e_phnum)
    data_phi = data_p_offset = None
    for phi in xrange(e_phnum):
      (p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_flags,
       p_align) = struct.unpack('<8L', phdata[phi * 0x20 : (phi + 1) * 0x20])
      if p_type == 1:
        if 0 < p_offset < 0x1000:  # p_type == PT_LOAD.
          # Prevent upx CantPackException: Go-language PT_LOAD.
          # Prevent invalid Phdr p_offset; (without upx --force-exece).
          p_vaddr -= p_offset
          p_paddr -= p_offset
          p_filesz += p_offset
          p_memsz += p_offset
          p_offset = 0
          newphdata = struct.pack('<8L', p_type, p_offset, p_vaddr, p_paddr,
                                  p_filesz, p_memsz, p_flags, p_align)
          f.seek(e_phoff + phi * 0x20)
          f.write(newphdata)
        if p_offset + p_filesz > truncate_ofs:
          data_phi, data_p_offset = phi, p_offset
          truncate_ofs = p_offset + p_filesz
    f.seek(7)
    f.write('\3')  # ei_osabi = GNU/Linux.
    f.seek(0x20)
    f.write('\0\0\0\0')  # e_shoff = 0.
    f.seek(0x30)
    f.write('\0\0\0\0')  # e_shnum = e_shstrndx = 0.
    if data is not None:
      if data_phi is None:
        raise ValueError('Missing PT_LOAD sections.')
      f.seek(truncate_ofs - 8)
      size, capacity = struct.unpack('<LL', f.read(8))
      if size > capacity:
        raise ValueError('Size larger than capacity.')
      if size >> 31:
        raise ValueError('Size too large.')
      if min_ofs + 13 + size > truncate_ofs:
        raise ValueError('Old data does not fit in file.')
      if len(data) > capacity:
        raise ValueError(
            'New data too long: new_size=%d capacity=%d' % (len(data), capacity))
      f.seek(truncate_ofs - 12 - size)
      used, = struct.unpack('<L', f.read(4))
      if used > size:
        raise ValueError('Used too large.')
      f.seek(truncate_ofs - 12 - size)
      f.write(struct.pack('<L', len(data)))
      f.write(data)
      f.write(struct.pack('<LL', len(data), capacity))
      if len(data) != size:
        truncate_ofs += len(data) - size
        data_p_filesz = truncate_ofs - data_p_offset
        f.seek(e_phoff + data_phi * 0x20 + 0x10)
        f.write(struct.pack('<L', data_p_filesz))
    f.truncate(truncate_ofs)
  finally:
    f.close()  # Works even if fout == f.


def main(argv):
  if len(argv) not in (2, 3):
    print >>sys.stderr, 'Usage: %s <filename.elf> [<data>]' % argv[0]
    sys.exit(1)
  data = None
  if len(argv) > 2:
    data = argv[2]
    if data == '--stdin':
      data = sys.stdin.read()
  sstrip_elf32_executable_and_set_data(argv[1], data=data)


if __name__ == '__main__':
  sys.exit(main(sys.argv))
