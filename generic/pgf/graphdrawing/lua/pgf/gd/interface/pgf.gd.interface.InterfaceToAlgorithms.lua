-- Copyright 2012 by Till Tantau
--
-- This file may be distributed an/or modified
--
-- 1. under the LaTeX Project Public License and/or
-- 2. under the GNU Public License
--
-- See the file doc/generic/pgf/licenses/LICENSE for more information

-- @release $Header$



---
-- This class provides the interface between the graph drawing system
-- and algorithms. Another class, |InterfaceToDisplay|, binds the
-- display layers (like \tikzname\ or a graph drawing editor) to the
-- graph drawing system ``from the other side''. 
--
-- The functions declared here can be used by algorithms to
-- communicate with the graph drawing system, which will usually
-- forward the ``requests'' of the algorithms to the display layers in
-- some way. For instance, when you declare a new parameter, this
-- parameter will become available on the display layer. 

local InterfaceToAlgorithms = {}

-- Namespace
require("pgf.gd.interface").InterfaceToAlgorithms = InterfaceToAlgorithms


-- Imports
local InterfaceCore      = require "pgf.gd.interface.InterfaceCore"
local InterfaceToDisplay = require "pgf.gd.interface.InterfaceToDisplay"

local LookupTable        = require "pgf.gd.lib.LookupTable"
local LayoutPipeline     = require "pgf.gd.control.LayoutPipeline"

local Edge               = require "pgf.gd.model.Edge"




-- Forwards

local declare_parameter
local declare_parameter_sequence
local declare_algorithm
local declare_collection_kind


---
-- This function is the ``work-horse'' for declaring things. It allows
-- you to specify on the algorithmic layer that a key ``is available''
-- for use on the display layer. There is just one function for
-- handling all declarations in order to make the declarations
-- easy-to-use since you just need to import a single function:
--
--\begin{codeexample}[code only]
--local declare = require "pgf.gd.interface.InterfaceToAlgorithms".declare
--\end{codeexample}
--
-- You can now use |declare| it as follows: You pass it a table
-- containing information about the to-be-declared key. The table
-- \emph{must} have a field |key| whose value is unique and must be a
-- string. If the value of |key| is, say, |"foo"|, the 
-- parameter can be set on the display layer such as, say, the 
-- \tikzname\ layer, using |/graph drawing/foo|. Here is a typical
-- example of how a declaration is done: 
--
--\begin{codeexample}[code only]
-- ---
-- declare {
--   key     = "electrical charge",
--   type    = "number",
--   initial = "1.0",
--
--   summary = "The ``electrical charge'' is a property...",
--   documentation = [[...]],
--   examples = [[...]]
-- }
--\end{codeexample}
--
-- The three keys |summary|, |documentation| and |examples| are
-- intended for the display layer to give the users information about
-- what the key does. The |summary| should be a string that succinctly
-- describes the option. This text will typically be displayed for
-- instance as a ``tool tip'' or in an option overview. The
-- |documentation| optionally provides more information and should be
-- typeset using \TeX. The |examples| can either be a single string or
-- an array of strings. Each should be a \tikzname\ example
-- demonstrating how the key is used.
--
-- Note that you can take advantage of the Lua syntax of enclosing
-- very long multi-line strings in [[ and ]]. As a bonus, if the
-- summary, documentation, or an example starts and ends with a quote,
-- these two quotes will be stripped. This allows you to enclose the
-- whole multi-line string (additionally) in quotes, leading to better
-- syntax highlighting in editors.
--
-- Now, as metioned above, |declare| is a work-horse that will call
-- different internal functions depending on whether you declare a
-- parameter key or a new algorithm or a collection kind. Which kind
-- of declaration is being done is detected by the presence of certain
-- fields in the table passed to |t|. The different kind of
-- possible declarations are documented in the |declare_...|
-- functions. Note that these functions are internal and cannot be
-- called from outside; you must use the |declare| function.
--
-- @param t A table contain the field |key| and other fields as
-- described.

