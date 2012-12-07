seconds2time = (seconds) ->
  hours = Math.floor(seconds / 3600)
  minutes = Math.floor((seconds - (hours * 3600)) / 60)
  seconds = Math.floor(seconds - (hours * 3600) - (minutes * 60))
  time = ""
  time = hours + ":"  unless hours is 0
  if minutes isnt 0 or time isnt ""
    minutes = (if (minutes < 10 and time isnt "") then "0" + minutes else String(minutes))
    time += minutes + ":"
  if time is ""
    time = seconds + "s"
  else
    time += (if (seconds < 10) then "0" + seconds else String(seconds))
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
  Handlebars.registerHelper "countdownToStage", (stage, after) ->
    if intervalStage isnt stage and intervaller
      clearInterval intervaller
      intervaller = null
    election = Session.get "election"
    if election?
      untilTime = election.sTimes[stage]
      #untilTime = inTenSeconds()
      if not intervaller and not intervalDone
        sI = (ms, fn) ->
          setInterval fn, ms
        intervaller = sI 1000, ->
          countDown = untilSTime untilTime
          #console.log "countDown", countDown
          if countDown >= 0
            Session.set "countDown", countDown
          else
            Session.set "countDown", countDown
            clearInterval intervaller
            intervaller = null
            intervalDone = yes
      displayCount = Session.get "countDown"
      #console.log "displayCount", displayCount
      if displayCount >= 0
        return Template["countdownClock"] 
          displayCount: seconds2time displayCount/1000
      else if displayCount?
        return Template[after]()
    else
      return "No experiment currently pending"
          
Handlebars.registerHelper "call", (funcName, data) ->
  window[funcName] data
  ""
  
playSound = (whichSound) ->
  sT = (ms, fn) ->
    setTimeout fn, ms
  sT 1000, ->
    document.getElementById(whichSound).play()
  
playSoundOnce = ->
  window.SOUNDED ?= false
  if not SOUNDED
    playSound "starting"
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
  VOTE.vote[cand] = rank
  for otherCand in [0..VOTE.vote.length - 1].splice(cand,1)
    if VOTE.vote[otherCand] is rank
      VOTE.vote[otherCand] = undefined
      if clearUI
        $("#cand#{ otherCand }rank#{ rank }").prop('checked', false)
      
  