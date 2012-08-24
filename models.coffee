[isArray, isString, isDate] = _

echo = (args...) ->
  console.log args...


Votes = new Meteor.Collection 'votes'
#  voter: 12
#  faction: 3
#  election: 1
#  round: 1
#  vote: [3,1,1] #higher is better
#  done: false #denormalzed copy: all votes in for this round

Elections = new Meteor.Collection 'elections', null

class Election extends StamperInstance
  
  @fields
    scenario: 'chicken'
    system: 'approval'
    factions: []
    nonfactions: [] #[0, 0, 1, 1, ... 2, ...]
    numvotes: [0] #9 voters connected, 3 votes r1, 0 r2.
    full: false
    round: 0
    stimes: ->
      [new Date]
    rtime:[20, 40] #time since start, floor 5
    winners: [1, 3]
  scen: (scenarioname) ->
    if @ == Election
      return Scenarios[scenarioname]
    Scenarios[@scenario]
    
  sys: (sysname) ->
    if @ == Election
      return Systems[sysname]
    Systems[@system]
    
  @register
    make: @static (options)->
      console.log "new election"
      options = _(options).pick "scenario", "system"
      
      _(options).extend
        scenario: 'chicken'
        system: 'approval'
        voters: []
        
      e = new Election options
      e.nonfactions = e.scen().vfactions()
      
      e.addVoter @userId()
      
      eid = e.save()
      
      console.log eid
      console.log @userId()
      
      Meteor.users.update
        _id: @userId()
      ,
        $set:
          eid: eid
      ,
        multi: false
      
    join: @static (eid) ->
      uid = @userId()
      election = Elections.findOne
        _id: eid
      if !election
        throw Meteor.Error 404, "no such election"
      if (_.indexOf election.voters, uid) == -1
        Elections.update
          _id: eid
        ,
          $push: 
            voters: uid
        ,
          multi: false
          
        Meteor.users.update
          _id: @userId()
        ,
          $set:
            eid: eid
        ,
          multi: false
        
    newVote: (vote) =>
      if @round != vote.round
        throw Meteor.Error 403, "Wrong round"
      if Meteor.user() != vote.voter
        throw Meteor.Error 403, "That's not you"
      oldVote = Votes.findOne
        voter: vote.voter
        round: @round
      if oldVote
        throw Meteor.Error 403, "You've already voted"
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
        throw Meteor.Error 403, "Not a voter in this election"
      return i
    return @factions[i]  
    
  finishRound: =>
    echo "fR not impl"
    
    
#debugger


    
  
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
        
  console.log "----published elections"
  console.log (Elections.find {}).count()
  
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
    if Meteor.user().eid
      Meteor.subscribe 'done_votes', Meteor.user().eid, ->
        console.log "done_votes (re)loaded"

  Meteor.autosubscribe ->
    Session.set 'election', new Election Elections.findOne
      _id: Meteor.user().eid
    console.log "election (re)loaded"
