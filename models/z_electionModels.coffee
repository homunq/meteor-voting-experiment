[isArray, isString, isDate] = _

if Meteor.isServer
  Meteor.startup =>
    @Future = Npm.require('fibers/future')
    @sleep = (untilWhen) ->
      waiter = new Future()
      if _.isFunction untilWhen
        untilWhen (val) ->
          waiter['return'](val)
      else
        setTimeout (-> waiter['return']()), untilWhen
      return waiter.wait()

echo = (args...) ->
  #debug args...

echo "echo", echo

ROBO_DEPTH = 50 #a robovote is chosen randomly from the first n real votes in similar circumstances.
  #If there aren't enough, the random pool is padded with default votes for the system/faction.
ROBO_SUB_DEPTH = 10 #if multiple robovotes are to be chosen, a block of ROBO_SUB_DEPTH contiguous votes
  #are the pool, with replacements.

randomTo = (roof) ->
  Math.floor(Math.random() * roof)

@Votes = new Meteor.Collection 'votes'

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

@Elections = new Meteor.Collection 'Elections', null

@MainElection = new Meteor.Collection 'mainElection', null
if Meteor.isServer && !MainElection.findOne()
  #debug "setting up MainElection..."
  MainElection.insert
    eid: null
  #debug "...setting up MainElection..."

