# cpptool
C++ post-processors for geeks

Shows you the amount of time spent parsing/compiling all the various content C++ header files tend to pull into your source files, allowing you to potentially optimize compilation times.

# usage

`timehdr [-DEPTH] <commandline used to call compiler>`

The `DEPTH` argument can be used to limit how far `timehdr.sh` should recursively analyze header files that are indirectly included.

See the example for more details.

# credits

Inspired by @NickNick
