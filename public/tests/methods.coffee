# Using mocha

assert = require "assert"
should = require "should"
_ = require "underscore"
Methods = require "../models/emethods.coffee"
Scenarios = require "../models/scenarios.coffee"

describe "prefs", ->
  it "should be correct for chicke", ->
    Scenarios.chicken.prefs().should.equal [[0,1,2],[1,2,0],[2,1,0]]
    
describe "SODA", ->
  prefs = Scenarios.chicken.prefs()
  it "should find a winnerOf", ->
    (Methods.SODA.winnerOf [3.1,5.2,2]).should.equal 1
    (Methods.SODA.winnerOf [-3.1,-5.2,-2]).should.equal 2

  it "should find an undelegated recursiveWinner", ->
    (Methods.SODA.recursiveWinner [3.1,5.2,2], [0,0,0], []).should.equal 1
    (Methods.SODA.winnerOf [-3.1,-5.2,-2], [0,0,0], []).should.equal 2
    
  it "should find a 1-delegated recursiveWinner", ->
    (Methods.SODA.recursiveWinner [3.1,1.2,2], [0,0,1], prefs).should.equal 1
    (Methods.SODA.winnerOf [-3.1,-5.2,-2], [5,0,0], prefs).should.equal 1