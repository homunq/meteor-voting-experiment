#tests/posts.js
assert = require "assert"
should = require "should" 

suite "methods", ->
  systemResults = 
    plurality: [ [ 0 ], [ 4, 2, 3 ] ]
    approval: [ [ 1, 2 ], [ 4, 5, 5 ] ]
    GMJ: [ [ 2 ], [ 2/5, 8/3, 11/4 ] ]
    IRV: [ [ 2 ], [ [1,1,1,1], 1, [1,1,1,1,1] ] ]
    MAV: [ [ 2 ], [ 1/7, 47/17, 23/8 ] ]
    condorcet: [ [ 1 ], [ 4, 9, 4 ] ]
    borda: [ [ 1 ], [ 4, 9, 4 ] ]
    score: [ [ 1 ], [ 4, 9, 4 ] ]
    SODA: [ [ 1 ], [ 4, 9, 4 ] ]
  for systemm, resultt of systemResults
    do (system=systemm, result=resultt) ->
      
      test system, (done, server) ->
        server.eval (system) ->
            emit "result"+system, (Methods[system].resolveHonestVotes Scenarios.chicken)
          , system #eval needs it as an arg
        server.once "result"+system, (r) ->
          r.should.eql result, "system failed:"+system
          done()
    
suite "integrations", ->
  test "two clients", (done, server, c1, c2) ->
    assert.equal 1, 2
    done()


