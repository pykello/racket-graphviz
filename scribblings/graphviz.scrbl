#lang scribble/manual
@require[@for-label[graphviz
                    racket/base
                    pict]]
@require[graphviz
         scriblib/figure
         "utils.rkt"]

@title{Racket Graphviz Integration}
@author{@(author+email "Hadi Moshayedi" "hadi@moshayedi.net")}
@defmodule[graphviz]
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

@subsection{Defining Subgraphs}
@defproc[(make-digraph [definitions list?] [#:ortho ortho boolean?]) digraph?]{
 Creates a digraph. "definitions" is a list of vertex, edge, or subgraph
 definitions.
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
 @item{A list like @tt{(edge [node1 ...] #:attr1 val1 ...)}.}
 ]}
 @item{
  @bold{Subgraph Definitions.} A subgraph can be defined using @tt{(subgraph label definitions)}}]


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


@defproc[(make-vertex [label string?] [#:shape shape (or/c pict? string?)]) vertex?]{
}

@subsection{Conversion to Pict}
@defproc[(digraph->pict [digraph digraph?]) pict?]{
 Converts the given digraph to a @racket[pict].
}

@defproc[(dot->pict [definition string?]) pict?]{
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

@subsection{Structs}

@defstruct[digraph ([objects list?] [ortho boolean?]) #:omit-constructor]{
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
