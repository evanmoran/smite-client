# smite-client

Backbone = require 'backbone'
_ = require 'underscore'

#──────────────────────────────────────────────────────
# Export
#──────────────────────────────────────────────────────

module.exports = SMITECLIENT = {}

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

#──────────────────────────────────────────────────────
# Validation
#──────────────────────────────────────────────────────

_.extend SMITECLIENT,
  inList: (list) -> (v, prop) ->               if list.indexOf(v) == -1 then             "#{prop}: #{v} is not in list: #{list}"
  inEnum: (enumList) -> (v, prop) ->           if enumList.indexOf(v) == -1 then         "#{prop}: #{v} is not in enum: #{enumList}"

  range: (min, max) -> (v, prop) ->            if v < min or max < v then                "#{prop}: #{v} is not in range: [#{min}, #{max}]"
  min: (min) -> (v, prop) ->                   if v < min then                           "#{prop}: #{v} is too small for min: #{min}"
  max: (max) -> (v, prop) ->                   if v > max then                           "#{prop}: #{v} is too large for max: #{max}"
  lessThan: (num) -> (v, prop) ->              if v >= num then                          "#{prop}: #{v} is too large for lessThan: #{num}"
  moreThan: (num) -> (v, prop) ->              if v <= num then                          "#{prop}: #{v} is too small for moreThan: #{num}"

  lengthRange: (min, max) -> (v, prop) ->      if v.length < min or max < v.length then  "#{prop}: #{v}.length is not in range: [#{min}, #{max}]"
  lengthMin: (num) -> (v, prop) ->             if v.length < num then                    "#{prop}: #{v}.length is too small for min: #{min}"
  lengthMax: (num) -> (v, prop) ->             if v.length > num then                    "#{prop}: #{v}.length is too large for max: #{max}"
  lengthLessThan: (num) -> (v, prop) ->        if v.length >= num then                   "#{prop}: #{v}.length is too large for lessThan: #{num}"
  lengthMoreThan: (num) -> (v, prop) ->        if v.length <= num then                   "#{prop}: #{v}.length is too small for moreThan: #{num}"

#──────────────────────────────────────────────────────
# ModelView
#──────────────────────────────────────────────────────

SMITE = {}
SMITE.modelview =

SMITECLIENT.modelview = (Model, name, data) ->

  # Lookup model by name if it is a string
  if _.isString Model
    Model = SMITECLIENT.models[Model]

  # Default to using all attributes from model
  data.attributes ?= Model.attributes

  # Gather info from Model but restrict to only attributes specified
  viewData = _.pick _transposeMap(_.pick(Model, 'validations', 'defaults', 'attributeTypes')), data.attributes...
  _.extend viewData, data

  # Add toModel and fromModel methods
  _.extend viewData,
    constructor: (argsModel) ->
      # If they give you the full model
      if argsModel instanceof Backbone.Model
        baseModel = argsModel
      # Otherwise these are the attributes construct the base
      else if _.isObject argsModel
        baseModel = new Model(argsModel)
      else
        throw "#{name} modelview expects model or argument object"

      # Create pass through arguments to modelview
      argsModelView = {}
      for attr in _.union(data.attributes, ['id', 'cid'])
        if baseModel.attributes[attr]?
          argsModelView[attr] = baseModel.attributes[attr]

      _.extend argsModelView, data.fromModel?.call(baseModel, baseModel.attributes)

      # Construct backbone modelview with attributes specified by user and us
      # call super
      @constructor.__super__.constructor.apply @, [argsModelView]

    toModel: ->
      # Create pass through arguments to model
      argsModel = {}
      for attr in _.union(data.attributes, ['id', 'cid'])
        if @attributes[attr]?
          argsModel[attr] = @attributes[attr]

      # Extend with user model args
      _.extend argsModel, data.toModel?.call(@, @.attributes)

      # Give them the model they so desire
      new Model argsModel

  # Return backbone model correctly setup
  modelViewName = "#{Model._modelName}.#{name}"
  modelViewOut = Model[name] = SMITECLIENT.model modelViewName, viewData

  # Keep a reference to model view for easy lookup
  SMITECLIENT.models[modelViewName] = modelViewOut

  modelViewOut

#──────────────────────────────────────────────────────
# Model
#──────────────────────────────────────────────────────

SMITECLIENT.model = (name, data) ->
  baseName = name.split('.')[0]

  # Adding _partial
    # Constructor ignore defaulting (only does id)
    #

  needsParent = (value) -> (value instanceof Backbone.Model and not value.collection) or value instanceof Backbone.Collection

  # Convert value to a partial of itself (must be bb model)
  makePartial = (v) -> v._partial()

  extender =
    # Defaults pass through
    validations: _pluckMap data, 'validate'
    defaults: _pluckMap data, 'default'
    attributeTypes: _pluckMap data, 'type'

    # Route by name
    urlRoot: "/#{name}"

    # Validate by attribute
    validate: (attributes) ->
      for attr, value of attributes
        if _.isFunction @validations[attr]
          validateResponse = @validations[attr](value, attr)
          if validateResponse
            return validateResponse
      null

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
      @_modelArgs = data
      @_model = -> SMITECLIENT.models[name]
      @_modelBase = -> SMITECLIENT.models[baseName]

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

        # Create a list of references to models that have already triggered this event
        lastArgIndex = arguments.length-1
        cycleGuard = arguments[lastArgIndex]
        if cycleGuard?.guard
          lastArgIndex--
        else
          cycleGuard =  { guard: true, triggered: [@] }

        #
        if parents
          for parent in parents
            # Avoid triggering cycles
            continue if _.indexOf(cycleGuard.triggered, parent.ref) != -1
            cycleGuard.triggered.push parent.ref

            changes = {}
            changes[parent.attribute] = true
            output = {changes: changes}
            if type in ['change', 'add', 'remove', 'error'] and parent.ref
              if type == 'error'
                parent.ref.trigger type, parent.ref, _.toArray(arguments).slice(2, lastArgIndex).push(cycleGuard)...

              # Trigger events to parent from child model changes
              else if type == 'change'
                parent.ref.trigger type, parent.ref, output, cycleGuard
                parent.ref.trigger "change:#{parent.attribute}", parent.ref, me, output, cycleGuard

    # Override set to keep track of parent model references
    set: (attr, value) ->
      # Remove old parent references
      oldValue = @get(attr)
      if needsParent oldValue
        parents =  @get(attr)?.parents
        if parents
          oldValue.parents = _.reject parents, (parentObj) => parentObj.ref == @ && parentObj.attribute == attr

      # Add to new value if it needs them
      if needsParent value
        value.parents ?= []
        value.parents.push {ref: @, attribute: attr}

      # Call super
      @constructor.__super__.set.apply @, [attr, value]

    # Serialize to attribute object but replace models with partials
    toJSON: ->
      out = _mapMap @attributes, (value) ->
        if value instanceof Backbone.Model
          makePartial(value)
        else if value instanceof Backbone.Collection
          _.map value, makePartial
        else
          value
      out

  # Extend methods into backbone model
  for k,v of data when _.isFunction v
    extender[k] = v

  # Return backbone model
  modelOut = Backbone.Model.extend extender

  # Remember initial arguments
  modelOut._modelArgs = data
  modelOut._modelName = name
  modelOut._modelBaseName = baseName
  modelOut._model = -> SMITECLIENT.models[name]
  modelOut._modelBase = -> SMITECLIENT.models[baseName]

  # Keep a reference for easy lookup by name
  SMITECLIENT.models[name] = modelOut

  modelOut

