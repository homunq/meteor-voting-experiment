[isArray, isString, isDate] = _

echo = (args...) ->
  #slog args...

echo "echo", echo

ROBO_DEPTH = 50 #a robovote is chosen randomly from the first n real votes in similar circumstances.
  #If there aren't enough, the random pool is padded with default votes for the system/faction.
ROBO_SUB_DEPTH = 10 #if multiple robovotes are to be chosen, a block of ROBO_SUB_DEPTH contiguous votes
  #are the pool, with replacements.

randomTo = (roof) ->
  Math.floor(Math.random() * roof)

Votes = new Meteor.Collection 'votes'

class @Vote extends VersionedInstance
  __name__: "Vote"
  collection: Votes
  
  @fields
    voter: null
    faction: null
    election: null
    stage: null
    step: null
    robo: no
    prevWinner: null #winner of previous round; helps robot voters be more realistic
    vote: [] #higher is better
    method: null #'approval'
    scenario: null #'chicken'
    
  scen: ->
    Scenarios[@scenario]
    
  meth: ->
    Methods[@method]
    
Vote.admin()

Elections = new Meteor.Collection 'elections', null

MainElection = new Meteor.Collection 'mainElection', null
if Meteor.isServer && !MainElection.findOne()
  #slog "setting up MainElection..."
  MainElection.insert
    eid: null
  #slog "...setting up MainElection..."

