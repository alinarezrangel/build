---
title: The build.make tool
toolbar: yes
---

# `build.make` -- The make-like clone of `build.lua` #

The `build.lua` library comes with a clone of the classic `make` program called
`build.make`. This program implements a `make`-like
[DSL](https://en.wikipedia.org/wiki/Domain-specific_language) that is mostly
compatible with a subset of GNU Make.

## Basic usage ##

The basic usage is the same than `make`: just run `build.make` in a directory
that has a `Makefile`, `makefile`, `BUILDmakefile` or `BuildMakefile` file and
it will automatically build your program.

For example: imagine the following `Makefile`:

```make
a.o: a.c
    cc -c a.c -o a.o

b.o: b.c
    cc -c b.c -o b.o

exe: a.o b.o
    cc a.o b.o -o exe
```

And the following files:

```c
// a.c

extern void foo(int);

int main()
{
    foo(1);
}

// b.c
#include <stdio.h>

void foo(int x)
{
    printf(">%d\n", x);
}
```

Then running `build.make exe` will perform the necessary actions to get the
file `exe` up to date. Try modifying only one of `a.c` or `b.c` and see how it
only builds the modified files.

And so, the simplest usages of `build.make` are:

- `build.make TARGET1 TARGET2 ...`: Builds `TARGET1`, `TARGET2`, etc.
- `build.make` (no arguments): Builds the `all` target.

## Makefiles ##

`build.make` will try to read any of the following files (in the given order):

- `BUILDmakefile`
- `BuildMakefile`
- `makefile`
- `Makefile`

The `BUILDmakefile` and `BuildMakefile` are meant to be used only when your
makefile is making use of `build.make`-specific features. Unlike the
relationship between [GNU Make][gnu-make] and other makes (see [FreeBSD's
make](https://www.freebsd.org/cgi/man.cgi?query=make&sektion=1&apropos=0&manpath=FreeBSD+13.1-RELEASE+and+Ports),
POSIX make, SVR4 make, etc), `build.make` does not attempt to replicate the
standards make language, but instead only take it as a widely-known base in
which to build upon. Features which would be too difficult to implement in it's
current architecture or "features" which are extremely difficult to use are
left unimplemented.

The usage of `makefile` and `Makefile` files is deprecated (as the languages
are different) and will be removed in the future.

The syntax implemented from make consists of the following:

### Comments ###

Any unquoted `#` will start a comment that lasts until the end of the line. If
the line ends with an odd number of backslashes `\` then the comment is
extended to the next line and so on.

### Continuations ###

Extending the previous syntax, any line can end with a backslash `\` and it
will be *continued* into the next. For example, the two programs are
equivalent:

```make
executable: main.c math.c \
graphics.c physics.c serde.c
    cc -o $@ $^
```

And:

```make
executable: main.c math.c graphics.c physics.c serde.c
    cc -o $@ $^
```

You can escape `\` with other `\`. There must be whitespace before a `\` that
escapes a newline. So, for example, `\\` is a literal `\` and `hola\` does
**not** continue into the next line. Note that, when not preceded by
whitespace, `\` has a escaping behaviour. For example, `\\` is a literal `\`,
while `\#` is a literal `#`. You can escape any of the characters `\`, `#`,
`:`, `=` and `|` which backslashes. An alternative to backslashes is to put
them between quotes (`\#` and `"#"` are the same literal).

*Note*: None of the previous paragraph applies to comments, which only check if
they end in an odd number of backslashes regardless for whenever they are
preceded by whitespace or not.

Finally, line continuations cannot appear inside string literals.

### Variables ###

Any of the following forms:

    VAR = ...
    VAR := ...
    VAR ::= ...
    VAR ?= ...

Will declare a variable `VAR` with a value of `...`, where `...` can be any
number of "words" (defined below). Variables can be named almost anything,
except names containing whitespace and/or the characters `:`, `=`, `(`, `)`,
`[`, `]`, `{`, `}` or `#`.

These have the same behaviour than their counterparts in [GNU
Make][gnu-make]. Specifically:

- `VAR =` will set a variable. The variable's value is expanded lazily (that
  is, it acts more like a macro than a variable in most other programming
  languages).
- `VAR :=` and `VAR ::=` set a variable but expand it's contents right
  away. This assigment basically has the same semantics than the normal
  assigment `=` in other programming languages.
- `VAR ?=` will set `VAR` only if not already set.

After defining a variable you can refer to it with the syntax `$(VAR)`. If the
name of the variable is a single character then you can also use `$VAR`. For
example, `$(CC)` refers to the variable `CC` while `$<` refers to the variable
`<`. To escape a `$` both inside and outside a recipe use `$$`.

### Rules ###

A rule indicates *when* to build a *target* (that is, a file that you want to
build automatically). Rules look like this:

    TARGET: DEPENDENCIES...

Where `TARGET` is a "word" and `DEPENDENCIES` are zero or more "words". What
this rule means is that `TARGET` should be rebuilt when any of the
`DEPENDENCIES` changes. For example: the rule `a.o: a.c` from the previous
example says that `a.o` will be rebuilt once `a.c` changes; the rule `lib.so:
a.o b.o c.o` says that the file `lib.so` will be rebuilt if any of `a.o`, `b.c`
or `c.o` changes and finally the rule `example.txt:` says that `example.txt`
will be rebuilt when possible (as it has no dependencies it is considered
permanently "out-of-date"/"to-be-rebuilt").

If `TARGET` contains an unescaped `%` then it is said that this is a *pattern
rule*. Each unescaped `%` on the dependencies will be replaced by what the `%`
*matched* on the target. This `%` acts kind of like a shell glob or a SQL
`LIKE` clause. Unlike a glob, it can match any character. For example, the next
rule tells how to build *any* file in the directory `build/` that starts with
`lib` and ends with `.so` by running the C compiler on an equally named (but
without the extension nor the `lib` at the beginning) file on the `src/libs/`
directory:

```make
build/lib%.so: src/libs/%.c
    cc -shared -o $@ $<
```

What this rule does is to match an output like `build/libfoo.so`, gets the part
matched by the `%` (`foo`) and replaces it into any dependency to get
`src/libs/foo.c`.

### Recipes ###

Recipes indicate *how* a target will be rebuilt. All lines after a rule that
start with at least one space or tab are considered it's recipe.

**NOTE**: Unlike other makes out there, **spaces can be used instead of tabs as
indentation**.

For example:

```make
release.zip: README.md main.lua
    zip release.zip README.md main.lua

game: release.zip
    cat `whereis love` release.zip > game
    chmod +x game
```

The indented lines after the rules are the recipes, indicating that to rebuild
`release.zip` one must run `zip release.zip README.md main.lua` and to rebuild
`game` one must run `cat `whereis love` release.zip > game` and `chmod +x
game`.

For each line of the recipe `build.make` will invoke the `sh`(1) shell with
said line. If any of the commands exists with a non-zero exit code then the
whole recipe is cancelled. For example, when running the `game` recipe it will
first run the equivalent of:

    sh -c 'cat `whereis love` release.zip > game' && sh -c 'chmod +x game'

Because each line has it's own subshell, this means that shell variables from
one line will not be visible on the next.

You can change the shell being used with the special `.SHELL` rule:

```make
.SHELL: python3 -c   # I prefer python...

date.txt:
    import datetime; print(datetime.date.today())
```

The first dependency of the `.SHELL` rule will be treated as the program to
run, while all remamining ones will be used as additional arguments.

### Recipe auto-escaping ###

One critical difference between `build.make` and other makes is that
`build.make` will automatically escape variable references in recipes. For
example:

```make
FILES = *.c

example:
    echo $(FILES)
```

When building `example`, the echo will actually print `*.c` rather than all the
files that end in `.c`. This is because other makes work more like a macro
templating system while `build.make` will escape the variables when
interpolating using the
[`shell-quote`(1p)](https://manpages.debian.org/buster/libstring-shellquote-perl/shell-quote.1p.en.html)
program.

### Words ###

The autoescaping feature requires me to specify where and how does `build.make`
insert spaces between a variable's elements. It does this by separating a
variable in words. Each word is escaped as a separate shell argument. Like the
the `sh`(1) language, you can concatenate several forms in a single word by
leaving no whitespace between them. You can use double-quoted strings, bare
words, make escapes (`$$` to escape a `$`) and backslash escapes. For example,
`hola" "mundo que$$"("TAL")"` contains 2 words, `hola mundo` and `que$(TAL)`.

All of this happens *syntactically*. This means that `build.make` works closer
to a common programming language like [Python](https://python.org) or
[Lua](https://lua.org) than it does with text templating engines like other
makes or [GNU M4](https://www.gnu.org/software/m4/m4.html).

Some examples: in the following snippet, the variable `FILES` contains 3
elements with the values `a`, `b c` and `d`:

```make
FILES = a "b c" d
```

The next example declares a variable with six elements:

```make
C_SRCS = a.c b.c c.c
LUA_SRCS = a.lua b.lua c.lua
SRCS = $(C_SRCS) $(LUA_SRCS)
```

As a demonstration that this is not text replacement, the following variable,
which contains special syntax for `sh`(1), will nonetheless be escaped
correctly:

```make
SPECIAL = HOLA=mundo

example:
    $(SPECIAL)
```

Will error out with a `HOLA=mundo: not found` error, indicating that the
`HOLA=mundo` was processed as a command and not an assigment.

If you use a variable with multiple values inside a word, the cartesian product
of the variable values and the parts after and before it will be produced. For
example:

```make
A = 1 2 3
B = a b c
C = $(A)
D = $(A) $(B)
E = $(A)$(B)
F = file.$(A).txt
G = data.$(B).txt z$(A).zip
```

The variables `A` and `B` have 3 elements each. So does `C`, which has `A`'s
elements. `D` has the values `1 2 3 a b c`. Because `E`'s definition used
multi-values variables in the same word, such word gets *expanded* with the
cartesian product to get the values `1a 1b 1c 2a 2b 2c 3a 3b 3c`. Same with
`F`, which gets `file.1.txt file.2.txt file.3.txt`. A similar process happens
for the 2 words of `G` for a total of 9 elements.

This only happens outside of recipes, as `build.make` cannot know the syntax of
the shell in use.

As a practical example of this, the following makefile will create 2 rules, in
which `docs.zip` depends on all the source files with a `.txt` extension and
`src.zip` depends on all the source files with a `.lua` extension:

```make
FILES = main utils fs buffer panels io
SRCS = $(FILES).lua
DOCS = $(FILES).txt

docs.zip: $(DOCS)
    zip $@ $^

%.txt: %.lua
    ... # Generate documentation from a lua file

src.zip: $(SRCS)
    zip $@ $^
```

### Shell Evaluation ###

Backquotes can be used anywhere where a word is expected. The text inside them
will be evaluated using the current shell (see the `.SHELL` pseudo-target) and
the result will be used instead.

**NOTE**: Due to autoescaping, this feature is surprisingly difficult to
implement: most programs meant to generate CLIs (like `pkg-config`) just emit
shell code to be eval'ed. This does not work with autoescaping and `pkg-config`
will only works as long as all options are in a single word.

An example of this feature is:

```make
CC ?= gcc
CFLAGS = `pkg-config --cflags check`
LIBS = `pkg-config --libs check`

output/test_%: tests/test_%.c
    $(CC) $(CFLAGS) -o $@ $< $(LIBS)
```

**NOTE**: There is no way to escape the backquotes, nor to get the command's
output without word-splitting.

### Includes ###

A single line like:

```make
include filenames...
```

Will include all the *`filenames`...* into the current file. Variables defined
will overwrite those that already exist, while the targets of both the current
and referenced files are combined. Each `filename` is a word, and, as such, can
include all the mentioned word-syntax, such as cartesian expansion, sub-shells,
etc.

A common example of this is including a `config.mk` file with some common
variables meant to be changed by the user:

```make
include config.mk
```

You could even include a different `config.autogen.mk` which was automatically
generated! Of course, you would include it before the user's `config.mk` so
that if the user explicitly sets any option, it overrides the automatically
generated one:

```make
include config.autogen.mk config.mk
```

### Special variables ###

The following variables are special: they are automatically defined before
executing each recipe.

- `$@`: The target being built.
- `$<`: The name of the first prerequisite (the first dependency).
- `$^`: The names of all prerequisites (all dependencies). Duplicate values are
  removed.
- `$+`: The names of all prerequisites (all dependencies). Duplicate values are
  left as-is.
- `$|`: Empty. Reserved for future purposes.

### Phony targets ###

The special `.PHONY` rule marks several other rules are "phony": they are
always considered out of date even if a suitable file exists. For example:

```make
.PHONY: all test run
all:
    ...

test:
    ...

run:
    ...
```

Will always run the `all`, `test` and `run` targets even if up to date `all`,
`test` and `run` files already exist.

## Command line usage ##

See `build.make -h` for a listing of all command line options and what they do.

[gnu-make]: https://www.gnu.org/software/make/
