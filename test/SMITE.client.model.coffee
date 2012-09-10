
SMITE = require '../src/SMITE.client'

#──────────────────────────────────────────────────────
# Before
#──────────────────────────────────────────────────────

EmptyModel = SMITE.model 'EmptyModel'

dateNow = new Date
BasicModel = SMITE.model 'BasicModel',
  bool: type: Boolean, default: false
  int: type: Number, default: 1, validate: SMITE.range(0, 100)
  real: type: Number, default: 1.1, validate: (v) -> if v < 0 or 100 < v then "real: {v} is not in range [0,100]" else null
  str: type: String, default: "BasicModel default", required: true, trim: true, validate: SMITE.lengthRange(0, 20)
  date: type: Date, default: dateNow

MethodsModel = SMITE.model 'MethodsModel'
  int: type: Number, default: 1, required: true
  str: type: String, default: 'MethodsModel default', required: true
  # Methods should be passed through
  method: ->
    @str + @int

str8 = 'eight###'
str9 = 'nine#####'
str10 = 'ten#######'
str11 = 'eleven#####'
str12 = 'twelve######'
ValidationModel = SMITE.model 'ValidationModel'
  intMin10:             type: Number, default: 10,      validate: SMITE.min(10)
  intMax10:             type: Number, default: 10,      validate: SMITE.max(10)
  intMoreThan10:        type: Number, default: 11,      validate: SMITE.moreThan(10)
  intLessThan10:        type: Number, default: 9,       validate: SMITE.lessThan(10)
  strLengthMax10:       type: String, default: str10,   validate: SMITE.lengthMax(10)
  strLengthMin10:       type: String, default: str10,   validate: SMITE.lengthMin(10)
  strLengthMoreThan10:  type: String, default: str11,   validate: SMITE.lengthMoreThan(10)
  strLengthLessThan10:  type: String, default: str9,    validate: SMITE.lengthLessThan(10)
  intInEnum:            type: Number, default: 1,       validate: SMITE.inEnum [1,2,3]
  strInList:            type: String, default: 'red',   validate: SMITE.inList ['red', 'green', 'blue']
  intCustomIsInteger:   type: Number, default: 10,      validate: (v) -> if Math.floor(v) != v then "intOnlyInt: {v} is not an integer"

RequiredModel = SMITE.model 'RequiredModel'
  intDefaulted: type: Number, default: 1
  intRequired:  type: Number,             required: true
  intBoth:      type: Number, default: 1, required: true

NestedModel = SMITE.model 'NestedModel'
  model: type: 'NestedModel',  default: null
  model2: type: 'NestedModel',  default: null
  str: type: String, default: "NestedModel default"

RecursiveModel = SMITE.model 'RecursiveModel'
  model: type: 'RecursiveModel',  default: null
  str: type: String, default: "RecursiveModel default"


#──────────────────────────────────────────────────────
# Test: SMITE.model
#──────────────────────────────────────────────────────

