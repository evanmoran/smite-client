
module.exports =

  #──────────────────────────────────────────────────────
  # itShouldBeAFunction
  #──────────────────────────────────────────────────────

  itShouldBeAFunction: (fn) ->
    it 'should be a function', ->
      fn.should.be.a 'function'
