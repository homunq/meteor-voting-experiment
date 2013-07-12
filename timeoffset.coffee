timeOffset = 0

Meteor.methods
  timeOffset: (msClient) ->
    d = new Date()
    msServer = d.getTime()
    return msServer - msClient
    
if Meteor.isClient
  Meteor.startup ->
    d = new Date()
    Meteor.call 'timeOffset', d.getTime(), (error, result) ->
      slog "timeOffset", result
      timeOffset = result
    
untilSTime = (sTime) ->
  d = new Date()
  return sTime - timeOffset - d.getTime()
  
sTimeHere = (sTime) ->
  return new Date (sTime - timeOffset)
