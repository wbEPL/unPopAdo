# unPopAdo

A Stata `.ado` command that loads UN World Population Prospects (WPP2024)
population estimates and projections for one or more countries directly
into memory -- straight from GitHub or a local mirror, no download step
required.

**Docs site:** https://wbEPL.github.io/unPopAdo/

> **Disclaimer.** `un_pop` is only a data *interface*. The population
> figures it returns are produced by the UN Population Division's
> [World Population Prospects](https://population.un.org/wpp) (WPP2024);
> we do not produce, verify, or take responsibility for the accuracy,
> completeness, methodology, or timeliness of that underlying data --
> see the UN WPP site for revisions and terms of use. The pre-cleaned
> copy this command reads is built and hosted in the companion
> [unPopData](https://github.com/wbEPL/unPopData) repository.

## Instruction manual

### What it does

`un_pop` returns one long-format dataset -- country x year x 5-year age
group x sex -- for any number of countries and one UN projection variant,
with country identifiers and the variant name already merged in. Nothing
is saved to disk; the result replaces whatever dataset was in memory.

### How it works

1. **Resolve `root()`.** Defaults to the unPopData GitHub repo's raw
   files; a local folder or another URL can override it.
2. **Validate `country()`.** Every requested ISO3 code is checked against
   `lookup_countries.dta`. If even one is unrecognized, nothing loads.
3. **Validate `variant()`.** Checked against whatever non-historical
   variants exist in `lookup_scenarios.dta` (case-insensitive).
4. **Load, filter, stack.** Each `<ISO3>.dta` is loaded, filtered to the
   shared historical rows plus the selected variant's projection rows,
   and appended across countries.
5. **Merge.** Country identifiers come from `lookup_countries.dta`; the
   variant name comes from `lookup_scenarios.dta`.

See [`un_pop.ado`](un_pop.ado) for the full implementation, or
`help un_pop` once installed.

### Installation

Pick one:

| Method                                                                  | Command                                                                                              |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Direct (`net install`)                                                  | `net install un_pop, from("https://raw.githubusercontent.com/wbEPL/unPopAdo/main/")`                 |
| Package manager ([`haghish/github`](https://github.com/haghish/github)) | `net install github, from("https://haghish.github.io/github/")` then `github install wbEPL/unPopAdo` |
| Manual                                                                  | Clone this repo and put `un_pop.ado` + `un_pop.sthlp` on your `adopath`                              |

All three install the same two files (`un_pop.ado`, `un_pop.sthlp`), listed
in [`un_pop.pkg`](un_pop.pkg) / [`stata.toc`](stata.toc). To remove:
`ado uninstall un_pop`.

### Usage

```stata
* Single country, default root (GitHub) and variant (Medium)
un_pop, country(GNB)

* Multiple countries, explicit variant
un_pop, country("GNB SEN COL") variant(Medium)

* Local checkout of unPopData instead of GitHub
un_pop, country(GNB) root("../unPopData/clean")
```

### Options

| Option            | Required? | Description                                                                                                                                                                                       |
| ----------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `country(string)` | Yes       | One or more ISO3 codes, space- and/or comma-separated (e.g. `country("GNB SEN, col")`). Case-insensitive; duplicates collapsed.                                                                   |
| `root(string)`    | No        | Local folder or URL with the `clean/` data layout. Defaults to the unPopData GitHub repo.                                                                                                         |
| `variant(string)` | No        | UN projection variant. Defaults to `Medium`. Validated dynamically against `lookup_scenarios.dta`, so new variants become selectable the moment the data adds them -- no code change needed here. |

### Output

One row per country x year x 5-year age group x sex, sorted by
`iso3_code variant time agegrpstart sex`. Variable names are carried over
unchanged from the source files; only `location`, `iso2_code`, and
`locid` are new, merged in from `lookup_countries`:

| Variable      | Description                                                            |
| ------------- | ---------------------------------------------------------------------- |
| `iso3_code`   | ISO3 country code                                                      |
| `location`    | Country / area name                                                    |
| `iso2_code`   | ISO2 country code                                                      |
| `locid`       | UN location ID                                                         |
| `variant`     | Requested variant name, applied to both historical and projection rows |
| `varid`       | UN VarID of the source row (0 = shared historical row)                 |
| `time`        | Calendar year (1 January), 1950 onward                                 |
| `agegrpstart` | 5-year age group, start age (0, 5, ..., 100)                           |
| `sex`         | Labelled 1 = Male, 2 = Female                                          |
| `pop`         | Population, in thousands                                               |

### Errors

| Code    | Message                                                  | Cause                                                                                                         | Fix                                                                                                      |
| ------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| r(197)  | `option country() required`                              | `country()` was omitted entirely                                                                              | Supply `country()`                                                                                       |
| r(198)  | `country() cannot be blank.`                             | `country()` was empty/whitespace                                                                              | Supply at least one ISO3 code                                                                            |
| r(198)  | `Country code(s) not found in lookup_countries.dta: ...` | One or more codes don't exist                                                                                 | Check the printed reference table for the correct code                                                   |
| r(198)  | `Variant '...' not available.`                           | The variant isn't in `lookup_scenarios.dta` (includes requesting the reserved `Historical` baseline directly) | Check the printed list of available variants                                                             |
| r(601)  | `Could not load <file> from root '...'.`                 | `root()` is unreachable, wrong, or you're offline                                                             | Check the path/URL and your internet connection                                                          |
| r(9999) | `Internal error: ...`                                    | The source data no longer matches what this `.ado` expects (schema drift)                                     | Not user-fixable; report it -- see [unPopData](https://github.com/wbEPL/unPopData) for the data pipeline |

Run [`test_un_pop.do`](test_un_pop.do) for the full test suite covering
every path above, plus the happy paths against both GitHub and a local
root.

## News

- **v0.1.0** -- Removed the unused `edu_level` placeholder; all other
  variables keep their original source names (no more renaming to
  `country`/`year`/`cohort`/`gender`/`value`).
- **v0.0.2** -- `root()` is now optional (defaults to GitHub); `country()`
  accepts multiple ISO3 codes; reads unPopData's one-file-per-country
  layout.
- **v0.0.1** -- Initial release: single country, mandatory `root()`.

## License

This project is licensed under the MIT License together with the [World Bank IGO Rider](WB-IGO-RIDER.md). The Rider is purely procedural: it reserves all privileges and immunities enjoyed by the World Bank, without adding restrictions to the MIT permissions. Please review both files before using, distributing or contributing.
