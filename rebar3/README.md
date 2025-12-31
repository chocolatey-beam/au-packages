# Rebar3

Rebar3 is an Erlang build tool that makes it easy to create, develop, and release Erlang libraries, applications, and systems in a repeatable manner.

## Features

* **Dependency Management** - Manages source dependencies and Erlang packages from Hex.pm
* **Project Templates** - Create new projects with `rebar3 new app myapp`
* **Compilation** - Build projects with `rebar3 compile`
* **Testing** - Run EUnit and Common Test suites
* **Code Coverage** - Generate coverage reports
* **Dialyzer Integration** - Static analysis with cached PLTs
* **Release Building** - Create self-contained Erlang releases with relx
* **Shell Integration** - Interactive shell with hot code reloading
* **Plugin System** - Extend functionality with plugins
* **Documentation** - Generate edoc documentation

## Usage

After installation, rebar3 is available from the command line:

```
rebar3 new app myapp    # Create new application
rebar3 compile          # Compile project
rebar3 eunit            # Run EUnit tests
rebar3 ct               # Run Common Test
rebar3 dialyzer         # Run Dialyzer
rebar3 release          # Build release
rebar3 shell            # Start interactive shell
```

## Requirements

Requires Erlang/OTP 26.0 or later. This package depends on the `erlang` Chocolatey package.

## Documentation

Full documentation available at [rebar3.org/docs](https://rebar3.org/docs)
