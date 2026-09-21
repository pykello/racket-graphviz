# Development and release checks

Use a full Racket installation and Graphviz with `-Tjson` support. From
the checkout, register the collection and run the suite:

```sh
raco pkg install --name graphviz --link "$PWD"
raco test tests main.rkt lib
raco setup --check-pkg-deps --no-docs --pkgs graphviz
raco scribble --htmls ++xref-in setup/xref load-collections-xref --dest build/manual scribblings/graphviz.scrbl
```

Set `TMPDIR` to a writable temporary directory when the system default is
read-only. For isolation, set `PLTUSERHOME` to a fresh temporary directory
before package installation and all subsequent commands. Test a source
archive in a second fresh environment before releasing.

## Test layers

- Baseline/compatibility tests retain the public struct layouts, examples,
  pict exports, legacy cardinalities, and orthogonal-layout option.
- Serializer tests check actual graph identities in native Graphviz JSON.
- Process tests use a portable Racket child for binary output, Unicode,
  full pipes, failures, and deadlines; real Graphviz integrations validate
  executable configuration and output formats.
- Renderer tests use committed JSON fixtures without requiring Graphviz,
  inspect pixels for fill behavior, and record text anchors numerically.
- Documentation/example tests verify inert imports and fresh rendering
  without source-tree writes.

Local integrations skip when `dot` is absent. CI must first verify `dot`
and JSON support; a missing dependency must fail that job.

## Visual review

```sh
racket tools/gallery.rkt build/gallery
racket tools/readme-images.rkt images
```

The second command refreshes the committed README diagrams from the
actual examples; the directory-tree snapshot uses `tests/fixtures`.

Open `build/gallery/index.html`. Native and pict SVG/PNG outputs are
paired for issues #6, #8, and #9, plus transformed custom picts. The
manifest records Graphviz/Racket versions, installed fonts, platform, and
source hashes. Native PNG uses Graphviz's output DPI; compare geometry
at a common scale rather than expecting identical image dimensions.

Review contour counts, label anchors, font families, custom node placement,
and clipping. Exact bitmap equality across arbitrary platforms is not a
release criterion. The Linux visual job pins the OS, Graphviz package,
font packages, and Racket version; update pins and review artifacts
intentionally. Its manifest still records any environment differences.

The public renderer uses Graphviz JSON opcode conventions: lowercase `b`
is an unfilled cubic spline and uppercase `B` is filled. Do not substitute
the textual xdot opcode mapping without checking actual JSON output.
Gradients and external images currently produce explicit errors.

## Benchmarks

```sh
racket tools/benchmark.rkt > build/benchmark.json
```

The report separates graph construction, serialization, Graphviz process
execution, JSON parsing, and drawing. It reports elapsed time, allocation,
and sampled Racket memory; Graphviz's child-process memory is not included.
Use an OS profiler for whole-process peak RSS. Compare repeated runs in
the same environment and investigate large regressions before optimizing.
The checked-in baseline is an observation, not a cross-machine threshold.

## Platform matrix and limits

| Environment | Status |
| --- | --- |
| Linux, Racket 8.2 CS, Graphviz 2.43.0 | Locally exercised during implementation |
| Linux, current stable Racket | CI configured; results required before release |
| macOS, current stable Racket | CI configured; GUI executable-path check still required |
| Windows, current stable Racket | CI configured; results required before release |

Racket 8.2 is the tested compatibility baseline. Older versions are not
intentionally rejected, but are not certified. Graphviz 2.40.0 introduced
JSON historically; actual JSON capability, plugins, fonts, and fixture
results determine whether a particular installation works.

The CI configuration follows the upstream
[setup-racket usage](https://github.com/Bogdanp/setup-racket),
[checkout action](https://github.com/actions/checkout), and
[artifact action](https://github.com/actions/upload-artifact) documentation.

## Release checklist

- [ ] All test jobs pass on the exact release revision.
- [ ] Review the shape and label gallery against native Graphviz.
- [ ] Verify DrRacket on macOS with Graphviz outside GUI PATH (#5).
- [ ] Verify #8 contours, #9 labels, and #10 graph attributes from an install.
- [ ] Build docs from another working directory with read-only sources.
- [ ] Install a source archive into a fresh package environment; check deps.
- [ ] Review benchmark changes and memory behavior.
- [ ] Choose the release version and summarize changes when the release is ready.
- [ ] Verify package catalog source revision after publishing.
- [ ] Link released fixes and regression evidence when resolving issues.

Publishing, tagging, and issue comments are maintainer actions. Local
implementation and configured CI do not imply a published release or
successful remote matrix run.
