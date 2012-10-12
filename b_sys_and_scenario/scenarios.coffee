
class Scenario
  #factSizes: [2, 1]
  #payoffs: [[3, 0],
  #         [2,2],
  #         [0,3]]
  
  constructor: (props) ->
    _.extend this, props
    
  numVoters: =>
    numvoters = _.reduce @factSizes, (sum, addend) -> 
      sum + addend
    , 0
    @numVoters = ->
      numVoters
    numVoters
    
  vFactions: (skim) =>
    _.flatten(num for val in _.range(factSize - skim) for factSize, num in @factSizes)
    
    
  shuffledFactions: =>
    _(_.range(@factSizes.length)).shuffle().concat(_(@vFactions(1)).shuffle())
    
@Scenarios =
  chicken: new Scenario
    factSizes: [3, 2, 4]
    payoffs: [[0, 0, 3],
              [2, 3, 1],
              [3, 2, 0]]
  doubleChicken: new Scenario
    factSizes: [6, 4, 8]
    payoffs: [[0, 0, 3],
              [2, 3, 1],
              [3, 2, 0]]
  simple: new Scenario
    factSizes: [2, 1]
    payoffs: [[3, 0],
              [2, 2],
              [0, 3]]
  mini: new Scenario
    factSizes: [1, 1]
    payoffs: [[3, 0],
              [2, 2],
              [0, 3]]
  
    