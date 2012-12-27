[isArray, isString, isDate] = _

echo = (args...) ->
  #console.log args...

echo "echo", echo

Votes = new Meteor.Collection 'votes'

class @Vote extends VersionedInstance
  collection: Votes
  
  @fields
    voter: null
    faction: null
    election: null
    stage: null
    step: null
    vote: [] #higher is better
    method: null #'approval'
    scenario: null #'chicken'
    
  scen: ->
    Scenarios[@scenario]
    
  meth: ->
    Methods[@method]

Elections = new Meteor.Collection 'elections', null

MainElection = new Meteor.Collection 'mainElection', null
if Meteor.is_server && !MainElection.findOne()
  #console.log "setting up MainElection..."
  MainElection.insert
    eid: null
  #console.log "...setting up MainElection..."

backToHour = (aTime) ->
  aTime.setMinutes(0) #rounded back to on-the-hour
  aTime.setSeconds(0) #rounded back to on-the-hour
  aTime.setMilliseconds(0) #rounded back to on-the-hour
  aTime
  
minutesFromNow = (mins) ->
  later = new Date
  later.setMinutes(later.getMinutes() + mins)
  later
  
nullOrAfterNow = (ms) ->
  if not ms
    return true
  return ((new Date).getTime() - ms) < 0

