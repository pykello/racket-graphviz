#lang scribble/manual
@require[@for-label[graphviz
                    racket/base
                    pict]]
@require[graphviz
         scriblib/figure
         pict/shadow
         "utils.rkt"]

@(define (shadowed-box w h color)
  (inset (shadow (filled-rounded-rectangle w h 5
                                           #:color color
                                           #:border-color "black")
                 15 -3 3) 10))
@(define start-pict (shadowed-box 120 40 "LightSkyBlue"))
@(define node-pict (shadowed-box 160 40 "Gainsboro"))
@(define running-pict (shadowed-box 150 40 "Aquamarine"))
@(define terminal-pict (shadowed-box 150 40 "Salmon"))

@title{Racket Graphviz Integration}
@author{@(author+email "Hadi Moshayedi" "hadi@moshayedi.net")}
@defmodule[graphviz #:use-sources (graphviz/main)]
The goal of this library is to make composition of @racket[pict] and
@link["https://www.graphviz.org/"]{graphviz} diagrams possible.

The composition is made possible through:

@itemlist[
 @item{You can use graphviz diagrams as normal picts}
 @item{You can use any Pict as node shape of graphviz diagrams}
 ]

@section[#:tag "concepts"]{Basic concepts}

This package helps with visualizing directed graphs, or digraphs for short.
Each digraph consists of a set of vertexes and edges. For example
the digraph in @figure-ref["digraph0"] consists of three vertexes and four edges.

@figure[
 "digraph0"
 "An example digraph"
 @digraph->pict-cached[@(make-digraph
                         `("v0" "v1" "v2" "v0 -> v0" "v0 -> v1" "v1 -> v2" "v2 -> v0"))]]

There can be multiple edges between two vertexes, as shown in @figure-ref["digraph1"].

@figure[
 "digraph1"
 "multiple edges between two nodes"
 @digraph->pict-cached[@(make-digraph
                         `("v0" "v1" "v2" "v0 -> v1" "v0 -> v1" "v1 -> v2" "v2 -> v0" "v0 -> v2"))]]

Furthermore, a set of vertexes can be grouped in a subgraph, as show in @figure-ref["digraph2"].

@figure[
 "digraph2"
 "Subgraphs"
 @digraph->pict-cached[@(make-digraph
                         `((subgraph "Coordinator"
                                     ("Parser -> Planner -> Executor"))
                           (subgraph "Worker1"
                                     ("QueryProcessor1 -> DataPartition1"))
                           (subgraph "Worker2"
                                     ("QueryProcessor2 -> DataPartition2"))
                           "Executor -> QueryProcessor1" "QueryProcessor1 -> Executor"
                           "Executor -> QueryProcessor2" "QueryProcessor2 -> Executor"))]]

@section[#:tag "api"]{API}

@subsection{Defining Graphs}
@defproc[(make-digraph [definitions list?]) digraph?]{
 Creates a digraph. "definitions" is a list of vertex, edge, or subgraph
 definitions. Arbitrary keyword arguments become Graphviz graph attributes:
 @racket[(make-digraph '("a -> b") #:rankdir "LR" #:nodesep 0.5)].
 Values may be strings, booleans, or finite real numbers. Attribute names
 remain extensible. Duplicate attributes in a definition retain the first
 value, matching the historical parser. Malformed definitions raise an
 argument error rather than silently losing graph content. Empty
 definitions retain their historical no-op behavior.

 The compatibility keyword @racket[#:ortho] accepts a boolean: true selects
 @tt{splines="ortho"}, false selects @tt{splines="true"}. A conflicting
 explicit @racket[#:splines] value raises an error. New code should use
 @racket[#:splines] directly.
}

@itemlist[
 @item{
  @bold{Vertex Definitions.} A vertex can be defined using:
  @itemlist[
 @item{A string. The string will be used as the label.}
 @item{A list whose first element is the label and rest
    of the list contains the attributes of the node.}
 @item{A call to @racket[make-vertex].}]}
 @item{
  @bold{Edge Definitions.} A edge can be defined using:
  @itemlist[
 @item{A string. Node names are separated by @tt{->}}
 @item{A list like @tt{('edge [node1 ...] #:attr1 val1 ...)}.}
 ]}
 @item{
  @bold{Subgraph Definitions.} A subgraph can be defined using @tt{('subgraph label definitions)}}]


For example, @figure-ref["digraph0"] can be defined as the following, where
vertexes and edges are defined using strings.

@codeblock{
 (make-digraph
  `("v0" "v1" "v2" "v0 -> v0" "v0 -> v1" "v1 -> v2" "v2 -> v0"))
}

@figure-ref["digraph2"] can be defined as the following:

@codeblock{
  (make-digraph
    `((subgraph "Coordinator"
                ("Parser -> Planner -> Executor"))
      (subgraph "Worker1"
                ("QueryProcessor1 -> DataPartition1"))
      (subgraph "Worker2"
                ("QueryProcessor2 -> DataPartition2"))
      "Executor -> QueryProcessor1" "QueryProcessor1 -> Executor"
      "Executor -> QueryProcessor2" "QueryProcessor2 -> Executor"))
}


@defproc[(make-vertex [label string?] [#:shape shape (or/c pict? string?) "none"]) vertex?]{
}

@subsection{Conversion to Pict}
@defproc[(digraph->pict [digraph digraph?]) pict?]{
 Converts the given digraph to a @racket[pict].
}

@defproc[(dot->pict [definition string?]
                     [#:node-picts node-picts hash? (hash)]) pict?]{
 Converts the given digraph definition in dot language to a @racket[pict].
 For example, following code produces @figure-ref["dot->pict-example"].

 @codeblock{
  (dot->pict
  "digraph {
   a -> b -> c;
   }")
 }

 @figure[
 "dot->pict-example"
 "@dot->pict example"
 @dot->pict-cached["digraph {
                   a -> b -> c;
                   }"]
 ]
}

@subsection{Construction, Serialization, and Execution}

@defproc[(make-edge [from vertex?] [to vertex?]) edge?]{
 Creates an edge between two existing vertices. Include the vertices and
 edge in the definitions passed to @racket[make-digraph].
}

@defproc[(digraph->dot [graph digraph?]) string?]{
 Serializes a graph deterministically. Names are quoted as data; a few
 names that DOT cannot represent literally receive stable internal IDs.
 Generated anonymous vertex names are unique within the Racket process;
 separately constructed anonymous graphs need not have identical DOT.
 DOT label escapes, such as @tt{\\n}, retain their Graphviz meaning.
}

@defproc[(digraph-node-picts [graph digraph?]) hash?]{
 Returns the Graphviz node-ID to custom-pict mapping, including nested
 subgraphs and any internally assigned IDs. Conflicting custom picts for
 the same node are rejected.
}

@defproc[(digraph-ortho [graph digraph?]) boolean?]{
 Compatibility accessor that reports whether the graph selects orthogonal
 splines. Existing two-field graph structs remain unchanged. The older
 boolean second field is also accepted when rendering or serializing.
}

@defproc[(run-dot [definition string?] [format string?]) input-port?]{
 Runs Graphviz and returns a fresh input port containing its complete
 output bytes. The caller closes this port. Formats include @tt{json},
 @tt{svg}, @tt{png}, and Graphviz format/renderer variants. Failures include
 executable and process context; an unsupported JSON output build is
 identified explicitly. Warnings use Racket logging and never contaminate
 the output. No partial output is returned after timeout or failure.
}

@defparam[current-dot-executable executable (or/c path-string? #f)
          #:value #f]{
 An explicit executable path, or @racket[#f] to find @tt{dot} on PATH at
 call time. An invalid explicit path is an error. This supports GUI
 environments whose PATH differs from a terminal, without mutating PATH.
}

@defparam[current-dot-timeout seconds (or/c positive? #f) #:value 30]{
 Deadline in seconds covering input writes, process execution, and output
 collection. Use @racket[#f] for explicitly unlimited execution. A timed
 out or cancelled operation terminates the process and cleans up workers
 and ports.
}

@defproc[(er-diagram [tables list?] [relations list?]) pict?]{
 Each table is a list containing its name and a list of field strings.
 Relations contain the source table, destination table, source cardinality,
 and destination cardinality. Cardinalities are the symbols @racket['one]
 and @racket['many]; legacy @racket['(quote one)] and
 @racket['(quote many)] values remain accepted. Table names must be unique
 and relation endpoints must exist. Record metacharacters are escaped.
 @racketblock[
 (er-diagram '(("a" ("id")) ("b" ("id")))
             '(("a" "b" one many)))]
}

@defstruct[endpoint ([name string?] [port (or/c string? #f)]
                     [compass (or/c string? #f)]) #:transparent]{
 An explicit edge endpoint. @racket[(endpoint "a:b" #f #f)] refers to a
 literal node name containing a colon. String endpoints retain the
 historical colon-separated port syntax, such as @tt{Locked:n}.
 Compass values are @tt{n}, @tt{ne}, @tt{e}, @tt{se}, @tt{s}, @tt{sw},
 @tt{w}, @tt{nw}, @tt{c}, or @tt{_}. Use @racket[#f] for absent fields.
}

@subsection{Structs}

@defstruct[digraph ([objects list?] [attrs hash?]) #:omit-constructor]{
}

@defstruct[vertex ([name string?]
                   [label string?]
                   [shape (or/c pict? string?)]
                   [attrs hash?]) #:omit-constructor]{
}

@defstruct[edge ([nodes list?]
                 [attrs hash?]) #:omit-constructor]{
}

@defstruct[subgraph ([label string?]
                     [objects list?]
                     [attrs hash?]) #:omit-constructor]{
}

@section{Examples}

@subsection{Android Activity Lifecycle}

@codeblock{
(define (shadowed-box w h color)
  (inset (shadow (filled-rounded-rectangle w h 5
                                           #:color color
                                           #:border-color "black")
                 15 -3 3) 10))

(define start-pict (shadowed-box 120 40 "LightSkyBlue"))
(define node-pict (shadowed-box 160 40 "Gainsboro"))
(define running-pict (shadowed-box 150 40 "Aquamarine"))
(define terminal-pict (shadowed-box 150 40 "Salmon"))

(define d
  (make-digraph
   `(("Start" #:label "Activity Starts" #:shape ,start-pict)
     ("onCreate" #:label "onCreate()" #:shape ,node-pict)
     ("onStart" #:label "onStart()" #:shape ,node-pict)
     ("onResume" #:label "onResume()" #:shape ,node-pict)
     ("Running" #:label "Activity Running" #:shape ,running-pict)
     ("onPause" #:label "onPause()" #:shape ,node-pict)
     ("onStop" #:label "onStop()" #:shape ,node-pict)
     ("onDestroy" #:label "onDestroy()" #:shape ,terminal-pict)
     ("onRestart" #:label "onRestart()" #:shape ,node-pict)
     ("killed" #:label "Process is Killed" #:shape ,terminal-pict)
     (edge ("Start" "onCreate" "onStart" "onResume" "Running") #:weight "7")
     (edge ("Running" "onPause") #:label "Another activity activates" #:weight "7")
     (edge ("onPause" "onStop") #:label "Activity is no longer visible" #:weight "7")
     (edge ("onStop" "onDestroy") #:weight "7")
     (edge ("onPause" "onResume"))
     (edge ("onStop" "onRestart") #:label "Activity comes to foreground")
     (edge ("onRestart" "onStart"))
     (edge ("onStop" "killed"))
     (edge ("killed" "onCreate"))
     (same-rank "killed" "Running" "onRestart")) #:splines "ortho"))

(scale (inset (digraph->pict d) 10) 0.8)
}

 @figure[
 "android-activity-lifecycle"
 "Android Activity Lifecycle"
@digraph->pict-cached[@(make-digraph
   `(("Start" #:label "Activity Starts" #:shape ,start-pict)
     ("onCreate" #:label "onCreate()" #:shape ,node-pict)
     ("onStart" #:label "onStart()" #:shape ,node-pict)
     ("onResume" #:label "onResume()" #:shape ,node-pict)
     ("Running" #:label "Activity Running" #:shape ,running-pict)
     ("onPause" #:label "onPause()" #:shape ,node-pict)
     ("onStop" #:label "onStop()" #:shape ,node-pict)
     ("onDestroy" #:label "onDestroy()" #:shape ,terminal-pict)
     ("onRestart" #:label "onRestart()" #:shape ,node-pict)
     ("killed" #:label "Process is Killed" #:shape ,terminal-pict)
     (edge ("Start" "onCreate" "onStart" "onResume" "Running") #:weight "7")
     (edge ("Running" "onPause") #:label "Another activity activates" #:weight "7")
     (edge ("onPause" "onStop") #:label "Activity is no longer visible" #:weight "7")
     (edge ("onStop" "onDestroy") #:weight "7")
     (edge ("onPause" "onResume"))
     (edge ("onStop" "onRestart") #:label "Activity comes to foreground")
     (edge ("onRestart" "onStart"))
     (edge ("onStop" "killed"))
     (edge ("killed" "onCreate"))
     (same-rank "killed" "Running" "onRestart")) #:splines "ortho")]]

@subsection{Turnstile State Machine}

@codeblock{
(make-digraph
   `(("Locked" #:shape "circle" #:width "1.2")
     ("Unlocked" #:shape "circle" #:width "1.2")
     (edge ("Locked:n" "Locked:n") #:label "Push")
     (edge ("Locked" "Unlocked") #:label "Coin")
     (edge ("Unlocked" "Locked") #:label "Push")
     (edge ("Unlocked:n" "Unlocked:n") #:label "Coin")
     (same-rank "Locked" "Unlocked")))
}

@digraph->pict-cached[@(make-digraph
   `(("Locked" #:shape "circle" #:width "1.2")
     ("Unlocked" #:shape "circle" #:width "1.2")
     (edge ("Locked:n" "Locked:n") #:label "Push")
     (edge ("Locked" "Unlocked") #:label "Coin")
     (edge ("Unlocked" "Locked") #:label "Push")
     (edge ("Unlocked:n" "Unlocked:n") #:label "Coin")
     (same-rank "Locked" "Unlocked")))
]

@section{Installation and Rendering Limits}

Install Graphviz separately, verify @tt{dot -Tjson}, then install the
@tt{graphviz} Racket package. JSON support was introduced in Graphviz
2.40.0; the executable's actual output capabilities are authoritative.
The library does not start Graphviz merely because it is imported.

The renderer supports filled and unfilled ellipses, polygons and cubic
splines, polylines, RGB/RGBA colors, custom pict nodes, and all six drawing
arrays for graph/node/edge labels and arrows. Font styles combine, and
head/tail labels are retained. Installed requested faces take precedence. Missing faces use compatible
aliases, such as Nimbus Roman for Times-Roman, followed by the drawing
backend's family fallback. Exact rasterization is platform dependent. Gradients and external image
instructions currently produce contextual unsupported-feature errors.

All exports from @racketmodname[pict] continue to be re-exported for
compatibility. The default vertex shape remains @tt{none}. Existing raw
struct layouts and constructors are preserved. Use an explicit one-item
node list for a literal name containing @tt{->}; bare strings containing
that sequence retain the convenience edge-chain interpretation.
