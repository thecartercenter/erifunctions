# Control how much erifunctions prints to the console

By default erifunctions narrates each step it takes – confirmations,
summaries, and progress bars – so you can see what it is doing. If you
prefer a terser console, switch to `"quiet"`: headline results,
warnings, and errors are still shown, but the step-by-step chatter is
hidden.

## Usage

``` r
eri_verbosity(level)
```

## Arguments

- level:

  `chr` Either `"full"` (default; chatty) or `"quiet"` (terse). Omit to
  read the current level instead of setting it.

## Value

The verbosity level, invisibly when setting.

## Details

Set it for a whole project by adding
`options(erifunctions.verbosity = "quiet")` to the project's
`.Rprofile`, or for one session by calling this function. The
`ERIFUNCTIONS_VERBOSITY` environment variable is also honoured (useful
in CI).

## Examples

``` r
eri_verbosity()          # read the current level
#> [1] "full"
if (FALSE) { # \dontrun{
eri_verbosity("quiet")   # terser console for the rest of the session
eri_verbosity("full")    # back to the chatty default
} # }
```
