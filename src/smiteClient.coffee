# smite-client

Backbone = require 'backbone'
_ = require 'underscore'

#───────────────────────────
# Helpers
#───────────────────────────

_pluckMap = (map, key) ->
  out = {}
  for k,v of map
    if _.isObject(v)
      out[k] = v[key]
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

#───────────────────────────
# Export
#───────────────────────────

module.exports = SMITECLIENT = {}

#───────────────────────────
# Validation
#───────────────────────────

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

#───────────────────────────
# ModelView
#───────────────────────────

SMITECLIENT.modelview = (name, Model, data) ->

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
      else
        baseModel = new Model(argsModel...)

      # Create pass through arguments to modelview
      argsModelView = {}
      for attr in _.union(data.attributes, ['id', 'cid'])
        if baseModel.attributes[attr]?
          argsModelView[attr] = baseModel.attributes[attr]

      _.extend argsModelView, data.fromModel?.call(baseModel, baseModel.attributes)

      # Construct backbone modelview with attributes specified by user and us
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
  SMITECLIENT.model name, viewData

#───────────────────────────
# Model
#───────────────────────────


SMITECLIENT.model = (name, data) ->
  extender =
    # Defaults pass through
    validations: _pluckMap data, 'validate'
    defaults: _pluckMap data, 'default'
    attributeTypes: _pluckMap data, 'type'

    # Validate by attribute
    validate: (attributes) ->
      for attr, value of attributes
        if _.isFunction @validations[attr]
          validateResponse = @validations[attr](value, attr)
          if validateResponse
            return validateResponse

    initialize: ->
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
        if (v instanceof Backbone.Model and not v.collection) or v instanceof Backbone.Collection
          _.extend v, parent: @, parentAttribute: attr

      # Monitor events on ourself and forward them to our parent
      @on 'all', (type, model, arg2, arg3) =>
        parent = @parent || (@collection && @collection.parent)
        parentAttribute = @parentAttribute || (@collection && @collection.parentAttribute)
        me = @ || @collection
        changes = {}
        changes[parentAttribute] = true
        output = {changes: changes}
        if type in ['change', 'add', 'remove'] and parent
          # Trigger events to parent from child model changes
          parent.trigger 'change', parent, output
          parent.trigger "change:#{parentAttribute}", parent, me, output

  # Extend methods into backbone model
  for k,v of data when _.isFunction v
    extender[k] = v

  # Return backbone model
  output = Backbone.Model.extend extender

  output.data = data
  output

