[isArray, isString, isDate] = _

echo = (args...) ->
  console.log args...

echo "echo", echo

Votes = new Meteor.Collection 'votes'
#  voter: 12
#  faction: 3
#  election: 1
#  round: 1
#  vote: [3,1,1] #higher is better
# ## denormalized info
#  method: 'approval'
#  done: false #denormalzed copy: all votes in for this round

Elections = new Meteor.Collection 'elections', null

class @Election extends StamperInstance
  collection: Elections
  
  @fields
    scenario: 'chicken'
    method: 'approval'
    voters: []
    factions: []
    numVotes: [0] #9 voters connected, 3 votes r1, 0 r2.
    full: false
    round: 0
    stimes: ->
      [new Date]
    seed: ->
      Math.floor((Math.random()*0xffffff)+1);
    rtime:[] #time since start, floor 5
    winners: []
    
  if Meteor.is_server
    @fields
      factions: []
      nonfactions: [] #[0, 0, 1, 1, ... 2, ...]
    
    
  @register
    make: @static (options)->
      console.log "new election"
      options ?= {}
      options = _(options).pick "scenario", "method"
      
      _(options).extend
        scenario: 'chicken'
        method: 'approval'
        voters: []
        factions: []
        
      e = new Election options
      e.nonfactions = _(e.scen().vfactions()).shuffle()
      
      eid = e.addVoterAndSave @userId()
      console.log "e IS ", e
      console.log "EID IS "+eid
      console.log "UID IS "+@userId()
      
      
    join: @static (eid) ->
      uid = @userId()
      console.log "join EID IS "+eid
      console.log "join UID IS "+uid
      election = Elections.findOne
        _id: eid
      console.log "!time to add voter"
      if !election
        console.log "!!!time to add voter"
        throw Meteor.Error 404, "no such election"
      console.log "time to add voter"
      election = new Election election
      console.log election
      if (_.indexOf election.voters, uid) == -1
        election.addVoterAndSave(uid)
          
        Meteor.users.update
          _id: uid
        ,
          $set:
            eid: eid
        ,
          multi: false
        
    newVote: (vote) =>
      if @round != vote.round
        throw new Meteor.Error 403, "Wrong round"
      if Meteor.user() != vote.voter
        throw Meteor.Error 403, "That's not you"
      oldVote = Votes.findOne
        voter: vote.voter
        round: @round
      if oldVote
        throw new Meteor.Error 403, "You've already voted"
      faction = @factionOf uid #throws error on failure
      
      @numvotes[@round] += 1
      done = (@numvotes[@round] >= @scen.numvoters())
  
      _.extend vote
        election: @_id
        faction: faction
        done: done
        
      Votes.insert vote
      
      if done then @finishRound()
      
      console.log "newVote update"
      Elections.update @_id, @
      
    clearAll: @static ->
      Elections.remove {}
      
    addVoterAndSave: (vid) ->
      console.log "addVoterAndSave "+vid + "     ;     "
      console.log " "+ @nonfactions + @factions
      if @nonfactions.length is 0
        throw new Meteor.Error 403, "Election full"
      if @round isnt 0
        throw new Meteor.Error 403, "Huh? There's room but they moved on'"
      @voters.push vid
      faction = @nonfactions.pop()
      @factions.push faction
      @numVotes[@round] += 1
      eid = @save()
      console.log " "+ @nonfactions + @factions + eid
      Meteor.users.update
        _id: vid
      ,
        $set:
          eid: eid
          faction: faction
      ,
        multi: false
      eid
  
  #local (non-registered) methods
      
      
  scen: (scenarioname) ->
    if @ == Election
      return Scenarios[scenarioname]
    Scenarios[@scenario]
    
  meth: (methname) ->
    if @ == Election
      return Methods[methname]
    Methods[@method]
    
    
      
      
  factionOf: (voter, throwerr=true) =>
    i = _.indexOf @voters, voter
    if i == -1
      if throwerr
        throw Meteor.Error 403, "Not a voter in this election"
      return i
    return @factions[i]  
    
  completeness: ->
    "#{ @numVotes[@round] }/#{ @scen()?.numvoters() }"
    
  finishRound: =>
    echo "fR not impl"
    
    
#debugger

echo 'Election', Election
    
  

if Meteor.is_server
  Elections.r
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
    if Meteor.user()?.eid
      Meteor.subscribe 'done_votes', Meteor.user().eid, ->
        console.log "done_votes (re)loaded"

  Meteor.autosubscribe ->
    console.log "election (re)loading", Meteor.user()
    if Meteor.user()?.eid
      e = Elections.findOne
        _id: Meteor.user().eid
      console.log "really (re)loading",Meteor.user().eid,  e
      Session.set 'election', new Election e
      console.log "really (re)loaded ",Meteor.user().eid,  e