backToHour = (aTime, roundBackTo) ->
  debug "backToHour", aTime, roundBackTo
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
      #debug "evenLater", evenLater
      #[now.getTime(), later.getTime(), evenLater]
      
    seed: ->
      Math.floor((Math.random()*0xffffff)+1)
    rtime:[] #time since start, floor 5
    winners: []
    outcomes: []
    howManyMore: 0
    nextElection: undefined
    
    
        
  @register
    make: @static (options, promote, delay, roundBackTo)->
      debug "new election"#, options 
      options ?= {}
      options = _(options).pick "scenario", "method", "howManyMore"
      if _.isNumber options.howManyMore
        options.method = METHOD_WHEEL[options.howManyMore % METHOD_WHEEL.length]
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
        sTimes: [later] #, evenLater]
        
      e = new Election options
      if Meteor.isServer
        e.factions = e.scen().shuffledFactions()
      e.save()
      debug "new election 2"#, options 
      if promote
        e.promote()
      e._id
      
    makeNext: @static (old_eid, options, promote, delay, roundBackTo, cb) ->
      #sleep 100 #TESTING! REMOVE REMOVE REMOVE!
      #debug "You idiot, remove the line above."
      #it never worked perfectly with above, but close enough. Someday, I may fix this.
      debug "makeNext", old_eid, options, promote, delay, roundBackTo, cb
      if Meteor.isClient
        return undefined #sorry, no can do.
      gotSemaphore = Elections.update
        _id: old_eid
        nextElection: undefined
        yes and
          $set:
            nextElection: true
      debug "gotSemaphore", gotSemaphore
      if not gotSemaphore
        while true
          me = Elections.findOne
            _id: old_eid
          debug me?.nextElection
          waited = 0
          if me?.nextElection is true #in progress
            debug "sleeping"
            sleep 100
            debug "slept"
            waited += 1
            if waited > 10
              #something is wrong. Try to make a new one anyway.
              break
            continue
          debug "why sleep?", me.nextElection
          return me.nextElection
      #make it ourselves
      debug "make"
      new_eid = @make options, promote, delay, roundBackTo
      
      debug "made", new_eid
      if not new_eid
        new_eid = undefined
      saved = Elections.update
        _id: old_eid
        nextElection: undefined
        yes and
          $set:
            nextElection: new_eid
      debug saved
      if cb
        cb new_eid
      return new_eid
      
    join: @static (eid) ->
      uid = @userId
      election = Elections.findOne
        _id: eid
      if !election
        throw Meteor.Error 404, "notElection", "no such election"
      election = new Election election
      #debug election
      if (_.indexOf election.voters, uid) == -1
        election.addVoterAndSave(uid)
        
    watchMain: @static ->
      debug 'watchMain yo server is ', Meteor.isServer
      if Meteor.isServer
        debug 'watchMain 2'
        eid = MainElection.findOne()?.eid
        debug MainElection.find().fetch()
        if eid
          debug 'wm3', eid
          @watch eid
        else
          debug 'no elections pending'
      #return "yes you got watchMain babe"     
     
        
      
    watch: @static (eid) ->
      debug 'watch ', eid, @userId
      uid = @userId
      election = Elections.findOne
        _id: eid
      #debug 'watch 2', eid
      if !election
        throw Meteor.Error 404, "notElection", "no such election"
      election = new Election election
      #debug election
      #if (_.indexOf election.watchers, uid) == -1
      election.addWatcherAndSave(uid)
      #else
        #debug uid, " is already in ", election.watchers
          
        
    addVote: (vote) ->
      debug "addVote", vote, @userId
      uid = @userId
      if @stage != vote.stage
        debug "wrong stage"
        if @stage > vote.stage
          throw new Meteor.Error 403, 'wrongStage', "Sorry, the time ran out before that vote could be registered. (Reload to clear error display)"
        throw new Meteor.Error 403, 'wrongStage', "Wrong stage: election " + @stage + ", vote " + vote.stage + " ((in " + _.keys @
      if uid != vote.voter
        debug "not you"
        throw Meteor.Error 403, 'notYou', "That's not you"
      oldVote = Votes.findOne
        voter: vote.voter
        stage: @stage
        election: @_id
      if oldVote
        debug "already voted"
        throw new Meteor.Error 403, 'already', "You've already voted"
      faction = @factionOf uid #throws error on failure
      
      #comment out the following non-atomic mess because it should be handled in process.coffee
      #@stagesDoneBy[@stage] ?= 0
      #@inc
      #stagesDoneBy[@stage] += 1
      #@save()
      #debug "@stagesDoneBy[@stage]", @stage, @stagesDoneBy, @stagesDoneBy[@stage],  @scen().numVoters()
      #done = (@stagesDoneBy[@stage] >= @scen().numVoters())
  
      if vote.vote.length or _.isNumber vote.vote #Don't add null votes, but do move on regardless
        _.extend vote,
          election: @_id
          prevWinner: @winners[@stage - 1]
          faction: faction
          method: @method
          scenario: @scenario
          
        Votes.insert vote
      
      #debug "Vote added; stage done?:", done
      #if done then @finishStage() #@stage
      
      #debug "newVote update"
      
    clearAll: @static ->
      #debug "clearAll"
      Elections.remove {}
      
    addWatcherAndSave: (vid) ->
      debug "addWatcherAndSave "+vid + "     ;     ", @_id
      #if (_.indexOf @watchers, vid) == -1
      #  @watchers.push vid
      #eid = @save()
      voter = Meteor.users.findOne
        _id: vid
      if voter?.eid isnt @_id
        debug "eid", @_id, vid
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
      debug "findAndJoin for uid:"+@userId + "     ;     ", @_id
      old_eid = eid
      vid = @userId
      
      while Meteor.isServer
        debug "findAndJoin 2 ", eid
        try
          if not eid?
            eid = MainElection.findOne().eid
          election = Elections.findOne
            _id: eid
          if election
            election = new Election election
            election.addVoterAndSave vid
            debug "findAndJoin done"
            return eid
          else
            debug "findAndJoin can't find ", eid
            throw new Meteor.Error 404, "nullElection", "null election"
        catch e
          debug "findAndJoin make new ", e, options.howManyMore
          if e instanceof Meteor.Error
            if e.reason is 'duplicate'
              debug "...but it's just a wasntMe error. Still, easier to bail than to re-add."
              throw e
              #continue #this causes infinite loop. Correct thing to do would be to re-add on client but not server, or something...
            else if (e.reason is 'full') or (e.reason is 'tooLate')
              debug "so make?"
              if options.howManyMore > 0
                debug "yes"
                options.howManyMore = options.howManyMore - 1
                eid = @makeNext(old_eid, options, true, 0, false)
                continue
              else
                debug "no"
                throw e
            else
              throw e
          else
            throw e
      debug "findAndJoin AAAK"
            
    addVoterAndSave: (vid) ->
      #debug "addVoterAndSave "+vid + "     ;     "
      if Meteor.isServer
        #debug @factions
        debug "Adding voter ", vid, "to an election with voters", @voters, "?"
        if (_.indexOf @voters, vid) >= 0
          err = "Sorry, you cannot participate in this same election twice. (How did you do that?)"
          debug err
          throw new Meteor.Error 403, 'duplicate', err
        user = new MtUser Meteor.users.findOne
          _id: vid
        if user.nonunique
          throw new Meteor.Error 403, 'nonunique', "Sorry, you cannot participate in this experiment twice."
        if @stage > 1
          throw new Meteor.Error 403, 'tooLate', "Experiment already in progress; cannot join."
        numVoters = @scen().numVoters()
        if @voters.length >= numVoters
          debug "FULL", @voters
          throw new Meteor.Error 403, 'full', "Election full."
        @push
          voters: vid
        , true, (err, n) => #the "true" is to ensure it's called syncronously
          if @stage is 0
            @nextStage("timerOnly")
          debug "voter added", @_id, vid
          vIndex = _.indexOf @voters, vid
          if vIndex < 0
            debug "Adding voter failed mysteriously... BAD BAD BAD"
            throw new Meteor.Error 401, 'mystery', "Joining election failed."
          if vIndex >= numVoters
            @pull
              voters: vid
            throw new Meteor.Error 403, 'full', "Election filled up."
          @inc
            "stagesDoneBy.0": 1
          Meteor.users.update
            _id: vid
          ,
            $set:
              eid: @_id
              faction: @factions[vIndex]
              watcher: false
              blurbCondition: generateBlurbCondition @factions[vIndex], vIndex, @
              showAverageCondition: generateShowAverageCondition @factions[vIndex], vIndex, @
              subtotalCondition: generateSubtotalCondition @factions[vIndex], vIndex, @
          ,
            multi: false
      
    promote: ->
      #debug "promote"
      if Meteor.isServer
        mainElection = MainElection.findOne({})
        mainElection.eid = @._id
        MainElection.update
          _id: mainElection._id
        , mainElection
        #debug mainElection, MainElection.findOne({})
        
    robovotes: (stage) ->
      debug "robovotes", stage
      robofactions = @factions.slice(@voters.length)
      factionCounts = _.countBy robofactions, (x)->x
      debug "robovotes", robofactions, factionCounts, @factions
      votesByFaction = for faction, numVotes of factionCounts
        faction = parseInt faction #!@#$#@!$ _.countby converts to strings, damne its eyes.
        for vote in @robovotesForFaction(faction, numVotes, stage)
          @recordRobovote vote, faction
      return _.flatten votesByFaction, yes #shallow flatten to go from votesByFaction to votes.
    
    robovotesForFaction: (faction, numVotes, stage) ->
      debug "robovotesForFaction", faction, numVotes, stage
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
          debug "oldVote", oldVote.vote, faction
          oldVote.vote
        else
          honestVote ?= @meth().honestVote(@scen().payoffsForFaction(faction).payoffs)
          debug "honestVote", honestVote.vote, faction
          honestVote
            
        
    recordRobovote: (vote, faction) ->
      debug "recordRobovote", vote, faction
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
        debug "finishStage", stage
        fullRobovotes = @robovotes stage
        [votesForStage, fullVotes] = @votesForStage stage, undefined, "noRobos"
        votesForStage = votesForStage.concat (robo.vote for robo in fullRobovotes)
        
        debug "finishStage fullVotes = fullVotes.concat fullRobovotes", fullVotes, fullRobovotes
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
        debug "winners, winner, tiebreakers: ", winners, winner, tiebreakers
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
        debug "My new outcome is", outcome
        outcome.save()
        debug "and I just saved it:", outcome._id, Outcomes.findOne
          _id: outcome._id
        @winners[stage] = winner
        @outcomes[stage] = outcome._id
        @save()
      
    nextStage: (timerOnly) ->
      debug "election.nextStage", @_id, @stage, @sTimes
      stage = @stage
      if not timerOnly
        stage += 1
      if Meteor.isServer 
        now = (new Date).getTime()
        if nullOrAfterNow(@sTimes[stage])
          debug "election.nextStage 12", stage, @sTimes
          @sTimes[stage] = now
        @setTimerIf stage, 0, timerOnly
      if not timerOnly
        @stage = stage
        do @save
        
    setTimerIf: (stage, numDone, save) ->
      if Meteor.isServer 
        debug "setTimerIf", stage, numDone
        now = (new Date).getTime()
        delay = PROCESS.minsForStage(stage) * 60 * 1000
        if delay > 0
          debug "poss setting stage timeout (voters,done,slackers)", @numVoters(), numDone, @numSlackers()
          base = now
          if stage isnt @stage
            base = _.max([base, @sTimes[stage]])
          later = base + delay
          if (not @sTimes[stage + 1]?) or ((@sTimes[stage + 1] < now) and (stage > 0)) or (later < @sTimes[stage + 1]) #(@numVoters() - numDone) <= @numSlackers()
            @sTimes[stage + 1] = later
            if save
              @save()
            sT = (ms, fn) ->
              Meteor.setTimeout fn, ms
              
            sT @sTimes[stage + 1] - now, =>
              debug "advance if stage <", stage
              @.constructor.nextForTime @_id, stage
            
              
    nextForTime: @static (eid, stage) ->
      election = new Election Elections.findOne
        _id: eid
      if election.stage <= stage
        debug "Stage timeout! Advancing stage\n!\n!\n!", eid, stage + 1
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
        throw Meteor.Error 403, 'nonvoter', "Not a voter in this election"
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
    debug "votesForStage", stage, fullVotes
    [v.vote for v in fullVotes, fullVotes]
  
  isFull: ->
    debug "isFull", @voters.length, @scen().numVoters()
    @voters.length >= @scen().numVoters()
    
  numVoters: ->
    @voters.length
    
  numSlackers: ->
    Math.max(Math.ceil(@numVoters() * 2 / 9), Math.min(2, Math.ceil(@numVoters() / 2)))
    
