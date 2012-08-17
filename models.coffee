
echo = (args...) ->
  console.log args...

Elections = new Meteor.Collection 'elections'
#  scenario: 'chicken'
#  system: 'approval'
#  voters: [12, 14, ...]
#  factions: [2, 0, ...]
#  nonfactions: [] #[0, 0, 1, 1, ... 2, ...]
#  numvotes: [9, 3] #9 voters connected, 3 votes r1, 0 r2.
#  full: true
#  round:1
#  stimes:[1234345, 1234367]
#  rtime:[20, 40] #time since start, floor 5
#  winners: [1, 3]

Votes = new Meteor.Collection 'votes'
#  voter: 12
#  faction: 3
#  election: 1
#  round: 1
#  vote: [3,1,1] #higher is better
#  done: false #denormalzed copy: all votes in for this round

class MyObj
  constructor: (props) ->
    _.extend this, props
    
  @register: (methods) ->
    servermethods = {}
    for mname, method of methods
      if _.isArray method #async with predefined callback
        [method, callback] = method
      else
        callback = undefined
      smname = @constructor.name + "_" + mname
      servermethods[smname] = (id, args) =>
        instance = @collection.findOne
          _id: id
        if !instance
          throw Meteor.error 404, "No such object on server"
        instance = new @ instance
        instance[mname] args...
      @[mname] = (args...) ->
        Meteor.apply smname args callback
    Meteor.methods servermethods
    
  @registerStatic: (methods) ->
    servermethods = {}
    for cmname, cmethod of methods
      if _.isArray cmethod #async with predefined callback
        [cmethod, callback] = cmethod
      else
        callback = undefined
      scmname = @constructor.name + "__" + mname
      servermethods[scmname] = (args) =>
        if !instance
          throw Meteor.error 404, "No such object on server"
        @[cmname] args...
      @[cmname] = (args...) ->
        Meteor.apply scmname args callback
    Meteor.methods servermethods
    
class Election extends MyObj
  scen: =>
    Scenarios[@scenario]
    
  sys: =>
    Systems[@system]
    
  newVote: (vote) =>
    if @round != vote.round
      throw Meteor.error 403, "Wrong round"
    if Meteor.user() != vote.voter
      throw Meteor.error 403, "That's not you"
    oldVote = Votes.findOne
      voter: vote.voter
      round: @round
    if oldVote
      throw Meteor.error 403, "You've already voted"
    faction = @factionOf uid #throws error on failure
    
    @numvotes[@round] += 1
    done = (@numvotes[@round] >= @scen.numvoters())
     
    _.extend vote
      election: @_id
      faction: faction
      done: done
      
    Votes.insert vote
    
    if done then @finishRound()
    
    Elections.update @_id, @
  @
    
      
      
  factionOf: (voter, throwerr=true) =>
    i = _.indexOf @voters, voter
    if i == -1
      if throwerr
        throw Meteor.error 403, "Not a voter in this election"
      return i
    return @factions[i]  
    
  finishRound: =>
    echo "fR not impl"
    
  
class Scenario extends MyObj
  #factSizes: [2, 1]
  #payoffs: [[3, 0],
  #         [2,2],
  #         [0,3]]
  numvoters: =>
    numvoters = _.reduce @factSizes, (sum, addend) -> 
      sum + addend
    , 0
    @numvoters = ->
      numvoters
    numvoters
    
  vfactions: =>
    _.flatten((num for val in _.range factSize) for num, factSize of @factSizes)
    
    
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
  
    

if Meteor.is_server
  # publish all the non-full elections.
  Meteor.publish 'elections', ->
    Elections.find {},
      fields:
        #voters: 0
        factions: 0
        nonfactions: 0
        
  Meteor.publish 'done_votes', (eid) ->
    Votes.find
      eid: eid
      done: true
    ,
      voter: 0
      #faction: 0 #do not hide this, even though it wouldn't be visible IRL
      
    
else if Meteor.is_client
  Meteor.subscribe 'elections'
  Meteor.autosubscribe ->
    Meteor.subscribe 'done_votes', Meteor.user().eid, ->
      console.log "done_votes (re)loaded"

  Meteor.autosubscribe ->
    Session.set 'election', Elections.findOne
      _id: Meteor.user().eid
    console.log "election (re)loaded"
