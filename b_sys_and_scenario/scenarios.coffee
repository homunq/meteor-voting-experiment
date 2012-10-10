
class Scenario
  #factSizes: [2, 1]
  #payoffs: [[3, 0],
  #         [2,2],
  #         [0,3]]
  
  constructor: (props) ->
    _.extend this, props
    
  numvoters: =>
    numvoters = _.reduce @factSizes, (sum, addend) -> 
      sum + addend
    , 0
    @numvoters = ->
      numvoters
    numvoters
    
  vfactions: =>
    _.flatten((parseInt(num) for val in _.range factSize) for num, factSize of @factSizes)
    
    
@Scenarios =
  chicken: new Scenario
    factSizes: [4, 2, 3]
    payoffs: [[3, 0, 0],
              [1, 3, 2],
              [0, 2, 3]]
  simple: new Scenario
    factSizes: [2, 1]
    payoffs: [[3, 0],
              [2, 2],
              [0, 3]]
  
    