Election.admin()
    
#debugger

echo 'Election', Election
    
  
@Outcomes = new Meteor.Collection 'outcomes', null

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
  Meteor.publish 'allElections', (password) ->
    if password is PASSWORD
      return Elections.find {},
        fields:
          #voters: 0
          factions: 0
    this.ready()
    
  
  Meteor.publish 'oneElection', (eid) ->
    debug "publishing oneElection", eid
    [
      Elections.find {_id:eid},
        fields:
          #voters: 0
          factions: 0
      Votes.find
          eid: eid
          done: true
        ,
          voter: 0
      Outcomes.find
        election: eid
    ]
        
    
  #debug "----published elections"
  #debug (Elections.find {}).count()
      
  #debug "gonna .autorun"
  #Meteor.autorun ->
  #  Outcomes.find().fetch({},{reactive: true})
    #---------------------
  #  debug "should be (re-)publishing outcomes"
  
  Outcomes.allow
    insert: ->
      yes

else if Meteor.isClient
  #Meteor.subscribe 'elections'

  @OLD_ELECTION = undefined
  @OLD_USER = undefined
  @OLD_STEP_COMPLETED_NUM = undefined
  
  #on auto-reloads, session variables can be left over, but global variables aren't. Clear them out if so.
  if Session.get 'election'
    debug "resetting session variables"
    Session.set 'election', undefined
    Session.set 'scenario', undefined
    #but only the ones that are object-oriented. Static data should still be OK.
    #Session.set 'stage', undefined
    #Session.set 'stepCompletedNums', undefined
    Session.set 'method', undefined
  
  debug 'Autosubscribing...', OLD_ELECTION, OLD_USER
  Meteor.autosubscribe ->
    debug 'autosubscribe (re)new'
    if (Session.get 'router') and ROUTER?.current_page.get() is 'loggedIn'
      user = Meteor.user()
      debug "got new user", user?._id
      if user?.faction isnt OLD_USER?.faction
        Session.set 'faction', user?.faction
      if user?.step isnt OLD_USER?.step
        if user?.step is 1 and not Session.get('movedPastZero')
          debug "straight to step 1 - better to restart, election could be stale."
          Meteor.logout ->
            login_then "", ->
              Election.watchMain (error, result) ->
                debug "now I should have a new user:", Meteor.user()
          return
        Session.set 'step', user?.step
      if user?.step isnt OLD_USER?.step or user?.lastStep isnt OLD_USER?.lastStep
        Session.set 'stepLastStep', [user?.step, user?.lastStep or -1]
      OLD_USER = user
      
      
      eid = user?.eid
      debug "election (re)loading", eid
      if eid
        e = Elections.findOne
          _id: eid
        #important for reactivity to try finding before subscribing/disconnecting
        Meteor.subscribe 'oneElection', eid, ->
          debug "oneElection (re)loaded"
        if not global.SUBSCRIBED?
          global.SUBSCRIBED = yes
          debug "subscribed", eid
          return 1
        if not e?
          debug "no election for eid", eid
          return 1
        debug "really (re)loading",Meteor.user().eid,  e?._id
        global.ELECTION = new Election e
        debug "set ELECTION", e?._id#, global.ELECTION, "global", global, "Election", Election
        Session.set 'election', e
        Session.set 'stage', ELECTION.stage
        Session.set 'stepCompletedNums', ELECTION.stepsDoneBy
        stepCompletedNum = ELECTION.stepsDoneBy[user?.step] ? 0
        if stepCompletedNum isnt OLD_STEP_COMPLETED_NUM
          OLD_STEP_COMPLETED_NUM = stepCompletedNum
          
          votersLeft = ELECTION.scen().numVoters - stepCompletedNum 
          if votersLeft <= ELECTION.scen().hurryNumber and (user.step isnt user.lastStep)
            playSound "hurry"
        #subscribe
        debug "subscribing oneElection", eid
        if eid isnt OLD_ELECTION?._id #don't obsessively reload stable values
            
          #set session vars  
          if ELECTION.scen() isnt OLD_ELECTION?.scen()     
            global.SCENARIO = ELECTION.scen()
            Session.set 'scenario', ELECTION.scenario
            debug "set scenario", ELECTION.scenario
          if ELECTION.meth() isnt OLD_ELECTION?.meth()       
            global.METHOD = ELECTION.meth()        
            Session.set 'method', ELECTION.method
          OLD_ELECTION = ELECTION
                
          debug "fully (re)loaded ",Meteor.user().eid,  e?._id