function InterfaceToAlgorithms.declare (t)
  local keys = InterfaceCore.keys
  
  -- Sanity check:
  assert (type(t.key) == "string" and t.key ~= "", "parameter key may not be the empty string")
  if keys[t.key] or t.key == "collections" or t.keys == "algorithm_phases" then
    error("parameter '" .. t.key .. "' already declared")
  end

  -- Detect kind
  if t.type then
    declare_parameter(t)
  elseif t.algorithm then
    declare_algorithm(t)
  elseif t.layer then
    declare_collection_kind(t)
  else
    -- Parameter sequence
    declare_parameter_sequence(t)
  end
    
  -- Set!
  keys[t.key]     = t
  keys[#keys + 1] = t
  
end



---
-- This function is called by |declare| for ``normal parameter keys.''
-- They are detected by the presence of the |type| field in the table
-- |t| passed to |declare|. Suppose you write
--
--\begin{codeexample}[code only]
-- ---
-- -- The |electrical charge| is a property of a node that is used in
-- -- force directed algorithms... (description of the parameter,
-- -- will be used in the automatic documentation.)
--
-- declare {
--   key     = "electrical charge",
--   type    = "number",
--   initial = "1.0",
-- }
--\end{codeexample}
--
-- Now, when an author writes |my node[electrical charge=5-3]| in the
-- description of her graph, the object |vertex| corresponding to the
-- node |my node| will have a field |options| attached to it with
--\begin{codeexample}[code only]
--vertex.options["electrical charge"] == 2
--\end{codeexample}
--
-- The |type| is not the same as Lua types. Rather, these types are
-- sensible types for graph drawing and they are mapped by the higher
-- layers to Lua types. In detail, the following types are available:
--
-- \begin{itemize}
-- \item |number| A dimensionless number. Will be mapped to a normal
-- Lua |number|. So, when the author writes |foo=5*2|, the |foo| key
-- of the |options| field of the corresponding object will be set to
-- |10.0|.
-- \item |length| A ``dimension'' in the sense of \TeX\ (a number with
-- a dimension like |cm| attached to it). It is the job of the display
-- layer to map this to a number in ``\TeX\ points,'' that is, to a
-- multiple of $1/72.27$th of an inch.
-- \item |string| Some text. Will be mapped to a Lua |string|.
-- \item |canvas coordinate| A position on the canvas. Will be mapped
-- to a |model.Coordinate|.
-- \item |boolean| A Boolean value.
-- \item |raw| Some to-be-executed Lua text.
-- \item |direction| Normally, an angle; however,
-- the special values of |down|, |up|, |left|, |right| as well as the
-- directions |north|, |north west|, and so on are also legal on the
-- display layer. All of them will be mapped to a number. Furthermore,
-- a vertical bar (\verb!|!) will be mapped to |-90| and a minus sign
-- (|-|) will be mapped to |0|.
-- \end{itemize}
--
-- A parameter can have an |initial| value. This value will be used
-- whenever the parameter has not been set explicitly for an object.
--
-- A parameter can have a |default| value. This value will be used as
-- the parameter value whenever the parameter is explicitly set, but
-- no value is provided.
--
-- (You cannot call this function directly, it is included for
-- documentation purposes only.)
--
-- @param t The table originally passed to |declare|.

function declare_parameter (t)
  -- Normal key
  assert (type(t.type) == "string", "key type must be a string")
  
  -- Declare via the hub:
  InterfaceCore.binding:declareParameterCallback(t)

end



---
-- This function is called by |declare| for ``parameters sequence
-- keys.'' They are detected by the presence numeric fields in the table
-- |t| passed to |declare|. Such a key stores a sequence of parameters
-- that get set ``all at once'' when a the key is used (this is
-- exactly the same as a \emph{style} in \tikzname). They only trigger
-- some ``real'' parameter keys to be set; they do not set any fields
-- in |options| tables. 
--
-- The sequence of keys is stored in the numeric fields (the array
-- part) of the |t| table. Each entry must have at least a |key| key and,
-- possibly, a |value| key. Here is an example:
--
--\begin{codeexample}[code only]
-- ---
-- -- The |binary tree layout| places node under the assumption that
-- -- the graph is a binary tree. This means, in particular, ...
-- -- (description of the parameter, will be used in the automatic
-- -- documentation.)
--
-- declare {
--   key = "binary tree layout",
--   { key = "minimum number of children", value = 2 },
--   { key = "significant sep",            value = 12 },
--   { key = "tree layout" },
-- }
--\end{codeexample}
--
-- You can also provide a |default| value. The reason for this is that
-- inside the values of the sequence, you can use the special string
-- |"#1"| to refer to the value passed to the key (this works as for
-- styles in \tikzname).
--
-- (You cannot call this function directly, it is included for
-- documentation purposes only.)
--
-- @param t The table originally passed to |declare|.
--

function declare_parameter_sequence (t)
  InterfaceCore.binding:declareParameterSequenceCallback(t)
end


---
-- This function is called by |declare| for ``algorithm
-- keys.'' They are detected by the presence of the field |algorithm|
-- in the table |t| passed to |declare|. Here is an example of how it
-- is used:
--\begin{codeexample}[code only]
-- local ReingoldTilford1981 = {}
--
-- ---
-- -- The Reingold--Tilford method is a standard method for drawing
-- -- trees. It is described in: ...
--
-- declare {
--   key       = "tree layout",
--   algorithm = ReingoldTilford1981,
--
--   preconditions = {
--     connected = true,
--     tree      = true
--   },
--
--   postconditions = {
--     upward_oriented = true
--   }
-- }
--
-- function ReingoldTilford1981:run()
--   ...
-- end
--\end{codeexample}
--
-- The |algorithm| field expects either a table or a string as
-- value. If you provide a string, then |require| will be applied to
-- this string to obtain the table; however, this will happen only
-- when the key is actually used for the first time. This means that
-- you can declare (numerous) algorithms in a library without these
-- algorithms actually being loaded until they are needed.
--
-- Independently of how the table is obtained, it will be ``upgraded''
-- to a class by setting its |__index| field and installing a static
-- |new| function (which takes a table of initial values as
-- argument). Both these settings will only be done if they have not
-- yet been performed.
--
-- Next, you can specify the fields |preconditions| and
-- |postconditions|. The preconditions are a table that tell the graph
-- drawing engine what kind of graphs your algorithm expects. If the
-- input graph is not of this kind, it will be automatically
-- transformed to meet this condition. Similarly, the postconditions
-- tell the engine about properties of your graph after the algorithm
-- has run. Again, additional transformations may be performed.
--
-- You can also specify the field |phase|. This tells the graph
-- drawing engine which ``phase'' of the graph drawing process your
-- option applies to. Each time you select an algorithm later on
-- through use of the algorithm's key, the algorithm for this phase
-- will be set; algorithms of other phases will not be changed. So,
-- for instance, when an algorithm is part of the spanning tree
-- computation, its phase will be |"spanning tree computation"| and
-- using its key does not change the main algorithm, but only the
-- algorithm used during the computation of a spanning tree for the
-- current graph (in case this is needed by the main algorithm). In
-- case the |phase| field is missing, the phase |main| is used. Thus,
-- when no phase field is given, the key will change the main
-- algorithm used to draw the graph.
--
-- Later on, the algorithm set for the current phase can be accessed
-- through the special |algorithm_phases| field of |options|
-- tables. The |algorithm_phases| table will contain a field for each
-- phase for which some algorithm has been set.
--
-- The following example shows the declaration of an algorithm that is
-- the default for the phase |spanning tree computation|:
--
--\begin{codeexample}[code only]
-- ---
-- -- This key selects ``breadth first'' as the (sub)algorithm for
-- -- computing spanning trees. Note that ...
-- declare {
--   key = "breadth first spanning tree",
--   algorithm = { 
--     run =
--       function (self)
--         return SpanningTreeComputation.computeSpanningTree(self.ugraph, false, self.events)
--       end
--   },
--   phase = "spanning tree computation",
--   default = true,
-- }
--\end{codeexample}
--
-- The algorithm is called as follows during a run of the main
-- algorithms:
--
--
--\begin{codeexample}[code only]
-- local graph = ... -- the graph object
-- local spanning_algorithm_class = graph.options.algorithm_phases["spanning tree computation"]
-- local spanning_algorithm =
--   spanning_algorithm_class.new{
--     ugraph = ugraph,
--     events = scope.events
--   }
-- local spanning_tree = spanning_algorithm:run()
--\end{codeexample}
--
-- If you set the |default| field of |t| to |true|, the algorithm will
-- be installed as the default algorithm for the phase. This can be
-- done only once per phase. Furthermore, for such a default algorithm
-- the |algorithm| key must be table, it may not be a phase (in other
-- words, all default algorithms are loaded immediately).
--
-- (You cannot call this function directly, it is included for
-- documentation purposes only.)
--
-- @param t The table originally passed to |declare|.

function declare_algorithm (t)
  -- Algorithm declaration!
  assert(type(t.algorithm) == "table" or type(t.algorithm) == "string")
      
  t.phase = t.phase or "main"

  local function make_class ()
    local class

    if type(t.algorithm) == "table" then
      class = t.algorithm
    else
      class = require(t.algorithm)
    end
  
    -- First, setup indexing, if necessary
    if not class.__index then
      class.__index = class
    end
  
    -- Second, setup new method, if necessary
    class.new = class.new or 
      function (initial) 
      
	-- Create new object
	local obj = {}
	for k,v in pairs(initial) do
	  obj[k] = v
	end
	setmetatable(obj, class)
	
	return obj
      end
  
    -- Now, save pre- and postconditions
    class.preconditions  = t.preconditions or {}
    class.postconditions = t.postconditions or {}

    -- Save phase
    class.phase          = t.phase

    -- Compatibility
    class.old_graph_model = t.old_graph_model

    return class
  end

  -- Store this:
  local store_me
  if type(t.algorithm) == "table" then
    store_me = make_class()
  else
    store_me = make_class
  end
  
  -- Save in the algorithm_classes table:
  InterfaceCore.algorithm_classes[t.key] = store_me
  
  -- Install!
  InterfaceCore.binding:declareAlgorithmCallback(t)
  
  if t.default then
    assert (not InterfaceCore.option_initial.algorithm_phases[t.phase],
	    "default algorithm for phase already set")
    assert (type(store_me) == "table",
	    "default algorithms must be loaded immediately")
    InterfaceCore.option_initial.algorithm_phases[t.phase] = store_me
  end 
end



---
-- This function is called by |declare| for ``collection kinds.'' They
-- are detected by the presence of the field |layer| 
-- in the table |t| passed to |declare|. See the class |Collection|
-- for details on what a collection and a collection kind is.
--
-- The |key| field of the table |t| passed to this function is both
-- the name of the to-be-declared collection kind as well as the key
-- that is used on the display layer to indicate that a node or edge
-- belongs to a collection. 
--
-- \medskip
-- \noindent\textbf{The Display Layer.}
-- Let us first have a look at what happens on the display layer: 
-- A key |t.key| is setup on the display layer that, when used inside
-- a graph drawing scope, starts a new collection of the specified
-- kind. ``Starts'' means that all nodes and edges mentioned in the
-- rest of the current option scope will belong to a new collection
-- of kind |t.key|. 
-- 
--\begin{codeexample}[code only]
--declare { key = "hyper", layer = 1 }
--\end{codeexample}
-- you can say on the \tikzname\ layer
--\begin{codeexample}[code only] 
-- \graph {
--   a, b, c, d;
--   { [hyper] a, b, c }
--   { [hyper] b, c, d }
-- };
--\end{codeexample}
-- 
-- In this case, the nodes |a|, |b|, |c| will belong to a collection of
-- kind |hyper|. The nodes |b|, |c|, and |d| will (also) belong to
-- another collection of the same kind |hyper|. You can nest
-- collections; in this case, nodes will belong to several
-- collections. 
--
-- The effect of declaring a collection kind on the algorithm layer
-- it, first of all, that |scope.collections| will have a field named
-- by the collection kind. This field will store an array that
-- contains all collections that were declared as part of the
-- graph. For instance, |collections.hyper| will contain all
-- hyperedges, each of which is a table with the following fields: The
-- |vertices| and |edges| fields each contain arrays of all objects
-- being part of the collection. The |sub| field is an array of
-- ``subcollections,'' that is, all collections that were started
-- inside another collection. (For the collection kinds |hyper| and
-- |same layer| this makes no sense, but subgraphs could, for instance,
-- be nested.)
-- 
-- \medskip
-- \noindent\textbf{Rendering of Collections.}
-- For some kinds of collections, it makes sense to \emph{render} them,
-- but only after the graph drawing algorithm has run. For this
-- purpose, the binding layer will use a callback for each collection
-- kind and each collection, see the |Binding| class for details. 
-- Suppose, for instance, you would
-- like hyperedges to be rendered. In this case, a graph drawing
-- algorithm should iterate over all collections of type |hyper| and
-- compute some hints on how to render the hyperedge and store this
-- information in the |generated_options| table of the hyperedge. Then,
-- the binding layer will ask the dislay layer to run some some code
-- that is able to read key--value pairs passed to 
-- it (which are the key--value pairs of the |generated_options| table)
-- and use this information to nicely draw the hyperedge.
--
-- The number |t.layer| determines in which order the different
-- collection kinds are rendered.
-- 
-- The last parameter, the layer number, is used to specify the order
-- in which the different collection kinds are rendered. The higher the
-- number, the later the collection will be rendered. Thus, if there is
-- a collection kind with layer number 10 and another with layer number
-- 20, all collections of the first kind will be rendered first,
-- followed by all collections of the second kind.
-- 
-- Collections whose layer kinds are non-negative get rendered
-- \emph{after} the nodes and edges have already been rendered. In
-- contrast, collections with a negative layer number get shown
-- ``below'' the nodes and edges.
--
-- (You cannot call this function directly, it is included for
-- documentation purposes only.)
-- 
-- @param t The table originally passed to |declare|.

function declare_collection_kind (t)
  assert (type(t.layer) == "number", "layer must be a number")

  local layer = t.layer
  local kind  = t.key
  local kinds = InterfaceCore.collection_kinds
  local new_entry = { kind = kind, layer = layer }
  
  -- Insert into table part:
  kinds[kind] = new_entry

  -- Insert into array part:  
  local found
  for i=1,#kinds do
    if kinds[i].layer > layer or (kinds[i].layer == layer and kinds[i].kind > kind) then
      table.insert(kinds, i, new_entry)
      return
    end
  end

  kinds[#kinds+1] = new_entry
  
  -- Bind
  InterfaceCore.binding:declareCollectionKind(t)
end



---
-- Finds a node by its name. This method should be used by algorithms
-- for which a node name is specified in some option and, thus, needs
-- to be converted to a vertex object during a run of the algorithm.
--
-- @param name A node name
--
-- @return The vertex of the given name in the syntactic digraph or
-- |nil|.

function InterfaceToAlgorithms.findVertexByName(name)
  return InterfaceCore.topScope().node_names[name]
end





-- Helper function
local function add_to_collections(collection,where,what)
  if collection then
    LookupTable.addOne(collection[where],what)
    add_to_collections(collection.parent,where,what)
  end
end

local unique_count = 1

---
-- Generate a new vertex in the syntactic digraph. Calling this method
-- allows algorithms to create vretices that are not present in the
-- original input graph. Using the graph drawing coroutine, this
-- function will pass back control to the display layer in order to
-- render the vertex and, thereby, create precise size information
-- about it.
--
-- Note that creating new vertices in the syntactic digraph while the
-- algorithm is already running is a bit at odds with the notion of
-- treating graph drawing as a series of graph transformations: For
-- instance, when a new vertex is created, the graph will (at least
-- temporarily) no longer be connected; even though an algorithm may
-- have requested that it should only be fed connected
-- graphs. Likewise, more complicated requirements like insisting on
-- the graph being a tree also cannot be met.
--
-- For these reasons, the following happens, when a new vertex is
-- created using the function:
--
-- \begin{enumerate}
-- \item The vertex is added to the syntactic digraph.
-- \item It is added to all layouts on the current layout stack. When
-- a graph drawing algorithm is run, it is not necessarily run on the
-- original syntactic digraph. Rather, a sequence / stack of nested
-- layouts may currently 
-- be processed and the vertex is added to all of them.
-- \item The vertex is added to both the |digraph| and the |ugraph| of
-- the current algorithm.
-- \end{enumerate}
--
-- @param algorithm An algorithm for whose syntactic digraph the node
-- should be added  
-- @param init  A table of initial values for the node that is passed
-- to |Binding:createVertex|, see that function for details. 
--
-- @return The newly created node
--
function InterfaceToAlgorithms.createVertex(algorithm, init)

  -- Setup
  local scope = InterfaceCore.topScope()
  local binding = InterfaceCore.binding
    
  -- Setup node
  if not init.name then
    init.name = "internal@gd@node@" .. unique_count
    unique_count = unique_count + 1
  end

  -- Does vertex already exist?
  assert (not scope.node_names[name], "node already created")
  
  if not init.shape or init.shape == "none" then
    init.shape = "rectangle"
  end
  
  -- Call binding
  binding:createVertex(init)
  
  local v = assert(scope.node_names[init.name], "internal node creation failed")
  
  -- Add vertex to the algorithm's digraph and ugraph
  algorithm.digraph:add {v}  
  algorithm.ugraph:add {v}
  
  -- Compute bounding boxes:  
  LayoutPipeline.prepareBoundingBoxes(algorithm, algorithm.digraph, {v})
  
  -- Add the node to the layout stack:
  add_to_collections(algorithm.layout, "vertices", v)
  
  return v
end



---
-- Generate a new edge in the syntactic digraph. This method is quite
-- similar to |createVertex| and has the same effects with respect to
-- the edge: The edge is added to the syntactic digraph and also to
-- all layouts on the layout stack. Forthermore, appropriate edges are
-- added to the |digraph| and the |ugraph| of the algorithm currently
-- running. 
--
-- @param algorithm An algorithm for whose syntactic digraph the node should be added 
-- @param tail A syntactic tail vertex
-- @param head A syntactic head vertex
-- @param init A table of initial values for the edge.
--
-- The following fields are useful for |init|:
--
-- @param init.direction If present, a direction for the edge. Defaults to "--".
-- @param init.options If present, some options for the edge.
-- @param init.generated_options A table that is passed back to the
-- display layer as a list of key-value pairs in the syntax of
-- |declare_parameter|. 

function InterfaceToAlgorithms.createEdge(algorithm, tail, head, init)

  init = init or {}
  
  -- Setup
  local scope = InterfaceCore.topScope()
  local binding = InterfaceCore.binding
  local syntactic_digraph = scope.syntactic_digraph
  
  assert (syntactic_digraph:contains(tail) and
	  syntactic_digraph:contains(head),
	  "attempting to create edge between nodes that are not in the syntactic digraph")
  
  local arc = syntactic_digraph:connect(tail, head)

  local edge = Edge.new {
    head = head,
    tail = tail,
    direction = init.direction or "--",
    options = init.options or algorithm.layout.options,
    path = init.path,
  }

  -- Add to arc    
  arc.syntactic_edges[#arc.syntactic_edges+1] = edge
  
  -- Create Event
  local e = InterfaceToDisplay.createEvent ("edge", { arc, #arc.syntactic_edges })
  edge.event = e
  
  -- Make part of collections
  for _,c in ipairs(edge.options.collections) do
    LookupTable.addOne(c.edges, edge)
  end

  -- Call binding
  edge.storage[binding] = {}
  binding:everyEdgeCreation(edge)
  
  -- Add edge to digraph and ugraph
  local direction = edge.direction
  if direction == "->" then
    algorithm.digraph:connect(tail, head)
  elseif direction == "<-" then
    algorithm.digraph:connect(head, tail)
  elseif direction == "--" or direction == "<->" then
    algorithm.digraph:connect(tail, head)
    algorithm.digraph:connect(head, tail)
  end
  algorithm.ugraph:connect(tail, head)
  algorithm.ugraph:connect(head, tail)

  -- Add edge to layouts
  add_to_collections(algorithm.layout, "edges", edge)
  
end




-- Done 

return InterfaceToAlgorithms