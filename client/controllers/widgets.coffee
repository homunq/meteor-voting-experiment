@seconds2roughTime = (seconds) ->
  rounded = Math.round(seconds/10) * 10
  if rounded is 0
    return "under 5 seconds"
  return "about "+seconds2time rounded
  
@seconds2time = (seconds, hideSeconds, notAbout) ->
  hours = Math.floor(seconds / 3600)
  minutes = Math.floor((seconds - (hours * 3600)) / 60)
  seconds = Math.floor(seconds - (hours * 3600) - (minutes * 60))
  time = ""
  time = hours + ":"  unless hours is 0
  if minutes isnt 0 or time isnt ""
    minutes = (if (minutes < 10 and time isnt "") then "0" + minutes else String(minutes))
    time += minutes + ""
  if not hideSeconds
    if time is ""
      time = seconds + "s"
    else
      time += (if (seconds < 10) then ":0" + seconds else ":" + seconds)
  time

@inTenSeconds = ->
  now = new Date
  later = new Date
  later.setSeconds(now.getSeconds() + 3) 
  return later.getTime()
  
#countdown
do ->
  intervaller = null
  intervalDone = no
  intervalStage = null
  untilTime = null
  Handlebars.registerHelper 'countdownToStage', (stage, before, after) ->
    #debug "countdownToStage", stage, intervalStage, intervalDone, intervaller
    election = (Session.get 'election') and ELECTION
    if stage isnt intervalStage
      Session.set 'error', ''
    if untilTime isnt election?.sTimes[stage]
      #debug "intervalStage"
      clearInterval intervaller
      if untilTime and (intervalStage is stage)
        playSound 'ahem'
      intervaller = null
      intervalDone = no
      intervalStage = stage
    if election?
      untilTime = election.sTimes[stage]
      #debug "untilTime", untilTime, stage, election.sTimes
      #untilTime = inTenSeconds()
      if not intervaller and not intervalDone
        Session.set 'countDown', no
        sI = (ms, fn) ->
          setInterval fn, ms
        intervaller = sI 2000, ->
          countDown = untilSTime untilTime
          #debug "countDown", countDown
          if countDown >= 0
            Session.set 'countDown', countDown
          else
            Session.set 'countDown', countDown
            clearInterval intervaller
            intervaller = null
            intervalDone = yes
      displayCount = Session.get 'countDown'
      if displayCount isnt no
        #debug "displayCount", displayCount, seconds2time displayCount/1000
        
        displayAbsoluteTime = (sTimeHere untilTime).toLocaleTimeString()
        displayAbsoluteTime = displayAbsoluteTime.substr(0, displayAbsoluteTime.length - 3)
        #debug "displayCount", displayCount
        if displayCount and displayCount >= 0
          val = Template[before] 
            displayCount: seconds2roughTime displayCount/1000
            displayAbsoluteTime: displayAbsoluteTime
          #debug "before?:", val, displayCount
          return val
        else #if displayCount?
          val = Template[after]
            displayCount: seconds2roughTime displayCount/1000
            displayAbsoluteTime: displayAbsoluteTime
          debug "Countdown complete"
          return val
        #else
        #  return "no displayCount???"
    else
      debug "No experiment currently pending"
      return "No experiment currently pending"
          
Handlebars.registerHelper 'call', (funcName, data) ->
  window[funcName] data
  ""
Handlebars.registerHelper 'debugger', (data, outerdata) ->
  debugger
  
@playSound = (whichSound) ->
  sT = (ms, fn) ->
    setTimeout fn, ms
  sT 1000, ->
    document.getElementById(whichSound).play()
  
@playSoundOnce = ->
  window.SOUNDED ?= false
  if not SOUNDED
    playSound 'starting'
    window.SOUNDED = true

global = @
    
global.VOTE = null  
@ballotSetup = ->
  step = Session.get('step')
  user = Meteor.user()
  if !VOTE or VOTE.step isnt step
    global.VOTE = new Vote
      step: step
      voter: user._id
      stage: Session.get('stage')
  ""

@voteFor = (cand, grade) ->
  debug "voteFor", cand, grade
  VOTE.vote[cand] = grade
  
@checkboxVoteFor = (cand, checked) ->
  debug "voteFor", cand, checked
  VOTE.vote[cand] = (if checked then 1 else 0)
  Session.set('vote',VOTE.vote)

@exclusiveVoteFor = (cand, rank, clearUI) ->
  debug "exclusiveVoteFor", cand, rank
  oldRank = VOTE.vote[cand]
  if -rank isnt oldRank
    if 0 > oldRank
      $("#cand#{ cand }rank#{ -oldRank }").prop('checked', false)
    VOTE.vote[cand] = -rank
    otherCands = [0..VOTE.vote.length - 1]
    otherCands.splice(cand,1)
    for otherCand in otherCands
      if VOTE.vote[otherCand] is -rank
        VOTE.vote[otherCand] = undefined
        
      
@pluralityVoteFor = (cand) ->
  debug "pluralityVoteFor", cand
  VOTE.vote = cand
  


if (Handlebars?.registerHelper?) 
  Handlebars.registerHelper 'Session', (what) ->
    Session.get what