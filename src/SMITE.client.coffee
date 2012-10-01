
# smite-client
Backbone = require 'backbone-browserify'
_ = require 'underscore'

#──────────────────────────────────────────────────────
# Export
#──────────────────────────────────────────────────────

module.exports = SMITECLIENT = {}

#──────────────────────────────────────────────────────
# Import SMITECLIENT like a SMITE plugin
#──────────────────────────────────────────────────────

SMITECLIENT.use = (SMITE, settings) ->
  for attr in ['version', 'error', 'warn', 'info', 'debug', 'throw', 'clone', 'ErrorCode']
    SMITECLIENT[attr] = SMITE[attr]

  SMITECLIENT.settings = settings

  'client'

#──────────────────────────────────────────────────────
# References
#──────────────────────────────────────────────────────

SMITECLIENT.Backbone = Backbone
SMITECLIENT.models = {}           # Store of models in smite
SMITECLIENT.modelsById = {}       # Store of models by id.
SMITECLIENT.options = {}          # Options passed from server.
#──────────────────────────────────────────────────────
# Helpers
#──────────────────────────────────────────────────────

# _pluckMap ({a1:{b1:1, b2:2}, a2:{b1:1, b2:2}}, 'b1') => {a1:1, a2:1}
_pluckMap = (map, key) ->
  out = {}
  for k,v of map
    if _.isObject(v) and v[key] != undefined
      out[k] = v[key]
  out

# _mapMap( {a1:1, a2: 2, a3: 3} , (v) -> v+1 ) => {a1:2, a2:3, a3, 4}
_mapMap = (map, fn) ->
  if _.isArray map
    return _.map map, fn
  out = {}
  for k,v of map
    if (result = fn(v, k)) != undefined
      out[k] = result
  out

# _transposeMap( [{a1: {b1: 1, b2: 'str1'}, {a2: {b1: 2, b2: 'str2'}] )
#   returns: {b1: {a1: 1, a2: 2}, b2: {a1: 'str1', a2: 'str2'}
_transposeMap = (obj) ->
  out = {}
  for key, obj2 of obj
    for key2, val of obj2
      out[key2] ?= {}
      out[key2][key] = val
  out

_unionKeys = ->
  obj = {}
  for arg in arguments
    for k of arg
      obj[k] = 1
  ans = []
  for k of obj
    ans.push k
  ans

#──────────────────────────────────────────────────────
# Error Codes
#──────────────────────────────────────────────────────

# SMITE can sometimes specially handle errors of the form:
# {code: <ErrorCode>, message: <message>}
SMITECLIENT.ErrorCode =
  NotFound: ['NotFound']
  ValidationFailed: ['ValidationFailed']


#──────────────────────────────────────────────────────
# Validation
#──────────────────────────────────────────────────────

_.extend SMITECLIENT,
  inList: (list) -> (v, prop) ->               if not list?.indexOf? or list.indexOf(v) == -1 then         "#{prop}: #{v} is not in list: #{list}"
  inEnum: (enumList) -> (v, prop) ->           if not enumList?.indexOf? or enumList.indexOf(v) == -1 then "#{prop}: #{v} is not in enum: #{enumList}"

  range: (min, max) -> (v, prop) ->            if v < min or max < v then                "#{prop}: #{v} is not in range: [#{min}, #{max}]"
  min: (min) -> (v, prop) ->                   if v < min then                           "#{prop}: #{v} is too small for min: #{min}"
  max: (max) -> (v, prop) ->                   if v > max then                           "#{prop}: #{v} is too large for max: #{max}"
  lessThan: (num) -> (v, prop) ->              if v >= num then                          "#{prop}: #{v} is too large for lessThan: #{num}"
  moreThan: (num) -> (v, prop) ->              if v <= num then                          "#{prop}: #{v} is too small for moreThan: #{num}"

  lengthRange: (min, max) -> (v, prop) ->      if not v?.length? or v.length < min or max < v.length then  "#{prop}: #{v}.length is not in range: [#{min}, #{max}]"
  lengthMin: (min) -> (v, prop) ->             if not v?.length? or v.length < min then                    "#{prop}: #{v}.length is too small for min: #{min}"
  lengthMax: (max) -> (v, prop) ->             if not v?.length? or v.length > max then                    "#{prop}: #{v}.length is too large for max: #{max}"
  lengthLessThan: (num) -> (v, prop) ->        if not v?.length? or v.length >= num then                   "#{prop}: #{v}.length is too large for lessThan: #{num}"
  lengthMoreThan: (num) -> (v, prop) ->        if not v?.length? or v.length <= num then                   "#{prop}: #{v}.length is too small for moreThan: #{num}"

