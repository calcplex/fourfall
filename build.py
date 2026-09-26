import os
from pathlib import Path
import subprocess

from assets import generate, write_icon

ROOT = Path(__file__).resolve().parent
CEDEV = Path(os.environ.get('CEDEV', Path.home() / 'CEdev'))


def run(*args):
    subprocess.run([str(a) for a in args], cwd=ROOT, check=True)


def build():
    (ROOT / 'build').mkdir(exist_ok=True)
    (ROOT / 'bin').mkdir(exist_ok=True)
    generate(ROOT / 'build/assets.inc')
    write_icon(ROOT / 'build/icon.png')
    run(CEDEV / 'bin/convimg', '--icon', 'build/icon.png', '--icon-output',
        'build/icon.s', '--icon-format', 'gas', '--icon-description', 'Fourfall')
    icon = (ROOT / 'build/icon.s').read_text().splitlines()
    (ROOT / 'build/icon.inc').write_text('\n'.join(
        line for line in icon if line.strip().startswith('.db')) + '\n')
    run(CEDEV / 'binutils/bin/z80-none-elf-as', '-march=ez80+full',
        '-I', 'src', '-I', 'build', 'src/main.s', '-o', 'build/fourfall.o')
    run(CEDEV / 'binutils/bin/z80-none-elf-ld', '-T', 'link.ld',
        '-Map', 'build/fourfall.map', 'build/fourfall.o', '-o', 'build/fourfall.elf')
    run(CEDEV / 'binutils/bin/z80-none-elf-objcopy', '-O', 'binary',
        'build/fourfall.elf', 'build/fourfall.bin')
    run(CEDEV / 'bin/convbin', '-j', 'bin', '-k', '8xp', '-n', 'FOURFALL',
        '-i', 'build/fourfall.bin', '-o', 'bin/FOURFALL.8xp')
    print(f'FOURFALL.8xp: {(ROOT / "bin/FOURFALL.8xp").stat().st_size:,} bytes')


if __name__ == '__main__':
    build()
