
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
    
  factions: (faction)->
    factions = _.range @factSizes.length
    if faction
      factions.splice faction, 1
      factions.splice 0,0,faction
    factions
    
  factionsAttrs: (myFaction) ->
    for faction in (@factions myFaction)
      mine: (faction is myFaction)
      name: @factNames[faction]
      size: @factSizes[faction]
      color: @factColors[faction]
    
  vFactions: (skim) ->
    _.flatten(num for val in _.range(factSize - skim) for factSize, num in @factSizes)
    
    
  shuffledFactions: ->
    milk = _(@vFactions(1)).shuffle()
    cream = _.shuffle _.range @factSizes.length
    milk.concat(cream)
    
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
    
  payoffCents: (winner, faction) ->
    @payoffs[winner][faction] * $bonusUnit
    
  candInfos: (faction, count) ->
    for candName, candNum in @candNames
      @candInfo candNum, faction, 
        count: count
      
  candInfo: (candNum, faction, outcome, scen) ->
    num: candNum
    name: @candNames[candNum]
    color: @candColors[candNum]
    myPayoff: @candNames[candNum] and @payoffs[candNum][faction]
    count: outcome.counts?[candNum]
    candTied: candNum in (outcome.ties or []) 
    factionCounts: for faction in (scen?.factions(faction) or [])
      count: outcome.factionCounts?[faction][candNum] or 0
      faction: faction
      color: scen?.factColors[faction]
      name: scen?.factNames[faction]
      
  prefs: ->
    #as currently written, this ONLY WORKS by assuming that the lists of factions and candidates correspond. 
    payoffsByFaction = _.zip @payoffs
    prefs = for factionPayoffs in payoffsByFaction
      sortablePayoffs = _.zip factionPayoffs, [0..factionPayoffs.length - 1]
      sortablePayoffs.sort (a, b) ->
        a[0] - b[0]
      index for [payoff, index] in sortablePayoffs
    prefs
      
  slides: (faction) ->
    for num in [1..5]
      name:@factPngs[faction] + num
      active: if num is 1 then "active " else ""
    
@Scenarios =
  chicken: new Scenario
    factSizes: [4, 2, 3]
    factNames: ['Red', 'Green', 'Blue']
    factColors: ["#D40000", "#00D400", "#0000D4"]
    factPngs: ["4pairs", "2pairs", "3pairs"]
    candNames: ['X', 'Y', 'Z']
    candColors: ["#D40000", "#47D48E", "#008ED4"]
    payoffs: [[3, 0, 0],
              [1, 3, 2],
              [0, 2, 3]]
  doubleChicken: new Scenario
    factSizes: [8, 4, 6]
    factNames: ['Red', 'Green', 'Blue']
    factColors: ["#D40000", "#00D400", "#0000D4"]
    factPngs: ["4pairs", "2pairs", "3pairs"]
    candNames: ['X', 'Y', 'Z']
    candColors: ["#D40000", "#47D48E", "#008ED4"]
    payoffs: [[3, 0, 0],
              [1, 3, 2],
              [0, 2, 3]]
  simple: new Scenario
    factSizes: [2, 1]
    factNames: ['Red', 'Blue']
    factColors: ["#D40000", "#00D400"]
    factPngs: ["4pairs", "3pairs"]
    candNames: ['X', 'Y', 'Z']
    candColors: ["#D40000", "#47D48E", "#008ED4"]
    payoffs: [[3, 0],
              [2, 2],
              [0, 3]]
  mini: new Scenario
    factSizes: [1, 1]
    factNames: ['Red', 'Blue']
    factColors: ["#D40000", "#00D400"]
    factPngs: ["4pairs", "3pairs"]
    candNames: ['X', 'Y', 'Z']
    candColors: ["#D40000", "#47D48E", "#008ED4"]
    payoffs: [[3, 0],
              [2, 2],
              [0, 3]]
  one: new Scenario
    factSizes: [1]
    factNames: ['Red']
    factColors: ["#D40000"]
    factPngs: ["4pairs"]
    candNames: ['X', 'Y', 'Z']
    candColors: ["#D40000", "#47D48E", "#008ED4"]
    payoffs: [[3],
              [2],
              [0]]
  
    
#expose for Node testing        
exports = Scenarios unless Meteor?