# stackup
xnu MAXSSIZ got you down?  `stackup <path_to_binary> 0xdeadbeef` makes everything all better.

The Mac OS X kernel 'hardcodes' the stack size (`MAXSSIZ`) to 64MB.

However, check out this kernel code in the `load_main` routine in `xnu/bsd/kern/mach_loader.c`:

```` c
if (epc->stacksize) {
   result->prog_stack_size = 1;
   result->user_stack_size = epc->stacksize;
} else {
  result->prog_stack_size = 0;
  result->user_stack_size = MAXSSIZ;
}
````

where `epc` is an `entry_point_command` struct.

In other words, if our binary image contains a non-zero stack size in its `entry_point_command` struct (`LC_MAIN`), the kernel will use that instead of the default `MAXSSIZ`.

So, if for some reason you can't recompile, don't want to, or just simply want to be cool, you can run this command line tool to statically modify your program's runtime max stack size.

Enjoy.

## Compile

`xcrun --sdk macosx swiftc main.swift -o stackup`

## Examples

Set stack to 1GB: `stackup <path_to_binary> 0x1000000000`

Set stack to 0xdeadbeef: `stackup <path_to_binary> 0xdeadbeef`

# Features

  * Static binary translation for program max stack size.
  * Variable stack size
  * No recompilation or source code necessary
  * Hackish

## TODO:

   1. Enable 32-bit binary translation
   2. Enable fat-binary (universal) translation
