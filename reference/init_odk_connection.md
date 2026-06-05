# Initialize an ODK Central connection

Authenticates with ODK Central and returns a connection object that can
be passed to other ODK functions via the `con` argument. As a fallback
for backward compatibility, all ODK functions also accept credentials
via the `ODK_URL`, `ODK_USER`, and `ODK_PASS` environment variables.

## Usage

``` r
init_odk_connection(
  url = Sys.getenv("ODK_URL", unset = "https://rblf.tccodk.org/"),
  user = Sys.getenv("ODK_USER", unset = ""),
  pass = Sys.getenv("ODK_PASS", unset = "")
)
```

## Arguments

- url:

  `chr` ODK Central server URL

- user:

  `chr` Email address used to authenticate

- pass:

  `chr` Password

## Value

An `odk_connection` object (returned invisibly)