class @Election extends VersionedInstance
  collection: Elections
  
  @fields
    scenario: null
    method: null
    watchers: [] #before consent is clicked; ready to join
    
    voters: [] #consent is clicked, faction is assigned
    factions: [] #same order as voters
    
    stepsDoneBy: [0] #how many voters/watchers have done each step
    stagesDoneBy: [0] #how many voters/watchers have done each step
    full: false
    stage: 0
    sTimes: [] #->
      #now = new Date
      #later = backToHour minutesFromNow 100
      #evenLater = later.getTime() + PROCESS.minsForStage(1) * 60 * 1000
      #console.log "evenLater", evenLater
      #[now.getTime(), later.getTime(), evenLater]
      
    seed: ->
      Math.floor((Math.random()*0xffffff)+1)
    rtime:[] #time since start, floor 5
    winners: []
    outcomes: []
    
  if Meteor.is_server
    @fields
      nonfactions: [] #[0, 0, 1, 1, ... 2, ...]
    
    
  @register
    make: @static (options, promote, delay)->
      #console.log "new election", options 
      options ?= {}
      options = _(options).pick "scenario", "method"
      delay ?= 0
      later = minutesFromNow delay
      if delay > 10
        later = backToHour later
      #evenLater = later.getTime() + PROCESS.minsForStage(1) * 60 * 1000
      
      _(options).defaults
        scenario: 'chicken'
        method: 'approval'
        watchers: []
        voters: []
        factions: []
        sTimes: [(new Date).getTime(), later.getTime()] #, evenLater]
        
      e = new Election options
      if Meteor.is_server
        e.nonfactions = e.scen().shuffledFactions()
      e.save()
      #console.log "EID IS ", e._id
      #console.log "UID IS "+@userId()
      if promote
        e.promote()
      
    join: @static (eid) ->
      uid = @userId()
      election = Elections.findOne
        _id: eid
      if !election
        throw Meteor.Error 404, "no such election"
      election = new Election election
      #console.log election
      if (_.indexOf election.voters, uid) == -1
        election.addVoterAndSave(uid)
        
    watchMain: @static ->
      #console.log 'watchMain '
      if Meteor.is_server
        #console.log 'watchMain 2'
        eid = MainElection.find().fetch()[0].eid
        #console.log MainElection.find().fetch()
        if eid
          @watch eid
        else
          #console.log 'no elections pending'
        
      
    watch: @static (eid) ->
      #console.log 'watch ', eid
      uid = @userId()
      election = Elections.findOne
        _id: eid
      #console.log 'watch 2', eid
      if !election
        throw Meteor.Error 404, "no such election"
      election = new Election election
      #console.log election
      if (_.indexOf election.watchers, uid) == -1
        election.addWatcherAndSave(uid)
      else
        #console.log uid, " is already in ", election.watchers
          
        
    addVote: (vote) ->
      console.log "addVote", vote
      uid = @userId()
      if @stage != vote.stage
        throw new Meteor.Error 403, "Wrong stage: election " + @stage + ", vote " + vote.stage + " ((in " + _.keys @
      if uid != vote.voter
        throw Meteor.Error 403, "That's not you"
      oldVote = Votes.findOne
        voter: vote.voter
        stage: @stage
        election: @_id
      if oldVote
        throw new Meteor.Error 403, "You've already voted"
      faction = @factionOf uid #throws error on failure
      
      @stagesDoneBy[@stage] ?= 0
      @stagesDoneBy[@stage] += 1
      @save()
      console.log "@stagesDoneBy[@stage]", @stage, @stagesDoneBy, @stagesDoneBy[@stage],  @scen().numVoters()
      done = (@stagesDoneBy[@stage] >= @scen().numVoters())
  
      _.extend vote,
        election: @_id
        faction: faction
        method: @method
        scenario: @scenario
        
      Votes.insert vote
      
      #console.log "Vote added; stage done?:", done
      if done then @finishStage @stage
      
      #console.log "newVote update"
      
    clearAll: @static ->
      #console.log "clearAll"
      Elections.remove {}
      
    addWatcherAndSave: (vid) ->
      #console.log "addWatcherAndSave "+vid + "     ;     "
      if (_.indexOf @watchers, vid) == -1
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
      #console.log "addVoterAndSave "+vid + "     ;     "
      if Meteor.is_server
        #console.log @nonfactions, @factions
        if (_.indexOf @voters, vid) >= 0
          err = "Sorry, you cannot participate in this same election twice. (How did you do that?)"
          console.log err
          throw new Meteor.Error 403, err
        user = new User Meteor.users.findOne
          _id: vid
        if user.nonunique
          throw new Meteor.Error 403, "Sorry, you cannot participate in this experiment twice."
        if @nonfactions.length is 0
          throw new Meteor.Error 403, "Election full"
        if @stage isnt 0
          throw new Meteor.Error 403, "Huh? There's room but they moved on'"
        @voters.push vid
        faction = @nonfactions.pop()
        @factions.push faction
        @stagesDoneBy[0] += 1
        eid = @save()
        #console.log " "+ @nonfactions + @factions + eid
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
      #console.log "promote"
      if Meteor.is_server
        mainElection = MainElection.findOne({})
        mainElection.eid = @._id
        MainElection.update
          _id: mainElection._id
        , mainElection
        #console.log mainElection, MainElection.findOne({})
        
    finishStage: (stage) ->
      console.log "finishStage"
      [winners, counts] = @meth().resolveVotes @scen().numCands(), @votesForStage stage
      tiebreakerGen = new MersenneTwister(@seed + stage)
      tiebreakers = (tiebreakerGen.random() for cand in _.range @scen().numCands())
      best = -1
      if winners.length is 0
        winners.push 0
      for oneWinner in winners
        if tiebreakers[oneWinner] > best
          winner = oneWinner
          best = tiebreakers[oneWinner]
      console.log "winners, winner, tiebreakers: ", winners, winner, tiebreakers
      factionCounts = for faction in @scen().factions()
        [winners, counts] = @meth().resolveVotes @scen().numCands(), @votesForStage stage, faction
        counts
      outcome = new Outcome
        winner: winner
        counts: counts
        factionCounts: factionCounts
        election: @_id
        stage: stage
        method: @method
        scenario: @scenario
      outcome.save()
      @winners[stage] = winner
      @outcomes[stage] = outcome._id
      @save()
      
    nextStage: (dontSave) ->
      console.log "election.nextStage"
      @stage += 1
      if Meteor.is_server 
        now = (new Date).getTime()
        delay = PROCESS.minsForStage(@stage) * 60 * 1000
        if nullOrAfterNow(@sTimes[@stage])
          @sTimes[@stage] = now
        console.log "setting stage timeout??", @sTimes, @sTimes[@stage + 1], delay, @stage, now, now + delay
        if not @sTimes[@stage + 1]
          console.log "setting stage timeout", delay, @stage, now, now + delay
          @sTimes[@stage + 1] = now + delay
          sT = (ms, fn) ->
            Meteor.setTimeout fn, ms
            
          console.log "nextForTime", @, @::, @_id
          sT delay, =>
            console.log "nextForTime", @, @.constructor, @_id
            @.constructor.nextForTime @_id, @stage
      if not dontSave
        @save()
              
    nextForTime: @static (eid, stage) ->
      console.log "Stage timeout! Advancing stage\n!\n!\n!", eid, stage + 1
      election = new Election Elections.findOne
        _id: eid
      if election.stage = stage
        election.finishStage()
        election.nextStage()

      
      
    userNonunique: (user) ->
      voterIndex = _.indexOf @voters, user
      if voterIndex >= 0
        @voters.splice voterIndex, 1
        [faction] = @factions.splice voterIndex, 1
        if Meteor.is_server
          @nonfactions.push faction
        @save()
        
        
        
  
  #local (non-registered) methods
      
      
  scen: ->
    Scenarios[@scenario]
    
  meth: ->
    Methods[@method]
    
    
      
      
  factionOf: (voter, throwerr=true) ->
    i = _.indexOf @voters, voter
    if i == -1
      if throwerr
        throw Meteor.Error 403, "Not a voter in this election"
      return i
    return @factions[i]  
    
  completeness: ->
    "#{ @numVotes[@stage] }/#{ @scen()?.numVoters() }"
    
  votesForStage: (stage, faction) ->
    searchKey = 
      election: @_id
      stage: stage
    if faction?
      searchKey.faction = faction
    vCursor = Votes.find searchKey
    fullVotes = vCursor.fetch()
    #console.log "votesForStage", stage, fullVotes
    v.vote for v in fullVotes
    
    
    
