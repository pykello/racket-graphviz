# Graphviz regression fixtures

The shapes and labels inputs reproduce issues #8 and #9. The large
input comes from issue #6. JSON fixtures use Graphviz's inverted y axis,
matching the library. SVG files are native Graphviz references, not
screenshots of the existing renderer.

Generated with Graphviz 2.43.0 on Linux. Font requests are the default
Times-Roman and Courier; actual font substitution is platform dependent.
Regenerate each fixture with:

```sh
dot -y -Tjson shapes.dot > shapes.json
dot -Tsvg shapes.dot > shapes.svg
```

Pure tests and renderer fixtures do not need Graphviz. Integration tests
require `dot`; CI requires it rather than treating its absence as success.
Regression assertions for known defects land with their fixes.
