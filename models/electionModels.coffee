[isArray, isString, isDate] = _

echo = (args...) ->
  console.log args...

echo "echo", echo

Votes = new Meteor.Collection 'votes'

class @Vote extends StamperInstance
  collection: Votes
  
  @fields
    voter: null
    faction: null
    election: null
    stage: null
    step: null
    vote: [] #higher is better
    method: 'approval'

Elections = new Meteor.Collection 'elections', null

MainElection = new Meteor.Collection 'mainElection', null
if Meteor.is_server && !MainElection.findOne()
  console.log "setting up MainElection..."
  MainElection.insert
    eid: null
  console.log "...setting up MainElection..."

class @Election extends StamperInstance
  collection: Elections
  
  @fields
    scenario: null
    method: null
    watchers: [] #before consent is clicked; ready to join
    voters: [] #consent is clicked, faction is assigned
    factions: []
    stepsDoneBy: [0] #how many voters/watchers have done each step
    stagesDoneBy: [0] #how many voters/watchers have done each step
    full: false
    stage: 0
    sTimes: ->
      now = new Date
      later = new Date
      later.setMinutes(now.getMinutes() + 100) #plus 1:40
      later.setMinutes(0) #rounded back to on-the-hour
      later.setSeconds(0) #rounded back to on-the-hour
      later.setMilliseconds(0) #rounded back to on-the-hour
      [now.getTime(), later.getTime()]
    seed: ->
      Math.floor((Math.random()*0xffffff)+1);
    rtime:[] #time since start, floor 5
    winners: []
    outcomes: []
    
  if Meteor.is_server
    @fields
      nonfactions: [] #[0, 0, 1, 1, ... 2, ...]
    
    
  @register
    make: @static (options, promote)->
      console.log "new election", options 
      options ?= {}
      options = _(options).pick "scenario", "method"
      
      _(options).defaults
        scenario: 'chicken'
        method: 'approval'
        watchers: []
        voters: []
        factions: []
        
      e = new Election options
      if Meteor.is_server
        e.nonfactions = e.scen().shuffledFactions()
      
      eid = e.addWatcherAndSave @userId()
      console.log "e IS ", e
      console.log "EID IS ", eid, e._id
      console.log "UID IS "+@userId()
      if promote
        e.promote()
      
    join: @static (eid) ->
      uid = @userId()
      election = Elections.findOne
        _id: eid
      if !election
        throw Meteor.Error 404, "no such election"
      election = new Election election
      console.log election
      if (_.indexOf election.voters, uid) == -1
        election.addVoterAndSave(uid)
        
    watchMain: @static ->
      console.log 'watchMain '
      if Meteor.is_server
        console.log 'watchMain 2'
        eid = MainElection.find().fetch()[0].eid
        console.log MainElection.find().fetch()[0]
        if eid
          @watch eid
        else
          console.log 'no elections pending'
        
      
    watch: @static (eid) ->
      console.log 'watch ', eid
      uid = @userId()
      election = Elections.findOne
        _id: eid
      console.log 'watch 2', eid
      if !election
        throw Meteor.Error 404, "no such election"
      election = new Election election
      console.log election
      if (_.indexOf election.watchers, uid) == -1
        election.addWatcherAndSave(uid)
      else
        console.log uid, " is already in ", election.watchers
          
        
    addVote: (vote) ->
      console.log "addVote1", @
      console.log "addVote2", @.raw()
      uid = @userId()
      if @stage != vote.stage
        throw new Meteor.Error 403, "Wrong stage: election " + @stage + ", vote " + vote.stage + " ((in " + _.keys @
      if uid != vote.voter
        throw Meteor.Error 403, "That's not you"
      oldVote = Votes.findOne
        voter: vote.voter
        stage: @stage
      if oldVote
        throw new Meteor.Error 403, "You've already voted"
      faction = @factionOf uid #throws error on failure
      
      @stagesDoneBy[@stage] += 1
      done = (@stagesDoneBy[@stage] >= @scen().numVoters())
  
      _.extend vote,
        election: @_id
        faction: faction
        method: @method
        
      Votes.insert vote
      
      if done then @finishStage()
      
      console.log "newVote update"
      
    clearAll: @static ->
      console.log "clearAll"
      Elections.remove {}
      
    addWatcherAndSave: (vid) ->
      console.log "addWatcherAndSave "+vid + "     ;     "
      @watchers.push vid
      eid = @save()
      Meteor.users.update
        _id: vid
      ,
        $set:
          eid: eid
          watcher: true
          step: 0
      ,
        multi: false
      eid
      
    addVoterAndSave: (vid) ->
      console.log "addVoterAndSave "+vid + "     ;     "
      if Meteor.is_server
        console.log @nonfactions, @factions
        if @nonfactions.length is 0
          throw new Meteor.Error 403, "Election full"
        if @stage isnt 0
          throw new Meteor.Error 403, "Huh? There's room but they moved on'"
        @voters.push vid
        faction = @nonfactions.pop()
        @factions.push faction
        @stagesDoneBy[0] += 1
        eid = @save()
        console.log " "+ @nonfactions + @factions + eid
        Meteor.users.update
          _id: vid
        ,
          $set:
            eid: eid
            faction: faction
            watcher: false
        ,
          multi: false
        eid
      
    promote: ->
      console.log "promote"
      if Meteor.is_server
        mainElection = MainElection.findOne()
        mainElection.eid = @._id
        MainElection.update
          _id: mainElection._id
        , mainElection
  
  #local (non-registered) methods
      
      
  scen: ->
    Scenarios[@scenario]
    
  meth: ->
    Methods[@method]
    
    
      
      
  factionOf: (voter, throwerr=true) =>
    i = _.indexOf @voters, voter
    if i == -1
      if throwerr
        throw Meteor.Error 403, "Not a voter in this election"
      return i
    return @factions[i]  
    
  completeness: ->
    "#{ @numVotes[@stage] }/#{ @scen()?.numVoters() }"
    
  votesForStage: (stage) ->
    vc = Votes.find
      election: @_id
      stage: stage
    v.vote for v in vc.fetch
    
  finishStage: (stage)=>
    [winner, counts] = @meth.resolveVotes @scen.numCands(), @seed + stage, @votesForStage stage
    outcome = new Outcome
      winner: winner
      counts: counts
      election: @_id
      stage: stage
      method: @method
      scenario: @scenario
    outcome.save()
    @winners[stage] = winner
    @outcomes[stage] = outcome._id
    @save()
    
    