backToHour = (aTime, roundBackTo) ->
  slog "backToHour", aTime, roundBackTo
  aTime.setMinutes(aTime.getMinutes() - roundBackTo)
  aTime.setMinutes(0,0,0) #rounded back to on-the-hour
  aTime.setMinutes(aTime.getMinutes() + roundBackTo)
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
  __name__: "Election"
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
      #slog "evenLater", evenLater
      #[now.getTime(), later.getTime(), evenLater]
      
    seed: ->
      Math.floor((Math.random()*0xffffff)+1)
    rtime:[] #time since start, floor 5
    winners: []
    outcomes: []
    
    
    
  @register
    make: @static (options, promote, delay, roundBackTo)->
      slog "new election"#, options 
      options ?= {}
      options = _(options).pick "scenario", "method"
      if delay
        later = minutesFromNow delay
        if roundBackTo >= 0
          later = backToHour later, roundBackTo
        later = later.getTime()
      else
        later = undefined
      #evenLater = later.getTime() + PROCESS.minsForStage(1) * 60 * 1000
      
      _(options).defaults
        scenario: 'chicken'
        method: 'approval'
        watchers: []
        voters: []
        factions: []
        sTimes: [(new Date).getTime(), later] #, evenLater]
        
      e = new Election options
      if Meteor.isServer
        e.factions = e.scen().shuffledFactions()
      e.save()
      slog "new election 2"#, options 
      if promote
        e.promote()
      
    join: @static (eid) ->
      uid = @userId()
      election = Elections.findOne
        _id: eid
      if !election
        throw Meteor.Error 404, "no such election"
      election = new Election election
      #slog election
      if (_.indexOf election.voters, uid) == -1
        election.addVoterAndSave(uid)
        
    watchMain: @static ->
      slog 'watchMain yo server is ', Meteor.isServer
      if Meteor.isServer
        slog 'watchMain 2'
        eid = MainElection.findOne()?.eid
        slog MainElection.find().fetch()
        if eid
          slog 'wm3', eid
          @watch eid
        else
          slog 'no elections pending'
      #return "yes you got watchMain babe"     
     
        
      
    watch: @static (eid) ->
      slog 'watch ', eid, @userId
      uid = @userId
      election = Elections.findOne
        _id: eid
      #slog 'watch 2', eid
      if !election
        throw Meteor.Error 404, "no such election"
      election = new Election election
      #slog election
      #if (_.indexOf election.watchers, uid) == -1
      election.addWatcherAndSave(uid)
      #else
        #slog uid, " is already in ", election.watchers
          
        
    addVote: (vote) ->
      slog "addVote", vote, @userId
      uid = @userId
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
      
      #comment out the following non-atomic mess because it should be handled in process.coffee
      #@stagesDoneBy[@stage] ?= 0
      #@inc
      #stagesDoneBy[@stage] += 1
      #@save()
      #slog "@stagesDoneBy[@stage]", @stage, @stagesDoneBy, @stagesDoneBy[@stage],  @scen().numVoters()
      #done = (@stagesDoneBy[@stage] >= @scen().numVoters())
  
      if vote.vote.length or _.isNumber vote.vote #Don't add null votes, but do move on regardless
        _.extend vote,
          election: @_id
          prevWinner: @winners[@stage - 1]
          faction: faction
          method: @method
          scenario: @scenario
          
        Votes.insert vote
      
      #slog "Vote added; stage done?:", done
      #if done then @finishStage() #@stage
      
      #slog "newVote update"
      
    clearAll: @static ->
      #slog "clearAll"
      Elections.remove {}
      
    addWatcherAndSave: (vid) ->
      slog "addWatcherAndSave "+vid + "     ;     ", @_id
      #if (_.indexOf @watchers, vid) == -1
      #  @watchers.push vid
      #eid = @save()
      voter = Meteor.users.findOne
        _id: vid
      if voter?.eid isnt @_id
        slog "eid", @_id, vid
        Meteor.users.update
          _id: vid
        ,
          $set:
            eid: @_id
            watcher: true
            step: 0
        ,
          multi: false
        @_id
      
    findAndJoin: @static (eid, options) ->
      slog "findAndJoin "+@userId + "     ;     ", @_id
      vid = @userId
      
      while true
        slog "findAndJoin 2 ", eid
        try
          if not eid?
            eid = MainElection.findOne().eid
          election = Elections.findOne
            _id: eid
          if election
            election = new Election election
            election.addVoterAndSave vid
            return eid
          else
            slog "findAndJoin can't find ", eid
            throw new Meteor.Error 404, "null election"
        catch e
          slog "addWatcherAndSave make new ", e
          if e instanceof Meteor.Error
            eid = undefined
            @make(options, true, 0, false)
          else
            throw e
            
    addVoterAndSave: (vid) ->
      #slog "addVoterAndSave "+vid + "     ;     "
      if Meteor.isServer
        #slog @factions
        slog "Adding voter ", vid, "to an election with voters", @voters, "?"
        if (_.indexOf @voters, vid) >= 0
          err = "Sorry, you cannot participate in this same election twice. (How did you do that?)"
          slog err
          throw new Meteor.Error 403, err
        user = new MtUser Meteor.users.findOne
          _id: vid
        if user.nonunique
          throw new Meteor.Error 403, "Sorry, you cannot participate in this experiment twice."
        if @stage > 1
          throw new Meteor.Error 403, "Experiment already in progress; cannot join."
        numVoters = @scen().numVoters()
        if @voters.length >= numVoters
          slog "FULL", @voters
          throw new Meteor.Error 403, "Election full."
        @push
          voters: vid
        , =>
          if @stage is 0
            @nextStage("timerOnly")
          #slog "voter pushed", @, user
          vIndex = _.indexOf @voters, vid
          if vIndex < 0
            slog "Adding voter failed mysteriously... BAD BAD BAD"
            user.pushError "Joining election failed."
          if vIndex >= numVoters
            user.pushError "Election filled up."
            @pull
              voters: vid
            return
          @inc
            "stagesDoneBy.0": 1
          Meteor.users.update
            _id: vid
          ,
            $set:
              eid: @_id
              faction: @factions[vIndex]
              watcher: false
          ,
            multi: false
      
    promote: ->
      #slog "promote"
      if Meteor.isServer
        mainElection = MainElection.findOne({})
        mainElection.eid = @._id
        MainElection.update
          _id: mainElection._id
        , mainElection
        #slog mainElection, MainElection.findOne({})
        
    robovotes: (stage) ->
      slog "robovotes", stage
      robofactions = @factions.slice(@voters.length)
      factionCounts = _.countBy robofactions, (x)->x
      slog "robovotes", robofactions, factionCounts, @factions
      votesByFaction = for faction, numVotes of factionCounts
        faction = parseInt faction #!@#$#@!$ _.countby converts to strings, damne its eyes.
        for vote in @robovotesForFaction(faction, numVotes, stage)
          @recordRobovote vote, faction
      return _.flatten votesByFaction, yes #shallow flatten to go from votesByFaction to votes.
    
    robovotesForFaction: (faction, numVotes, stage) ->
      slog "robovotesForFaction", faction, numVotes, stage
      searchKey =
        prevWinner: @winners[stage - 1]
        faction: faction
        method: @method
        scenario: @scenario
        robo: no
        version: VERSION
      oldVotes = Votes.find searchKey,
        reactive: no
        limit: ROBO_DEPTH
      oldVotes = oldVotes.fetch()
      honestVote = undefined
      robovotes = for voter in [1..numVotes]
        oldVote = oldVotes[randomTo oldVotes.length+1] #a 1/n chance of an "honestVote"
        if oldVote?
          slog "oldVote", oldVote.vote, faction
          oldVote.vote
        else
          honestVote ?= @meth().honestVote(@scen().payoffsForFaction(faction).payoffs)
          slog "honestVote", honestVote.vote, faction
          honestVote
            
        
    recordRobovote: (vote, faction) ->
      slog "recordRobovote", vote, faction
      liveVote = new Vote
        vote: vote
        
        voter: null
        faction: faction
        election: @_id
        stage: @stage
        step: @step
        robo: yes
        prevWinner: @winners[@stage - 1] 
        method: @method
        scenario: @scenario
      liveVote.save()
      return liveVote
        
      
    finishStage: () ->
      stage = @stage
      if stage >= 1
        slog "finishStage", stage
        fullRobovotes = @robovotes stage
        [votesForStage, fullVotes] = @votesForStage stage, undefined, "noRobos"
        votesForStage = votesForStage.concat (robo.vote for robo in fullRobovotes)
        
        slog "finishStage fullVotes = fullVotes.concat fullRobovotes", fullVotes, fullRobovotes
        fullVotes = fullVotes.concat fullRobovotes
        tiebreakerGen = new MersenneTwister(@seed + stage)
        tiebreakers = (tiebreakerGen.random() for cand in _.range @scen().numCands())
        [winners, counts] = @meth().resolveVotes @scen(), votesForStage, tiebreakers
        best = -1
        if winners.length is 0
          winners.push 0
        if winners.length is 1
          ties = false
        else
          ties = winners
        for oneWinner in winners
          if tiebreakers[oneWinner] > best
            winner = oneWinner
            best = tiebreakers[oneWinner]
        slog "winners, winner, tiebreakers: ", winners, winner, tiebreakers
        factionCounts = for faction in @scen().factions()
          votesForFaction = (v.vote for v in fullVotes when v.faction is faction)
          [fwinners, fcounts] = @meth().resolveVotes @scen(), votesForFaction, tiebreakers
          fcounts
        outcome = new Outcome
          winner: winner
          ties: ties
          counts: counts
          factionCounts: factionCounts
          election: @_id
          stage: stage
          method: @method
          scenario: @scenario
          voters: v.voter for v in fullVotes
        slog "My new outcome is", outcome
        outcome.save()
        slog "and I just saved it:", outcome._id, Outcomes.findOne
          _id: outcome._id
        @winners[stage] = winner
        @outcomes[stage] = outcome._id
        @save()
      
    nextStage: (timerOnly) ->
      slog "election.nextStage", @_id, @stage, @sTimes
      stage = @stage
      if not timerOnly
        stage += 1
      if Meteor.isServer 
        now = (new Date).getTime()
        if nullOrAfterNow(@sTimes[stage])
          slog "election.nextStage 12", stage, @sTimes
          @sTimes[stage] = now
        @setTimerIf stage, 0
      if not timerOnly
        @stage = stage
        do @save
        
    setTimerIf: (stage, numDone) ->
      if Meteor.isServer 
        now = (new Date).getTime()
        delay = PROCESS.minsForStage(stage) * 60 * 1000
        if (not @sTimes[stage + 1]) and delay > 0
          slog "poss setting stage timeout (voters,done,slackers)", @numVoters(), numDone, @numSlackers()
          if (@numVoters() - numDone) <= @numSlackers()
            @sTimes[stage + 1] = now + delay
            sT = (ms, fn) ->
              Meteor.setTimeout fn, ms
              
            sT delay, =>
              @.constructor.nextForTime @_id, stage
              
    nextForTime: @static (eid, stage) ->
      election = new Election Elections.findOne
        _id: eid
      if election.stage <= stage
        slog "Stage timeout! Advancing stage\n!\n!\n!", eid, stage + 1
        election.stage = stage
        election.finishStage()
        election.nextStage()

      
      
    userNonunique: (user) ->
      voterIndex = _.indexOf @voters, user
      if voterIndex >= 0
        @voters.splice voterIndex, 1
        [faction] = @factions.splice voterIndex, 1
        if Meteor.isServer
          @factions.push faction
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
    
  votesForStage: (stage, faction, noRobos) ->
    searchKey = 
      election: @_id
      stage: stage
    if faction?
      searchKey.faction = faction
    if noRobos
      searchKey.robo = false
    vCursor = Votes.find searchKey
    fullVotes = vCursor.fetch()
    slog "votesForStage", stage, fullVotes
    [v.vote for v in fullVotes, fullVotes]
  
  isFull: ->
    slog "isFull", @voters.length, @scen().numVoters()
    @voters.length >= @scen().numVoters()
    
  numVoters: ->
    @voters.length
    
  numSlackers: ->
    Math.max(Math.ceil(@numVoters() * 2 / 9), Math.min(2, Math.ceil(@numVoters() / 2)))
    
