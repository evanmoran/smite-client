
module.exports =

  #──────────────────────────────────────────────────────
  # itShouldConstructABackboneModel
  #──────────────────────────────────────────────────────

  itShouldConstructABackboneModel: (model, Backbone) ->
    it 'should construct a backbone model', ->
      (model instanceof Backbone.Model).should.equal true

  # Model.NumberView, Model, 'Model', 'NumberView'
  itShouldHaveModelHelpers: (args) ->

    modelName = if args.modelParentName then "#{args.modelParentName}.#{args.modelBaseName}" else args.modelBaseName

    it 'should have private _model', ->
      v = new args.View
      v._model.should.be.a 'function'
      v._model().should.equal args.View

    it 'should have private _modelParent', ->
      v = new args.View
      v._modelParent.should.be.a 'function'
      assert v._modelParent() == args.Model

    it 'should have private _modelName', ->
      v = new args.View
      assert v._modelName == modelName

    it 'should have private _modelBaseName', ->
      v = new args.View
      assert v._modelBaseName == args.modelBaseName

    it 'should have private _modelParentName', ->
      v = new args.View
      assert v._modelParentName == args.modelParentName

    it 'should have private _modelRelations', ->
      v = new args.View
      expect(v._modelRelations()).to.deep.equal args.modelRelations

