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
  Handlebars.registerHelper "countdown", ->
    election = Session.get "election"
    if election?
      #untilTime = election.sTimes[1]
      untilTime = inTenSeconds()
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
        return Template["countdownDone"]()
    else
      return "No experiment currently pending"
          
Handlebars.registerHelper "call", (funcName, data) ->
  window[funcName] data
  
playSound = ->
  sT = (ms, fn) ->
    setTimeout fn, ms
  sT 1000, ->
    document.getElementById('starting').play()
  
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
