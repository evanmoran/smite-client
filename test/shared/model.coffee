
module.exports =

  #──────────────────────────────────────────────────────
  # itShouldConstructABackboneModel
  #──────────────────────────────────────────────────────

  itShouldConstructABackboneModel: (model, Backbone) ->
    it 'should construct a backbone model', ->
      (model instanceof Backbone.Model).should.equal true

  # Model.NumberView, Model, 'Model', 'NumberView'
  itShouldHaveModelHelpers: (View, Model, modelParentName, modelBaseName) ->
    modelName = if modelParentName then "#{modelParentName}.#{modelBaseName}" else modelBaseName

    it 'should have private _model', ->
      v = new View
      v._model.should.be.a 'function'
      v._model().should.equal View

    it 'should have private _modelParent', ->
      v = new View
      v._modelParent.should.be.a 'function'
      assert v._modelParent() == Model

    it 'should have private _modelName', ->
      v = new View
      assert v._modelName == modelName

    it 'should have private _modelBaseName', ->
      v = new View
      assert v._modelBaseName == modelBaseName

    it 'should have private _modelParentName', ->
      v = new View
      assert v._modelParentName == modelParentName