describe 'SMITE.client.model', ->

  shared.itShouldBeAFunction(SMITE.model)

  #──────────────────────────────────────────────────────

  it 'should support property-like access', ->
    bm = new BasicModel id: 'id1', bool: true, int: 2, real: 2.2, str: 'BasicModel argument', date: dateNow, attributes: true

    bm.id.should.equal bm.get('id')
    bm.bool.should.equal bm.get('bool')
    bm.int.should.equal bm.get('int')
    bm.real.should.equal bm.get('real')
    bm.str.should.equal bm.get('str')
    bm.date.should.equal bm.get('date')

    bm.attributes.should.be.a 'object'
    bm.get('attributes').should.equal true

  #──────────────────────────────────────────────────────

  shared.model.itShouldConstructABackboneModel(new BasicModel)

  #──────────────────────────────────────────────────────

  it 'should construct using `default` options', ->
    bm = new BasicModel
    bm.bool.should.equal false
    bm.int.should.equal 1
    bm.real.should.equal 1.1
    bm.str.should.equal 'BasicModel default'
    bm.date.should.equal dateNow

    nm = new NestedModel
    (nm.model == null).should.equal true

  #──────────────────────────────────────────────────────

  it 'should construct using `validate` options', ->
    vm = new ValidationModel

    # TODO: verity on('error') events are sent when validation fails
    # vm.on 'error', ->
    #   console.log 'error: ', arguments

    # Helper to test assignment of vm properties
    testAssign = (attr, value, result) ->
      vm[attr] = value
      vm[attr].should.equal result

    testAssign 'intMin10', 9, 10, 'error'
    testAssign 'intMin10', 11, 11
    testAssign 'strLengthMin10', str9, str10, 'error'
    testAssign 'strLengthMin10', str11, str11

    testAssign 'intMax10', 11, 10, 'error'
    testAssign 'intMax10', 9, 9
    testAssign 'strLengthMax10', str11, str10, 'error'
    testAssign 'strLengthMax10', str9, str9

    testAssign 'intMoreThan10', 10, 11, 'error'
    testAssign 'intMoreThan10', 12, 12
    testAssign 'strLengthMoreThan10', str10, str11, 'error'
    testAssign 'strLengthMoreThan10', str12, str12

    testAssign 'intLessThan10', 10, 9, 'error'
    testAssign 'intLessThan10', 8, 8
    testAssign 'strLengthLessThan10', str10, str9, 'error'
    testAssign 'strLengthLessThan10', str8, str8

    testAssign 'strInList', 'notfound', 'red', 'error'
    testAssign 'strInList', 'blue', 'blue'

    testAssign 'intInEnum', 0, 1, 'error'
    testAssign 'intInEnum', 2, 2

    testAssign 'intCustomIsInteger', 10.9, 10, 'error'
    testAssign 'intCustomIsInteger', 11, 11

  #──────────────────────────────────────────────────────

  it 'Partial testing doesnt exist!'

  #──────────────────────────────────────────────────────

  it 'should construct using `require` options (NYI)'
    # TODO: implement test for RequiredModel

  #──────────────────────────────────────────────────────

  it 'should receive `change` events on attributes', (done) ->
    done2 = _.after 2, done
    bm = new BasicModel bool: false
    bm.on 'change:bool', (model, newValue, info) ->
      info.changes.should.have.property 'bool'
      newValue.should.equal true
      done2()
    bm.on 'change', (model, info) ->
      info.changes.should.have.property 'bool'
      done2()
    bm.bool = true

  #──────────────────────────────────────────────────────

  it 'should receive `change` events on model attributes (contruction)', (done) ->
    done4 = _.after 4, done
    nmChild = new NestedModel model: null, str: 'child default'
    nmParent = new NestedModel model: nmChild, str: 'parent default'
    nmParent.on 'change', (model, info) ->
      model.should.equal nmParent
      info.changes.should.have.property 'model'
      done4()

    nmParent.on 'change:model', (model, newValue, info) ->
      newValue.should.equal nmChild
      info.changes.should.have.property 'model'
      done4()

    nmChild.on 'change', (model, info) ->
      info.changes.should.have.property 'str'
      done4()

    nmChild.on 'change:str', (model, newValue, info) ->
      newValue.should.equal 'child override'
      info.changes.should.have.property 'str'
      done4()
    nmParent.model.str = 'child override'

  #──────────────────────────────────────────────────────

  it 'should receive `change` events on model attributes (after construction)', (done) ->
    done2 = _.after 2, done
    nmChild = new NestedModel model: null, str: 'child default'
    nmParent = new NestedModel model: null, str: 'parent default'
    nmParent.model = nmChild

    nmParent.on 'change', (model, info) ->
      model.should.equal nmParent
      info.changes.should.have.property 'model'
      done2()

    nmParent.on 'change:model', (model, newValue, info) ->
      newValue.should.equal nmChild
      info.changes.should.have.property 'model'
      done2()

    nmChild.str = 'child override'

  #──────────────────────────────────────────────────────

  it 'should receive `change` events on previously assigned model attributes', (done) ->
    done2 = _.after 2, done
    nmChild = new NestedModel model: null, str: 'child default'
    nmParent = new NestedModel model: nmChild, str: 'parent default'
    nmChild2 = new NestedModel model: null, str: 'child2 default'
    nmParent.model = nmChild2

    nmParent.on 'change', (model, info) ->
      model.should.equal nmParent
      info.changes.should.have.property 'model'
      done2()
    nmParent.on 'change:model', (model, newValue, info) ->
      newValue.should.equal nmChild2
      info.changes.should.have.property 'model'
      done2()
    nmChild2.str = 'child override'

  #──────────────────────────────────────────────────────

  shared.model.itShouldHaveModelHelpers(BasicModel, null, null, 'BasicModel')

  #──────────────────────────────────────────────────────
  #──────────────────────────────────────────────────────
  #──────────────────────────────────────────────────────
  #──────────────────────────────────────────────────────
  #──────────────────────────────────────────────────────
