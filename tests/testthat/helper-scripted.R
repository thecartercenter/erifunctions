# Test helper: a scripted decision sequence for mocking an interactive menu prompt
# (.eri_prompt_menu(), R/dq_review.R and R/guide.R).
#
# IMPORTANT: build the closure ONCE and pass it directly as the mocked binding
# (`.eri_prompt_menu = scripted(list(...))`) -- do not call `scripted(...)()` fresh from inside a
# wrapper function, which creates a brand-new closure (always starting at its first response) on
# every invocation instead of a shared, advancing one. That exact mistake once sent a mocked
# eri_guide() menu loop into an infinite "Run it now" loop against a real, live Azure tenant during
# test development (docs-site redesign phase 7) -- caught only because the runaway process had to
# be killed, not because any test failed.

# Returns a function that yields the next element of `responses` on each call, ignoring its
# arguments, and errors loudly once the script runs out rather than silently returning NULL/NA (a
# scripted test should never need more responses than it planned for).
scripted <- function(responses) {
  i <- 0L
  function(...) {
    i <<- i + 1L
    if (i > length(responses)) stop("scripted responses exhausted at call ", i)
    responses[[i]]
  }
}