#──────────────────────────────────────────────────────
# ModelView
#──────────────────────────────────────────────────────


SMITECLIENT.modelview = (name, data = {}) ->

  lastPeriod = name.lastIndexOf '.'
  SMITECLIENT.throw 'SMITE.modelview expected the first argument to be a name (type: String)' unless _.isString name
  SMITECLIENT.throw 'SMITE.modelview expected the first argument to contain a period (example: `Model.View`)' unless lastPeriod != -1
  SMITECLIENT.throw 'SMITE.modelview expected the second argument to be the modelview definition (type: Object)' unless _.isObject data

  # name == 'Model.View.View2' => parentName = 'Model.View', baseName = 'View2'
  parentName = if lastPeriod == -1 then null else name.slice 0, lastPeriod
  baseName = if lastPeriod == -1 then null else name.slice lastPeriod+1

  toModel = data.toModel

  # Add toModel and fromModel methods
  _.extend data,
    constructor: (args = {}) ->
      # Passed a model Create pass through arguments to modelview
      if args instanceof Backbone.Model
        parentModel = args

        # Limit keys to those specified in modelview
        argsModelView = {}
        for attr of parentModel.attributes
          # If this attr is also defined as an attr in the modelview
          if _.isObject data[attr]
            argsModelView[attr] = parentModel.attributes[attr]

        # Pass through id if it is present
        if parentModel.attributes.id?
          argsModelView.id = parentModel.attributes.id

        # Apply the custom conversion method to modify argsModelView
        data.fromModel?.call(argsModelView, parentModel.attributes, argsModelView)

      # Otherwise these are the attributes construct the modelview with them
      else if _.isObject args
        argsModelView = args

      else
        throw "SMITE ERROR: #{name} modelview expects model or argument object"


      # Construct backbone modelview with calculated args using super
      @constructor.__super__.constructor.call @, argsModelView

    toModel: ->
      # Create pass through arguments to model
      argsModel = {}
      for attr in _.union _.keys(@attributes), ['id']
        if @attributes[attr]?
          argsModel[attr] = @attributes[attr]

      # Apply custom conversion method to modify argsModel
      toModel?.call(@attributes, argsModel)

      # Give them the model they so desire
      if ParentModel = @_modelParent()
        new ParentModel argsModel

  # Return backbone model
  modelViewOut = SMITECLIENT.model name, data

  # Keep a reference to model view for easy lookup
  # console.log 'SMITECLIENT.models:\n', SMITECLIENT.models
  SMITECLIENT.models[name] = modelViewOut

  # Keep a reference on the parent model as well if we have a reference to it
  # (On the client we won't have one, on the server we will)
  SMITECLIENT.models[parentName]?[baseName] = modelViewOut

  modelViewOut

#──────────────────────────────────────────────────────
# Model
#──────────────────────────────────────────────────────

