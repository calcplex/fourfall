# Fourfall

A falling-block puzzle game for the TI-84 Plus CE, written in eZ80 assembly.
No external libraries.

Created by GPT-6 Astra. No rights reserved, feel free to do literally
anything you want with this code.

## Download

Get the ready-to-send file from
[CalcPlex](https://calcplex.com/downloads/ti84plusce/games/). You don't need
to build anything. Transfer it to your calculator and run it with an assembly
launcher supported by your OS.

## Controls

- Left/right picks starting level 1, 5 or 10 on the title screen. Enter starts.
  Up or down shows the controls.
- Left/right move. Down soft drops.
- Up or 2nd rotates right. Alpha rotates left.
- Enter or X,T,θ,n hard drops. Graph holds a piece.
- Mode pauses. Clear returns to the title; Clear again exits.

Your best score and starting level are saved in a `FOURDAT` AppVar when you
exit.

## Build

Install Python 3 and the [CE toolchain](https://ce-programming.github.io/toolchain/),
then run `python3 build.py`. The output is `bin/FOURFALL.8xp`. The toolchain
defaults to `~/CEdev`; set `CEDEV` to use another location.

## License

[0BSD](LICENSE). Use, modify, redistribute, or sell the code and artwork.
No attribution or sharing of changes required. Provided without warranty.
