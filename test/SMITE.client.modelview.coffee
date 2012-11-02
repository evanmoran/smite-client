
SMITE = require '../src/SMITE.client'

# Before
# ----------------------------------------------------------------

# Define Model as grab bag of all of common attribute types
dateNow = new Date
Model = SMITE.model 'Model',
  bool: type: Boolean, default: false
  int: type: Number, default: 1, validate: SMITE.range(0, 100)
  real: type: Number, default: 1.1, validate: (v) -> if v < 0 or 100 < v then "real: {v} is not in range [0,100]" else null
  str: type: String, default: "Model.str default", required: true, trim: true, validate: SMITE.lengthRange(0, 20)
  date: type: Date, default: dateNow
  model: type: 'Model',  default: null

# NumberView - Only show number types (bool, int, real). Different validation ranges. Different defaults.
ModelNumberView = SMITE.modelview 'Model.NumberView',
  bool: type: Boolean, default: true
  int: type: Number, default: 2, validate: SMITE.range(0, 10)
  real: type: Number, default: 2.2, validate: SMITE.range(0, 10)

# NumberView - Only show number types (bool, int, real). Different validation ranges. Different defaults.
ModelRecursiveNumberView = SMITE.modelview 'Model.RecursiveNumberView',
  bool: type: Boolean, default: true
  int: type: Number, default: 2, validate: SMITE.range(0, 10)
  real: type: Number, default: 2.2, validate: SMITE.range(0, 10)
  model: type: 'Model.RecursiveNumberView', default: null

# ChildView - Only show model and str. Used to limit visability of attributes.
ModelChildView = SMITE.modelview 'Model.ChildView',
  model: type: 'Model',  default: null
  str: type: String, default: "Model.ChildView.str default", validate: SMITE.lengthRange(0, 20)

# ChangedView - Pass through everything a bit changed. Used to adjust values, and return them to previous state
ModelChangedView = SMITE.modelview 'Model.ChangedView',
  boolNot: type: Boolean, default: true
  intPlus2: type: Number, default: 4, validate: SMITE.range(2, 102)
  real: type: Number, default: 4.4, validate: SMITE.range(0, 100)
  strQuoted: type: String, default: "Model.ChangedView.str default", required: true, trim: true, validate: (v) -> if v.length < 2 or v[0] != '"' or v[v.length-1] != '"'  then "strQuoted: {v} is not quoted"

  fromModel: (m) ->
    @boolNot = not m.bool
    @intPlus2 = m.int + 2
    # @real automatic pass through
    @strQuoted = '"' + m.str + '"'

  toModel: (m) ->
    m.int = @intPlus2 - 2
    # m.real automatic pass through
    m.bool = not @boolNot
    m.str = @strQuoted.slice 1, @strQuoted.length-1

# Test: Smite.modelview
# ----------------------------------------------------------------

describe 'SMITE.client.modelview', ->

  shared.itShouldBeAFunction(SMITE.modelview)
  shared.model.itShouldConstructABackboneModel(new Model.NumberView, SMITE.Backbone)

  # ----------------------------------------------------------------

  it 'should throw if constructed with an invalid arguments'
  #   console.log ''
  #   ( -> SMITE.modelview(1)).should.throw 'SMITE.modelview expected the first argument to contain a period (example: `Model.View`)'
  #   ( -> SMITE.modelview('FirstArgumentIsInvalid')).should.throw 'SMITE.modelview expected the first argument to contain a period (example: `Model.View`)'
  #   ( -> SMITE.modelview('Model.View', 1)).should.throw 'SMITE.modelview expected the first argument to contain a period (example: `Model.View`)'

  # ----------------------------------------------------------------
  it 'should support property-like access', ->
    nm = new Model.NumberView id: 'id1', bool: true, int: 2, str: 'BasicModel override', attributes: true

    nm.id.should.equal nm.get('id')
    nm.bool.should.equal nm.get('bool')
    nm.int.should.equal nm.get('int')
    nm.attributes.should.be.a 'object'
    nm.get('attributes').should.equal true

  # ----------------------------------------------------------------

  it 'should construct using `default` options', ->
    nm = new Model.NumberView
    nm.bool.should.equal true
    nm.int.should.equal 2
    nm.real.should.equal 2.2

    nm = new Model.ChildView
    (nm.model == null).should.equal true
    nm.str.should.equal 'Model.ChildView.str default'

  # ----------------------------------------------------------------

  it 'should construct using `validate` options', ->
    # Helper to test assignment of vm properties
    testAssign = (mv, attr, value, result) ->
      mv[attr] = value
      mv[attr].should.equal result

    nv = new Model.NumberView
    nv.int.should.equal 2
    testAssign nv, 'int', 0, 0
    testAssign nv, 'int', -1, 0, 'error'
    nv.real.should.equal 2.2
    testAssign nv, 'real', 0, 0
    testAssign nv, 'real', -1.1, 0, 'error'

  # ----------------------------------------------------------------

  it 'new model', ->
    m = new Model id: 'id1', bool: false, int: 1, real: 1.1, str: 'one'
    cv = new Model.ChangedView m

    cv.id.should.equal m.id
    cv.cid.should.not.equal m.cid
    cv.boolNot.should.equal true
    cv.intPlus2.should.equal 3
    cv.real.should.equal 1.1              # automatic pass through
    cv.strQuoted.should.equal '"one"'

  it 'toModel()', ->
    m = new Model id: 'id1', bool: false, int: 1, real: 1.1, str: 'one'
    (m.toModel == undefined).should.equal true
    cv = new Model.ChangedView m
    cv.id.should.equal m.id
    cv.cid.should.not.equal m.cid
    cv.boolNot.should.equal true
    cv.intPlus2.should.equal 3
    cv.real.should.equal 1.1              # automatic pass through
    cv.strQuoted.should.equal '"one"'

    cv.toModel.should.be.a 'function'
    m2 = cv.toModel()
    m2.should.be.an.instanceof SMITE.Backbone.Model
    expect(m2.toModel).to.not.exist

    m2.id.should.equal m.id
    m2.int.should.equal m.int
    m2.real.should.equal m.real
    m2.str.should.equal m.str
    m2.date.should.equal dateNow
    assert.isNull m2.model

  # ----------------------------------------------------------------

  shared.model.itShouldHaveModelHelpers
    View: Model.RecursiveNumberView,
    Model: Model
    modelParentName: 'Model'
    modelBaseName: 'RecursiveNumberView'
    modelRelations: {model: null}

  # ----------------------------------------------------------------
  # ----------------------------------------------------------------
  # ----------------------------------------------------------------
  # ----------------------------------------------------------------