SMITECLIENT.model = (name, data = {}) ->

  SMITECLIENT.throw 'SMITE.model expected string as first argument' unless _.isString name
  SMITECLIENT.throw 'SMITE.model expected object as second argument' unless _.isObject data

  # name == 'Model.View.View2' => parentName = 'Model.View', baseName = 'View2'
  lastPeriod = name.lastIndexOf '.'
  parentName = if lastPeriod == -1 then null else name.slice 0, lastPeriod
  baseName = if lastPeriod == -1 then name else name.slice lastPeriod+1

  # Helper function to determine if the model needs to keep track of its parent model
  needsParent = (value) -> (value instanceof Backbone.Model and not value.collection) or value instanceof Backbone.Collection

  # Convert value to a partial of itself (must be bb model)
  makePartial = (v) -> v._partial()

  # Determine if type is a model
  isModelType = (attr) -> _.isString modelAttributeTypes[attr]

  modelValidations = _pluckMap data, 'validate'
  modelRequired = _pluckMap data, 'required'
  modelDefaults = _pluckMap data, 'default'
  modelAttributeTypes = _pluckMap data, 'type'
  modelValidator = if _.isFunction data.validate then _data.validate else null

  extender =
    # Defaults pass through
    validations: modelValidations
    required: modelRequired
    defaults: modelDefaults
    attributeTypes: modelAttributeTypes

    # Route by name
    urlRoot: "/#{name}"

    # Validate by attribute
    # TODO: Verify model type matches schema
    validate: (attributes) ->
      validationError = (msg) ->
          if msg then {code: SMITECLIENT.ErrorCode.ValidationFailed, message: msg} else null
      for attr in _unionKeys attributes, @validations
        value = attributes[attr]
        # Check that the attribute exists in this model
        if (attr != 'id') and not @attributeTypes[attr]
          return validationError "Model doesn't allow attribute #{attr}"
        # Check if the attribute is required, else accept null
        if value == undefined
          return if (@required[attr] == true) then validationError "Model requires attribute #{attr}" else null
        # Check that the attribute passes validation on its own
        if _.isFunction @validations[attr]
          validateResponse = @validations[attr](value, attr)
          if validateResponse
            return validationError validateResponse
      validationError modelValidator?(attrubutes)

    # Override constructor to prevent partials from defaulting values
    constructor: (attributes) ->
      # Pass through if partial isn't set
      if not attributes? or not attributes._partial
        return @constructor.__super__.constructor.apply @, [attributes]

      # Remove _partial from
      newAttributes = _.clone attributes
      delete newAttributes._partial

      # Override defaults in type to avoid constructing with them
      # This is horid, but better then rewriting the whole constructor here
      # and possibly breaking in future versions of backbone
      _defaults = @constructor.prototype.defaults
      @constructor.prototype.defaults = null
      out = @constructor.__super__.constructor.apply @, [newAttributes]

      # Restore defaults
      @constructor.prototype.defaults = _defaults
      out

    # Override fetch to support node-like callbacks
    fetch: (cb) ->
      if  _.isFunction cb
        opts = success:((m)-> cb(undefined,m)), error:(m,e)-> cb(e,m)
        @constructor.__super__.fetch.apply @, [opts]
      else
        @constructor.__super__.fetch.apply @, arguments

    # Override save to support node-like callbacks
    save: (cb) ->
      if  _.isFunction cb
        opts = success:((m)-> cb(undefined,m)), error:(m,e)-> cb(e,m)
        @constructor.__super__.save.apply @, [@attributes, opts]
      else
        @constructor.__super__.save.apply @, arguments

    # Override destroy to support node-like callbacks
    destroy: (cb) ->
      if  _.isFunction cb
        opts = success:((m)-> cb(undefined,m)), error:(m,e)-> cb(e,m)
        @constructor.__super__.destroy.apply @, [opts]
      else
        @constructor.__super__.destroy.apply @, arguments

    # Construct partial of model from the model
    _partial:  ->
      throw "Cannot get partial without an id. (cid = #{@cid})" unless @id?
      new @constructor id: @id, _partial: true

    # TODO: Add validation that it is the correct type
    # TODO: Add validation that the model is the correct model type
    # TODO: Consider auto converting model to modelview
    initialize: ->
      # Store model information in instance
      @_modelName = name
      @_modelBaseName = baseName
      @_modelParentName = parentName
      @_modelArgs = data
      @_model = (optionalName = name) -> SMITECLIENT.models[optionalName]
      @_modelParent = -> if not parentName then null else SMITECLIENT.models[parentName]

      # Map through attributes as properties
      for k,v of @attributes
        do (k) =>
          if _.isUndefined @[k]
            Object.defineProperty @, k,
              get: -> @get k
              set: (value) -> @set k, value
              enumerable: true
              configurable: false

      # Remember parent of attributes that contain models or collections
      for attr,v of @attributes
        if needsParent v
          v.parents ?= []
          v.parents.push {ref: @, attribute: attr}

      # Monitor events on ourself and forward them to our parent
      @on 'all', (type, model) =>
        parents = @parents || (@collection && @collection.parents)
        me = @ || @collection

        # Create a list of models that have already triggered this event
        lastArgIndex = arguments.length-1
        cycleGuard = arguments[lastArgIndex]
        if cycleGuard?.guard
          lastArgIndex--
        else
          cycleGuard = { guard: true, triggered: [@] }

        # Trigger on all of your parents
        if parents
          for parent in parents
            # Avoid triggering cycles
            continue if _.indexOf(cycleGuard.triggered, parent.ref) != -1
            cycleGuard.triggered.push parent.ref

            # Matches backbone event arguments
            changes = {}
            changes[parent.attribute] = true
            output = {changes: changes}
            if parent.ref
              if type == 'error'
                parent.ref.trigger type, parent.ref, _.toArray(arguments).slice(2, lastArgIndex).push(cycleGuard)...

              # Starts with 'change'
              else if type.lastIndexOf('change:', 0) == 0
                parent.ref.trigger "change:#{parent.attribute}", parent.ref, me, output, cycleGuard
                parent.ref.trigger 'change', parent.ref, output, cycleGuard

    # Override set to keep track of parent model references
    set: (_attr, _value) ->
      # Set supports either _attr, _value or _attr:_value syntax. Convert
      # both cases to _attr:_value so we can loop over all properties
      obj = {}
      if _.isString _attr
        obj[_attr] = _value
        args = Array.prototype.slice.call arguments, 2
      else
        obj = _.clone _attr
        args = Array.prototype.slice.call arguments, 1

      for attr, value of obj

        # Remove old parent references
        # These parent refences are kept so event notifications can be sent
        # parent models
        oldValue = @get(attr)
        if needsParent oldValue
          parents =  @get(attr)?.parents
          if parents
            oldValue.parents = _.reject parents, (parentObj) => parentObj.ref == @ && parentObj.attribute == attr

        # Add to new parent reference if this model needs them
        if needsParent value
          value.parents ?= []
          value.parents.push {ref: @, attribute: attr}

        # Models can be set by id or model. If they are set by id
        # then they should be turned automatically into partials
        # If they are set by id but the model already exists
        # nothing should happen
        if isModelType(attr) and value? and not (value instanceof Backbone.Model)
          # The model doesn't exist so make a partial of it
          if String(oldValue?.id) != String(value)
            modelType = modelAttributeTypes[attr]
            Model = SMITECLIENT.models[modelType]
            # Override with partial. Ensure id is a string
            obj[attr] = new Model _partial: true, id: String(value)
            return @constructor.__super__.set.apply @, [obj, args...]
          # The model does exist so don't set anything at this attribute
          else
            delete obj[attr]

      # Call super
      @constructor.__super__.set.apply @, [obj, args...]

    # Serialize to attribute object but replace models with partials
    toJSON: ->
      out = _mapMap @attributes, (value) ->
        if value instanceof Backbone.Model
          value.id
        else if value instanceof Backbone.Collection
          _.map value, (v) -> v.id
        else
          value
      out

  # Extend methods into backbone model
  for k,v of data when _.isFunction v
    if k != 'validate'
      extender[k] = v

  # Return backbone model
  modelOut = Backbone.Model.extend extender

  # Remember initial arguments
  _.extend modelOut,
    _modelArgs:       data
    _modelName:       name
    _modelParentName:   parentName
    _model:           (optionalName = name) -> SMITECLIENT.models[optionalName]
    _modelParent:       -> if not parentName then null else SMITECLIENT.models[parentName]
    validations:      modelValidations
    defaults:         modelDefaults
    attributeTypes:   modelAttributeTypes

  # Keep a reference for easy lookup by name
  SMITECLIENT.models[name] = modelOut

  modelOut

