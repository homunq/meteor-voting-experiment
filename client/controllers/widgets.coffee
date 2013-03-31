seconds2time = (seconds, hideSeconds) ->
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

inTenSeconds = ->
  now = new Date
  later = new Date
  later.setSeconds(now.getSeconds() + 3) 
  return later.getTime()
  
#countdown
do ->
  intervaller = null
  intervalDone = no
  intervalStage = null
  Handlebars.registerHelper 'countdownToStage', (stage, before, after) ->
    console.log "countdownToStage", stage, intervalStage, intervalDone, intervaller
    if intervalStage isnt stage
      console.log "intervalStage"
      clearInterval intervaller
      intervaller = null
      intervalDone = no
      intervalStage = stage
    election = (Session.get 'election') and ELECTION
    if election?
      untilTime = election.sTimes[stage]
      #console.log "untilTime", untilTime, stage, election.sTimes
      #untilTime = inTenSeconds()
      if not intervaller and not intervalDone
        Session.set 'countDown', no
        sI = (ms, fn) ->
          setInterval fn, ms
        intervaller = sI 1000, ->
          countDown = untilSTime untilTime
          #console.log "countDown", countDown
          if countDown >= 0
            Session.set 'countDown', countDown
          else
            Session.set 'countDown', countDown
            clearInterval intervaller
            intervaller = null
            intervalDone = yes
      displayCount = Session.get 'countDown'
      if displayCount isnt no
        #console.log "displayCount", displayCount, seconds2time displayCount/1000
        
        displayAbsoluteTime = (sTimeHere untilTime).toLocaleTimeString()
        displayAbsoluteTime = displayAbsoluteTime.substr(0, displayAbsoluteTime.length - 3)
        #console.log "displayCount", displayCount
        if displayCount >= 0
          return Template[before] 
            displayCount: seconds2time displayCount/1000
            displayAbsoluteTime: displayAbsoluteTime
        else if displayCount?
          return Template[after]
            displayCount: seconds2time displayCount/1000
            displayAbsoluteTime: displayAbsoluteTime
    else
      return "No experiment currently pending"
          
Handlebars.registerHelper 'call', (funcName, data) ->
  window[funcName] data
  ""
Handlebars.registerHelper 'debugger', (data, outerdata) ->
  debugger
  
playSound = (whichSound) ->
  sT = (ms, fn) ->
    setTimeout fn, ms
  sT 1000, ->
    document.getElementById(whichSound).play()
  
playSoundOnce = ->
  window.SOUNDED ?= false
  if not SOUNDED
    playSound 'starting'
    window.SOUNDED = true
    
VOTE = null  
ballotSetup = ->
  step = Session.get('step')
  user = Meteor.user()
  if !VOTE or VOTE.step isnt step
    VOTE = new Vote
      step: step
      voter: user._id
      stage: Session.get('stage')
  ""

voteFor = (cand, grade) ->
  console.log "voteFor", cand, grade
  VOTE.vote[cand] = grade

exclusiveVoteFor = (cand, rank, clearUI) ->
  console.log "exclusiveVoteFor", cand, rank
  oldRank = VOTE.vote[cand]
  if 0 > oldRank
    $("#cand#{ cand }rank#{ -oldRank }").prop('checked', false)
  VOTE.vote[cand] = -rank
  otherCands = [0..VOTE.vote.length - 1]
  otherCands.splice(cand,1)
  for otherCand in otherCands
    if VOTE.vote[otherCand] is -rank
      VOTE.vote[otherCand] = undefined
        
      
pluralityVoteFor = (cand) ->
  console.log "pluralityVoteFor", cand
  VOTE.vote = cand
  


Handlebars.registerHelper 'Session', (what) ->
  Session.get what