#debugger

echo 'Election', Election
    
  
Outcomes = new Meteor.Collection 'outcomes', null

class @Outcome extends StamperInstance
  collection: Outcomes
  
  @fields
    election: null
    scenario: null
    method: null
    stage: 0
    resolved: (new Date).getTime()
    winner: []
    
  if Meteor.is_server
    @fields
      nonfactions: [] #[0, 0, 1, 1, ... 2, ...]
    
    
  @register
  


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
      
  Meteor.publish 'outcomes', (eid) ->
    Outcomes.find
      election: eid

else if Meteor.is_client
  Meteor.subscribe 'elections'
  Meteor.autosubscribe ->
    eid = Meteor.user()?.eid
    if eid
      Meteor.subscribe 'done_votes', eid, ->
        console.log "done_votes (re)loaded"
      Meteor.subscribe 'outcomes', eid, ->
        console.log "outcomes (re)loaded"

  OLD_ELECTION = undefined
  OLD_USER = undefined
  Meteor.autosubscribe ->
    user = Meteor.user()
    eid = user?.eid
    console.log "election (re)loading", eid
    if eid
      e = Elections.findOne
        _id: eid
      console.log "really (re)loading",Meteor.user().eid,  e
      election = new Election e
      Session.set 'election', election
      Session.set 'stage', election.stage
      if eid isnt OLD_ELECTION?._id #don't obsessively reload stable values
        if election.scen() isnt OLD_ELECTION?.scen()            
          Session.set 'scenario', election.scen()
        if election.meth() isnt OLD_ELECTION?.meth()            
          Session.set 'method', election.meth()
        OLD_ELECTION = election
        console.log "really (re)loaded ",Meteor.user().eid,  e
    if user?.faction isnt OLD_USER?.faction
      Session.set 'faction', user.faction
    if user?.step isnt OLD_USER?.step
      Session.set 'step', user.step
      
    OLD_USER = user