#──────────────────────────────────────────────────────
# Model Serialization (users shouldn't need to call these)
#──────────────────────────────────────────────────────

#───────────────────────────
# SMITECLIENT.ravel
#───────────────────────────

# Subscript automatically between obj['foobar'] and obj.foobar if possible
_subscript = (attr) ->
  if attr.match /^[a-z][a-z0-9_$]*$/i
    ".#{attr}"
  else
    "['#{attr}']"

_ravelStringify = (optionsPlain, optionsModels, store, storeName, optionsName) ->
  # Return a string of a function that takes (smite, models, options)
  output = """(function(s, m, o){ m = m || {};\n
  """

  # Require modules
  moduleTypes = _.unique _.map(store, (v) -> v.type)
  if moduleTypes.length > 0
    output += "var r = function(t){t2 = t.split('.')[0]; s[t2] = require('./models/' + t2)};\n"
    for v in moduleTypes
      output += "r('#{v}');\n"

  # Construct args
  for k, v of store
    {type: t, construct: c} = v
    output += "m#{_subscript(k)} = new s.#{t}(#{JSON.stringify(c)});\n"

  # Assign args
  for k, v of store
    {assign: assignArgs} = v
    for attr, id of assignArgs
      output += "m#{_subscript(k)}#{_subscript(attr)} = m#{_subscript(id)};\n"

  # Options args
  output += "require('underscore').extend(o, {\n"
  i = 1
  for k, v of optionsPlain
    comma = if i == 1 then '' else ', '
    output += "#{comma}'#{k}': #{JSON.stringify(v)}"
    i++
  for k, id of optionsModels
    comma = if i == 1 then '' else ', '
    output += "#{comma}'#{k}': m#{_subscript(id)}"
    i++

    # return value
  output += "\n});})(SMITE.models,#{storeName},#{optionsName});$ = require('jquery'); _ = require('underscore');\nBackbone = require('backbone');"