#debugger

echo 'Election', Election
    
  
Outcomes = new Meteor.Collection 'outcomes', null

class @Outcome extends VersionedInstance
  collection: Outcomes
  
  @fields
    election: null
    scenario: null
    method: null
    stage: 0
    winner: null
    counts: []
    factionCounts: null
    
  
  scen: ->
    Scenarios[@scenario]
    
  meth: ->
    Methods[@method]
    
  payFactionCents: (faction) ->
    @scen().payoffCents @winner, faction

if Meteor.is_server
  Elections.r
  # publish all the non-full elections.
  Meteor.publish 'elections', ->
    Elections.find {},
      fields:
        #voters: 0
        factions: 0
        nonfactions: 0
        
  #console.log "----published elections"
  #console.log (Elections.find {}).count()
  
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
    if (Session.get 'router')?.current_page() is 'loggedIn'
      eid = Meteor.user()?.eid
      if eid
        Meteor.subscribe 'done_votes', eid, ->
          #console.log "done_votes (re)loaded"
        Meteor.subscribe 'outcomes', eid, ->
          #console.log "outcomes (re)loaded"

  OLD_ELECTION = undefined
  OLD_USER = undefined
  OLD_STEP_COMPLETED_NUM = undefined
  Meteor.autosubscribe ->
    if (Session.get 'router')?.current_page() is 'loggedIn'
      user = Meteor.user()
      if user?.faction isnt OLD_USER?.faction
        Session.set 'faction', user.faction
      if user?.step isnt OLD_USER?.step or user?.lastStep isnt OLD_USER?.lastStep
        Session.set 'stepLastStep', [user.step, user.lastStep]
      if user?.step isnt OLD_USER?.step
        Session.set 'step', user.step
      OLD_USER = user
      
      
      eid = user?.eid
      console.log "election (re)loading", eid
      if eid
        e = Elections.findOne
          _id: eid
        console.log "really (re)loading",Meteor.user().eid,  e
        election = new Election e
        Session.set 'election', election
        Session.set 'stage', election.stage
        stepCompletedNum = election.stepsDoneBy[user?.step] ? 0
        if stepCompletedNum isnt OLD_STEP_COMPLETED_NUM
          Session.set "stepCompletedNum", stepCompletedNum
          OLD_STEP_COMPLETED_NUM = stepCompletedNum
          
          votersLeft = election.scen().numVoters - stepCompletedNum 
          if votersLeft <= election.scen().hurryNumber and (user.step isnt user.lastStep)
            playSound "hurry"
        if eid isnt OLD_ELECTION?._id #don't obsessively reload stable values
          if election.scen() isnt OLD_ELECTION?.scen()            
            Session.set 'scenario', election.scen()
          if election.meth() isnt OLD_ELECTION?.meth()            
            Session.set 'method', election.meth()
          OLD_ELECTION = election
                
          console.log "fully (re)loaded ",Meteor.user().eid,  e
