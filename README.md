# unPopAdo

A Stata `.ado` command that loads UN WPP2024 population estimates and
projections for one or more countries directly into memory -- from a
local checkout or straight off GitHub, no download step required.

## About

`un_pop` reads the pre-cleaned UN WPP2024 "Population on 1 January by
5-year age group and sex" data produced by the companion
[unPopData](https://github.com/wbEPL/unPopData) repository, and returns
one long-format dataset (country x year x 5-year age group x sex) per
call, with country identifiers and the projection variant name already
merged in. See [`un_pop.ado`](un_pop.ado) for the full option reference
and design notes, or run `help un_pop` once the .ado is on your adopath.

```stata
* Single country, default root (GitHub) and variant (Medium)
un_pop, country(GNB)

* Multiple countries, explicit variant
un_pop, country("GNB SEN COL") variant(Medium)

* Local checkout of unPopData instead of GitHub
un_pop, country(GNB) root("../unPopData/clean")
```

Run [`test_un_pop.do`](test_un_pop.do) for the full smoke- and
edge-case test suite (bad country/variant codes, unreachable root,
comma- vs space-separated country lists, etc.).

## Getting Started

1. Clone this repo (or copy `un_pop.ado` + `un_pop.sthlp` onto your
   `adopath`).
2. Call `un_pop, country(<ISO3>)` -- it works with no local data at all,
   since it defaults to reading straight from the unPopData GitHub repo.
3. Pass `root()` to point at a local checkout of
   [unPopData](https://github.com/wbEPL/unPopData) instead, e.g. for
   offline use.
4. Review and update the `LICENSE` and [World Bank IGO Rider](WB-IGO-RIDER.md) as needed.

## License

This project is licensed under the MIT License together with the [World Bank IGO Rider](WB-IGO-RIDER.md). The Rider is purely procedural: it reserves all privileges and immunities enjoyed by the World Bank, without adding restrictions to the MIT permissions. Please review both files before using, distributing or contributing.