_ravelRecurse = (options, store, getIdFn, constructArgs = {}, assignArgs = {}) ->
  for k, v of options
    if v instanceof Backbone.Model
      if not store[getIdFn(v)]
        # console.log 'v: ', v
        store[getIdFn(v)] = type: v._modelName
        [innerConstructArgs, innerAssignArgs] = _ravelRecurse v.attributes, store, getIdFn
        _.extend store[getIdFn(v)],
          construct: innerConstructArgs
          assign: innerAssignArgs
      assignArgs[k] = getIdFn(v)
    else if v instanceof Backbone.Collection
      console.log "Backbone collection NYI"
    else if v?
      constructArgs[k] = v
  [constructArgs, assignArgs]

# Convert options to client readable options
# This is very hard:
#   1. Serialize into new constructors
#   2. Minimize characters sent to client
#   3. ...
SMITECLIENT.ravel = (options, storeName, optionsName, getIdFn = ((v)->v.id)) ->
  store = {}
  [constructArgs, assignArgs] = _ravelRecurse options, store, getIdFn
  _ravelStringify constructArgs, assignArgs, store, storeName, optionsName

#───────────────────────────
# SMITECLIENT.ravel
#───────────────────────────

# Take serialized json passed through network (or from database!)
# And construct them into SMITE.models while handling multiple references and cycles.
# SMITECLIENT.unravel = (attr, ModelView) ->

#──────────────────────────────────────────────────────
# SMITECLIENT.cache
#
# Cache to keep references shared across all models the same
# So if you query for something its children would be references
#──────────────────────────────────────────────────────

SMITECLIENT.cache = {}

# Internal store for the cache
_cache = {}

#───────────────────────────
# SMITECLIENT.cache.add
#───────────────────────────

# # Recursive helper for cache add
# _cacheAdd = (any, options) ->
#   recurse = arguments.callee


#   if any instanceof Backbone.Model
#     # Check cache and get / store
#     if not any.id
#       throw "Error: SMITE.cache.add cannot add a model without an id. (cid: #{any.cid})"
#     update = options.update
#     if not _cache[any.id]
#       _cache[any.id] = any
#       update = true
#     if update
#       _cache[any.id].set _.map _cache[any.id].attributes, ((v) ->
#         recurse v, options
#       ), silent: true
#       if any.hasChanged()
#         options._changed.push any
#     _cache[any.id]

#   if any instanceof Backbone.Model
#     throw "Error: SMITE.cache.add cannot add a model without an id. (cid: #{k.cid})"

#   else if any instanceof Backbone.Collection
#     # Do something
#     throw "Backbone collections NYI"
#   else if _.isObject any or _.isArray any
#     _mapMap any, (v) ->
#       recurse v, options
#   else
#     v

#───────────────────────────
# SMITECLIENT.cache.remove
# #───────────────────────────

# # Recursive helper for cache remove
# _cacheRemove = (any, options) ->
#   recurse = arguments.callee
#   if any instanceof Backbone.Model
#     # Check cache and get / store
#     if not any.id
#       throw "Error: SMITE.cache.add cannot add a model without an id. (cid: #{any.cid})"
#     update = options.update
#     if not _cache[any.id]
#       _cache[any.id] = any
#       update = true
#     if update
#       _cache[any.id].set _.map _cache[any.id].attributes, ((v) ->
#         recurse v, options
#       ), silent: true
#       if any.hasChanged()
#         options._changed.push any
#     _cache[any.id]

#   if any instanceof Backbone.Model
#     throw "Error: SMITE.cache.add cannot add a model without an id. (cid: #{k.cid})"

#   else if any instanceof Backbone.Collection
#     # Do something
#     throw "Backbone collections NYI"
#   else if _.isObject any or _.isArray any
#     _mapMap any, (v) ->
#       recurse v, options
#   else
#     v

# # Recursively find all models and remove them from the cache
# SMITECLIENT.cache.remove = (any, options) ->
#   opts = _.clone options or {update: true}
#   opts._changed = []
#   _cacheAdd any, opts
#   # Trigger all changed models
#   _.each _.unique opts._changed, (model) ->
#     model.change()