Election.admin()
    
#debugger

echo 'Election', Election
    
  
Outcomes = new Meteor.Collection 'outcomes', null

class @Outcome extends VersionedInstance
  __name__: "Outcome"
  collection: Outcomes
  
  @fields
    election: null
    scenario: null
    method: null
    stage: 0
    winner: null
    ties: no
    counts: []
    factionCounts: null
    voters: []
    
  
  scen: ->
    Scenarios[@scenario]
    
  meth: ->
    Methods[@method]
    
  payFactionCents: (faction) ->
    @scen().payoffCents @winner, faction

Outcome.admin()

global = @
if Meteor.isServer
  Elections.r
  # publish all the non-full elections.
  Meteor.publish 'elections', ->
    Elections.find {},
      fields:
        #voters: 0
        factions: 0
        
  #slog "----published elections"
  #slog (Elections.find {}).count()
  
  Meteor.publish 'done_votes', (eid) ->
    Votes.find
      eid: eid
      done: true
    ,
      voter: 0
      #faction: 0 #do not hide this, even though it wouldn't be visible IRL
      
  Meteor.publish 'outcomes', (eid) ->
    #JUST DEBUGGING - reactivity failing - DELETE WHEN DONE
    Outcomes.find().fetch()
    #---------------------
    slog "(re-)publishing outcomes", eid
    Outcomes.find
      election: eid
      
  slog "gonna .autorun"
  Meteor.autorun ->
    Outcomes.find().fetch({},{reactive: true})
    #---------------------
    slog "should be (re-)publishing outcomes"
  
  Outcomes.allow
    insert: ->
      yes

