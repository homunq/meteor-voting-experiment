#tests/posts.js
assert = require "assert"
should = require "should" 

suite "methods", ->
  trunc = (obj) ->
    return obj.toString().substr(0, 5)  if not obj? or typeof (obj) isnt "object"
    temp = obj.constructor() # changed
    for key of obj
      temp[key] = trunc(obj[key])
    temp
  systemResults = 
    plurality: [ [ 0 ], [ 4, 2, 3 ] ]
    approval: [ [ 1, 2 ], [ 4, 5, 5 ] ]
    GMJ: [ [ 2 ], [ 2/5, 8/3, 11/4 ] ]
    IRV: [ [ 2 ], [ [1,1,1,1], 1, [1,1,1,1,1] ] ]
    MAV: [ [ 2 ], [ 1/7, 47/17, 23/8 ] ]
    condorcet: [ [ 1 ], [ "beats 0 others; worst margin -1", "beats 2 others; worst margin 1", "beats 1 others; worst margin -3" ] ]
    borda: [ [ 1 ], [ 8, 11, 8 ] ]
    score: [ [ 1 ], [ 40, 52, 46 ] ]
    SODA: [ [ 1 ], [ "4 + 0", "2 + 7", "3 + 2" ] ]
  for systemm, resultt of systemResults
    do (system=systemm, result=resultt) ->
      
      test system, (done, server) ->
        server.eval (system) ->
            emit "result"+system, (Methods[system].resolveHonestVotes Scenarios.chicken)
          , system #eval needs it as an arg
        server.once "result"+system, (r) ->
          trunc(r).should.eql trunc(result), "system failed:"+system
          done()
    
suite "integrations", ->
  test "two clients", (done, server, c1, c2) ->
    assert.equal 1, 2
    done()


