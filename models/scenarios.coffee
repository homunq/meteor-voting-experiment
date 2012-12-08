
class Scenario
  #factSizes: [2, 1]
  #payoffs: [[3, 0],
  #         [2,2],
  #         [0,3]]
  
  constructor: (props) ->
    _.extend this, props
    
    #same candidate numbers
    @payoffs.length.should.equal(@candNames.length)
    @candColors.length.should.equal(@candNames.length)
    
    #same faction numbers
    for payoff in @payoffs
      payoff.length.should.equal(@factSizes.length)
    @factNames.length.should.equal(@factSizes.length)
    @factColors.length.should.equal(@factSizes.length)
    @factPngs.length.should.equal(@factSizes.length)
    if @numVoters() > 2
      @hurryNumber = 2
    else
      @hurryNumber = @numVoters() - 1
    
  numVoters: ->
    numVoters = _.reduce @factSizes, (sum, addend) -> 
      sum + addend
    , 0
    @numVoters = ->
      numVoters
    numVoters
    
  numCands: ->
    @payoffs.length
    
  vFactions: (skim) ->
    _.flatten(num for val in _.range(factSize - skim) for factSize, num in @factSizes)
    
    
  shuffledFactions: ->
    _(_.range(@factSizes.length)).shuffle().concat(_(@vFactions(1)).shuffle())
    
  payoffsExceptFaction: (myFaction) ->
    order = _.range @factSizes.length
    if myFaction?
      order.splice myFaction, 1
    @payoffsForFaction faction for faction in order
    
      
  payoffsForFaction: (faction) ->
    factName: @factNames[faction]
    factColor: @factColors[faction]
    factSize: @factSizes[faction]
    payoffs: (payoff[faction] for payoff in @payoffs)
    
  candInfos: (faction, count) ->
    for candName, candNum in @candNames
      @candInfo candNum, faction, count
      
  candInfo: (candNum, faction, count) ->
    num: candNum
    name: @candNames[candNum]
    color: @candColors[candNum]
    myPayoff: @candNames[candNum] and @payoffs[candNum][faction]
    count: count
    
    
@Scenarios =
  chicken: new Scenario
    factSizes: [4, 2, 3]
    factNames: ['X', 'Y', 'Z']
    factColors: ["#D40000", "#00D400", "#0000D4"]
    factPngs: ["4voters", "2voters", "3voters"]
    candNames: ['X', 'Y', 'Z']
    candColors: ["#D40000", "#47D48E", "#008ED4"]
    payoffs: [[3, 0, 0],
              [1, 3, 2],
              [0, 2, 3]]
  doubleChicken: new Scenario
    factSizes: [8, 4, 6]
    factNames: ['X', 'Y', 'Z']
    factColors: ["#D40000", "#00D400", "#0000D4"]
    factPngs: ["4voters", "2voters", "3voters"]
    candNames: ['X', 'Y', 'Z']
    candColors: ["#D40000", "#47D48E", "#008ED4"]
    payoffs: [[3, 0, 0],
              [1, 3, 2],
              [0, 2, 3]]
  simple: new Scenario
    factSizes: [2, 1]
    factNames: ['X', 'Y']
    factColors: ["#D40000", "#00D400"]
    factPngs: ["4voters", "2voters"]
    candNames: ['X', 'Y', 'Z']
    candColors: ["#D40000", "#47D48E", "#008ED4"]
    payoffs: [[3, 0],
              [2, 2],
              [0, 3]]
  mini: new Scenario
    factSizes: [1, 1]
    factNames: ['', 'Y']
    factColors: ["#D40000", "#00D400"]
    factPngs: ["4voters", "2voters"]
    candNames: ['X', 'Y', 'Z']
    candColors: ["#D40000", "#47D48E", "#008ED4"]
    payoffs: [[3, 0],
              [2, 2],
              [0, 3]]
  one: new Scenario
    factSizes: [1]
    factNames: ['Xfact']
    factColors: ["#D40000"]
    factPngs: ["4voters"]
    candNames: ['Xc', 'Yc', 'Zc']
    candColors: ["#D40000", "#47D48E", "#008ED4"]
    payoffs: [[3],
              [2],
              [0]]
  
    