else if Meteor.isClient
  Meteor.subscribe 'elections'

  @OLD_ELECTION = undefined
  @OLD_USER = undefined
  @OLD_STEP_COMPLETED_NUM = undefined
  slog 'Autosubscribing...', OLD_ELECTION, OLD_USER
  Meteor.autosubscribe ->
    if (Session.get 'router') and router?.current_page.get() is 'loggedIn'
      user = Meteor.user()
      slog "got new user", user
      if user?.faction isnt OLD_USER?.faction
        Session.set 'faction', user?.faction
      if user?.step isnt OLD_USER?.step or user?.lastStep isnt OLD_USER?.lastStep
        Session.set 'stepLastStep', [user?.step, user?.lastStep or -1]
      if user?.step isnt OLD_USER?.step
        Session.set 'step', user?.step
      OLD_USER = user
      
      
      eid = user?.eid
      slog "election (re)loading", eid
      if eid
        e = Elections.findOne
          _id: eid
        slog "really (re)loading",Meteor.user().eid,  e
        global.ELECTION = new Election e
        Session.set 'election', e
        Session.set 'stage', ELECTION.stage
        Session.set "stepCompletedNums", ELECTION.stepsDoneBy
        stepCompletedNum = ELECTION.stepsDoneBy[user?.step] ? 0
        if stepCompletedNum isnt OLD_STEP_COMPLETED_NUM
          OLD_STEP_COMPLETED_NUM = stepCompletedNum
          
          votersLeft = ELECTION.scen().numVoters - stepCompletedNum 
          if votersLeft <= ELECTION.scen().hurryNumber and (user.step isnt user.lastStep)
            playSound "hurry"
        #subscribe
        Meteor.subscribe 'done_votes', eid, ->
          #slog "done_votes (re)loaded"
        slog "subscribing outcomes", eid
        Meteor.subscribe 'outcomes', eid, ->
          slog "outcomes (re)loaded"
        if eid isnt OLD_ELECTION?._id #don't obsessively reload stable values
            
          #set session vars  
          if ELECTION.scen() isnt OLD_ELECTION?.scen()     
            global.SCENARIO = ELECTION.scen()
            Session.set 'scenario', ELECTION.scenario
          if ELECTION.meth() isnt OLD_ELECTION?.meth()       
            global.METHOD = ELECTION.meth()        
            Session.set 'method', ELECTION.method
          OLD_ELECTION = ELECTION
                
          slog "fully (re)loaded ",Meteor.user().eid,  e
