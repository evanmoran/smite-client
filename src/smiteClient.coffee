# smite-client

Backbone = require 'backbone'

#───────────────────────────
# Helpers
#───────────────────────────

_isUndefined = (obj) -> obj == undefined
_isFunction = (obj) -> toString.call(obj) == '[object Function]'
_isObject = (obj) -> obj == Object(obj)
_has = (obj, key) -> Object.prototype.hasOwnProperty.call obj, key
_each = (obj, iterator, context)  ->
  return unless obj?
    if Array.prototype.forEach and obj.forEach == Array.prototype.forEach
      obj.forEach iterator, context
    else if obj.length == +obj.length
      for i in [0...obj.length-1]
        return if (i in obj && iterator.call(context, obj[i], i, obj) == breaker)
    else
      for key of obj
        if _has(obj, key)
          return if (iterator.call(context, obj[key], key, obj) == breaker)

_extend = (obj) ->
  _each Array.prototype.slice.call(arguments, 1), (source) ->
    for prop of source
      obj[prop] = source[prop];
  obj

_pluckMap = (map, key) ->
  out = {}
  for k,v of map
    if _isObject(v)
      out[k] = v[key]
  out

#───────────────────────────
# Export
#───────────────────────────

module.exports = SMITECLIENT = {}

#───────────────────────────
# Validation
#───────────────────────────

_extend SMITECLIENT,
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
# Model
#───────────────────────────

SMITECLIENT.model = (name, data) ->
  validations = _pluckMap data, 'validate'
  extender =
    # Defaults pass through
    defaults: _pluckMap data, 'default'
    attributeTypes: _pluckMap data, 'type'

    # Validate by attribute
    validate: (attributes) ->
      for attr, value of attributes
        if _isFunction validations[attr]
          validateResponse = validations[attr](value, attr)
          if validateResponse
            return validateResponse

    initialize: ->
      for k,v of @attributes
        do (k) =>
          if _isUndefined @[k]
            Object.defineProperty @, k,
              get: -> @get k
              set: (value) -> @set k, value
              enumerable: true
              configurable: false

      # Remember parent of attributes that contain models or collections
      for attr,v of @attributes
        if (v instanceof Backbone.Model and not v.collection) or v instanceof Backbone.Collection
          _extend v, parent: @, parentAttribute: attr

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
  for k,v of data when _isFunction v
    extender[k] = v

  # Return backbone model
  Backbone.Model.extend extender
